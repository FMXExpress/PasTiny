#!/usr/bin/env python3
"""Train one PasTinyAsm expert as a low-rank adapter on the general TINY model.

  python3 train_lora.py EXPERT BASE.BIN OUT.BIN RANK [STEPS]

The base model is not changed.  Each of its 24 matrices W gets two small
ones, B (rows x RANK) and A (RANK x columns), and the expert is W + B.A;
only A, B and the 9 gain vectors are trained.  Same data, batches and
schedule as train_asm.py, so the two can be compared.

At the end the adapter is rounded to 8 bits a row, as it would be kept on
disk, added to the base and written as an ordinary model (OUT.BIN), which
the 8-bit runtime can score.  OUT.BIN.lora holds the adapter by itself.
"""
import os, random, struct, sys, time
from pathlib import Path
import torch
import torch.nn as nn
import torch.nn.functional as F
here = Path(__file__).resolve().parent
sys.path.insert(0, str(here)); sys.path.insert(0, str(here.parents[1] / 'PasTinyJev/training'))
import webtiny_train as w
import gen_asm, gen_recipes, gen_tasks

expert, start, out, rank = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
steps = int(sys.argv[5]) if len(sys.argv) > 5 else 5000
torch.set_num_threads(int(os.environ.get('THREADS', '1'))); torch.manual_seed(1)
enc = lambda s: [ord(c) - 30 for c in s]
NAMES = ('wq', 'wk', 'wv', 'wo', 'f1', 'f2')


class Lora(nn.Module):
    def __init__(self, linear):
        super().__init__()
        rows, cols = linear.weight.shape
        self.base = nn.Parameter(linear.weight.detach().clone(), requires_grad=False)
        self.a = nn.Parameter(torch.randn(rank, cols) / cols ** 0.5)
        self.b = nn.Parameter(torch.zeros(rows, rank))

    def merged(self, a=None, b=None):
        return self.base + (self.b if b is None else b) @ (self.a if a is None else a)

    def forward(self, x):
        return F.linear(x, self.merged())


def rounded(m):
    """A matrix as it is kept on disk: 8 bits a value, one scale a row."""
    scale = m.abs().amax(-1, keepdim=True).clamp_min(1e-20) / 127
    z = m / scale
    return (z.sign() * (z.abs() + .5).floor()).clamp(-127, 127) * scale


def batch(pairs):
    items = [(enc(q) + [1] + enc(a) + [1], len(q)) for q, a in pairs]
    n = max(len(s) for s, _ in items) - 1
    x = torch.zeros(len(items), n, dtype=torch.long); y = torch.full_like(x, -100)
    for i, (s, ql) in enumerate(items):
        x[i, :len(s) - 1] = torch.tensor(s[:-1]); y[i, ql:len(s) - 1] = torch.tensor(s[ql + 1:])
    return x, y


def score(model, pairs):
    return sum(w.answer(model, q) == a for q, a in pairs)


model = w.load_bin(start)
for p in model.parameters():
    p.requires_grad = False
for block in model.blocks:
    for name in NAMES:
        setattr(block, name, Lora(getattr(block, name)))
    block.g1.requires_grad = True; block.g2.requires_grad = True
model.gf.requires_grad = True
train = [p for p in model.parameters() if p.requires_grad]
opt = torch.optim.AdamW(train, lr=float(os.environ.get('LR', '2e-3')), weight_decay=0.0)
sched = torch.optim.lr_scheduler.LambdaLR(opt, lambda s: min(1.0, (s + 1) / 200) * (0.1 if s > steps * 0.8 else 1.0))
r = random.Random(11)
tests = random.Random(5)
if expert == 'tasks':
    draw = lambda rr: gen_tasks.make(rr, 'seen')
    seen = [gen_tasks.make(tests, 'seen') for _ in range(300)]
    held = [gen_tasks.make(tests, 'combo') for _ in range(300)]
elif expert == 'recipes':
    draw = lambda rr: gen_recipes.make(rr, 'seen')
    seen = [gen_recipes.make(tests, 'seen') for _ in range(300)]
    held = [gen_recipes.make(tests, 'combo') for _ in range(300)]
else:
    draw = lambda rr: gen_asm.make(rr, expert)
    seen = [gen_asm.make(tests, expert) for _ in range(300)]
    held = [gen_asm.make(tests, expert, held=True) for _ in range(300)]
print('rank %d: %d numbers trained of %d' % (rank, sum(p.numel() for p in train), sum(p.numel() for p in model.parameters())),
      flush=True)
t0 = time.time(); run = 0.0
for step in range(1, steps + 1):
    x, y = batch([draw(r) for _ in range(128)])
    l = F.cross_entropy(model(x).flatten(0, 1), y.flatten(), ignore_index=-100)
    opt.zero_grad(); l.backward(); torch.nn.utils.clip_grad_norm_(train, 1.0); opt.step(); sched.step()
    run += l.item()
    if step % 1000 == 0:
        print('%s rank %d step %d loss %.4f trained wordings %d/300 new wordings %d/300 %.0fs'
              % (expert, rank, step, run / 1000, score(model, seen), score(model, held), time.time() - t0), flush=True)
        run = 0.0; model.train()

# The adapter as a file: for each matrix the RANK columns of B, then the RANK rows of A, each a float
# scale and 8-bit values; then the gains.
blob = bytearray(b'TLR1' + struct.pack('<H', rank))
plain = w.load_bin(start)
with torch.no_grad():
    for pb, block in zip(plain.blocks, model.blocks):
        for name in NAMES:
            m = getattr(block, name)
            a8, b8 = rounded(m.a), rounded(m.b.t()).t()      # one scale for each of the RANK directions
            for mat in (b8.t(), a8):
                for row in mat:
                    scale = row.abs().max().item() / 127
                    q = (row / scale).round().to(torch.int8) if scale else torch.zeros_like(row, dtype=torch.int8)
                    blob += struct.pack('<f', scale) + struct.pack('<%db' % row.numel(), *q.tolist())
            getattr(pb, name).weight.copy_(m.merged(a8, b8))
        for g in ('g1', 'g2'):
            getattr(pb, g).copy_(getattr(block, g)); blob += struct.pack('<%df' % 96, *getattr(block, g).tolist())
    plain.gf.copy_(model.gf); blob += struct.pack('<%df' % 96, *model.gf.tolist())
w.export_bin(plain, out)
Path(out + '.lora').write_bytes(blob)
again = w.load_bin(out)
print('%s rank %d adapter %d bytes; merged and rounded to 8 bits: trained wordings %d/300 new wordings %d/300'
      % (expert, rank, len(blob), score(again, seen), score(again, held)), flush=True)
