#!/usr/bin/env python3
"""Train one PasTinyAsm expert, starting from the general TINY model.

  python3 train_asm.py EXPERT START.BIN OUT.BIN [STEPS]

EXPERT is screen, sound or text.  Needs PyTorch and the loader in
../../PasTinyJev/training.  Prints exact answers on 300 fresh steps in trained
wordings and 300 in wordings never trained on, scored in floating point; the
real score comes from running OUT.BIN in the 8-bit runtime (tests/test_asm.py).
"""
import random, sys, time
from pathlib import Path
import torch
import torch.nn.functional as F
here = Path(__file__).resolve().parent
sys.path.insert(0, str(here)); sys.path.insert(0, str(here.parents[1] / 'PasTinyJev/training'))
import webtiny_train as w
import gen_asm

expert, start, out = sys.argv[1:4]
steps = int(sys.argv[4]) if len(sys.argv) > 4 else 5000
torch.set_num_threads(1); torch.manual_seed(1)
enc = lambda s: [ord(c) - 30 for c in s]


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
opt = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=0.0)
sched = torch.optim.lr_scheduler.LambdaLR(opt, lambda s: min(1.0, (s + 1) / 200) * (0.1 if s > steps * 0.8 else 1.0))
r = random.Random(11)
tests = random.Random(5)
seen = [gen_asm.make(tests, expert) for _ in range(300)]
held = [gen_asm.make(tests, expert, held=True) for _ in range(300)]
t0 = time.time(); run = 0.0
for step in range(1, steps + 1):
    x, y = batch([gen_asm.make(r, expert) for _ in range(128)])
    l = F.cross_entropy(model(x).flatten(0, 1), y.flatten(), ignore_index=-100)
    opt.zero_grad(); l.backward(); torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0); opt.step(); sched.step()
    run += l.item()
    if step % 1000 == 0:
        print('%s step %d loss %.4f trained wordings %d/300 new wordings %d/300 %.0fs'
              % (expert, step, run / 1000, score(model, seen), score(model, held), time.time() - t0), flush=True)
        run = 0.0; model.train()
w.export_bin(model, out)
