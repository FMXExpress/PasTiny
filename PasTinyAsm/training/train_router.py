#!/usr/bin/env python3
"""Train the PasTinyAsm router: a kilobyte-sized recurrent network that reads
a request a letter at a time and says which expert should have it.

  python3 train_router.py OUT.BIN [HIDDEN] [STEPS]      (SEED=n in the environment for another run)

The cell is FastGRNN (Kusupati et al., 2018), one matrix pair for gate and
candidate:

    a  = W[letter] + U.h
    z  = sigmoid(a + bz)          h~ = tanh(a + bh)
    h  = (zeta.(1 - z) + nu).h~ + z.h

and the answer is the largest of C.h + bc after the last letter.  Training
stops being trusted where it stops helping on wordings held back from it:
the step that did best on those is the one that is kept.  So that
a 386 can run it without a coprocessor, sigmoid and tanh are the straight-
line kinds (clip(x/4 + 1/2, 0, 1) and clip(x, -1, 1)), the weights are 8-bit
with one power-of-two scale, and the state is 16-bit fixed point.  run()
below is that integer arithmetic exactly; ROUTER.PAS does the same sums, and
OUT.BIN.TXT holds requests with the answers both must give.
"""
import os, random, struct, sys, time
from pathlib import Path
import torch
import torch.nn as nn
import torch.nn.functional as F
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_router as g

out = sys.argv[1]
H = int(sys.argv[2]) if len(sys.argv) > 2 else 32
steps = int(sys.argv[3]) if len(sys.argv) > 3 else 6000
seed = int(os.environ.get('SEED', '1'))
torch.manual_seed(seed); torch.set_num_threads(int(os.environ.get('THREADS', '2')))
LETTERS = ' abcdefghijklmnopqrstuvwxyz0,'           # 29: every digit is "0"
V, K, S, Q = len(LETTERS), len(g.CLASSES), 6, 12     # weights are n/2^S, the state is n/2^Q
code = lambda s: [LETTERS.index(c) for c in s]


def q8(w):
    """Weights as they will be stored: whole numbers of 1/2^S, -127 to 127 (gradients pass straight through)."""
    return w + ((w * 2 ** S).round().clamp(-127, 127) / 2 ** S - w).detach()


class Router(nn.Module):
    def __init__(self):
        super().__init__()
        self.w = nn.Parameter(torch.randn(V, H) * 0.3)
        self.u = nn.Parameter(torch.randn(H, H) * 0.15)
        self.bz = nn.Parameter(torch.ones(H)); self.bh = nn.Parameter(torch.zeros(H))
        self.c = nn.Parameter(torch.randn(K, H) * 0.3); self.bc = nn.Parameter(torch.zeros(K))
        self.zeta = nn.Parameter(torch.tensor(2.0)); self.nu = nn.Parameter(torch.tensor(-4.0))

    def forward(self, x, n):                         # x: batch x time, n: lengths
        w, u, c = q8(self.w), q8(self.u), q8(self.c)
        zeta, nu = torch.sigmoid(self.zeta), torch.sigmoid(self.nu)
        h = torch.zeros(x.shape[0], H)
        for t in range(x.shape[1]):
            a = w[x[:, t]] + h @ u.t()
            z = (a / 4 + 0.5 + self.bz / 4).clamp(0, 1)
            cand = (a + self.bh).clamp(-1, 1)
            new = (zeta * (1 - z) + nu) * cand + z * h
            h = torch.where((t < n).unsqueeze(1), new, h)
        return h @ c.t() + self.bc


def batch(pairs):
    n = torch.tensor([len(q) for q, _ in pairs])
    x = torch.zeros(len(pairs), int(n.max()), dtype=torch.long)
    for i, (q, _) in enumerate(pairs):
        x[i, :len(q)] = torch.tensor(code(q))
    return x, n, torch.tensor([g.CLASSES.index(c) for _, c in pairs])


def tdiv(a, k):
    """Divide by 2^k, rounding toward zero, as Pascal's div does."""
    return a >> k if a >= 0 else -((-a) >> k)


def integers(m):
    r8 = lambda w: (w.detach() * 2 ** S).round().clamp(-127, 127).long().tolist()
    r12 = lambda b: (b.detach() * 2 ** Q).round().long().tolist()
    return dict(w=r8(m.w), u=r8(m.u), c=r8(m.c), bz=r12(m.bz), bh=r12(m.bh), bc=r12(m.bc),
                zeta=int(torch.sigmoid(m.zeta).item() * 2 ** Q + 0.5), nu=int(torch.sigmoid(m.nu).item() * 2 ** Q + 0.5))


def run(p, q):
    """The class of request q, in whole numbers only."""
    one = 1 << Q
    h = [0] * H
    for x in code(q):
        new = []
        for i in range(H):
            a = (p['w'][x][i] << (Q - S)) + tdiv(sum(p['u'][i][j] * h[j] for j in range(H)), S)
            z = min(max(tdiv(a + p['bz'][i], 2) + one // 2, 0), one)
            cand = min(max(a + p['bh'][i], -one), one)
            new.append(tdiv((tdiv(p['zeta'] * (one - z), Q) + p['nu']) * cand, Q) + tdiv(z * h[i], Q))
        h = new
    score = [tdiv(sum(p['c'][k][j] * h[j] for j in range(H)), S) + p['bc'][k] for k in range(K)]
    return score.index(max(score))


m = Router()
opt = torch.optim.AdamW(m.parameters(), lr=3e-3, weight_decay=float(os.environ.get('DECAY', '0.01')))
sched = torch.optim.lr_scheduler.LambdaLR(opt, lambda s: min(1.0, (s + 1) / 100) * (0.1 if s > steps * 0.8 else 1.0))
r, tests = random.Random(10 + seed), random.Random(5)
seen = [g.make(tests, 'seen') for _ in range(1000)]
valid = [g.make(tests, 'valid') for _ in range(1000)]     # wordings the router is not trained on: they pick the step to keep
new = [g.make(tests, 'new') for _ in range(1000)]
fresh = [g.make(tests, 'fresh') for _ in range(1000)]
best, kept = -1, None
acc = lambda pairs: sum((m(*batch(pairs)[:2]).argmax(1) == batch(pairs)[2]).tolist())
print('hidden %d: %d numbers' % (H, sum(p.numel() for p in m.parameters())), flush=True)
t0 = time.time(); tot = 0.0
for step in range(1, steps + 1):
    x, n, y = batch([g.make(r, 'all') for _ in range(128)])
    loss = F.cross_entropy(m(x, n), y)
    opt.zero_grad(); loss.backward(); torch.nn.utils.clip_grad_norm_(m.parameters(), 1.0); opt.step(); sched.step()
    tot += loss.item()
    if step % 500 == 0:
        with torch.no_grad():
            v = acc(valid)
            if v > best:
                best, kept = v, integers(m)
            print('step %d loss %.4f trained %d/1000 held back %d/1000%s %.0fs'
                  % (step, tot / 500, acc(seen), v, ' (kept)' if v == best and kept is not None and best == v else '', time.time() - t0), flush=True)
        tot = 0.0

p = kept
blob = bytearray(b'RTR1' + struct.pack('<4B2H', H, V, K, S, p['zeta'], p['nu']))
for row in p['w'] + p['u'] + p['c']:
    blob += struct.pack('<%db' % H, *row)
for b in (p['bz'], p['bh'], p['bc']):
    blob += struct.pack('<%dh' % len(b), *b)
Path(out).write_bytes(blob)
for name, pairs in (('trained', seen), ('held back', valid), ('new', new), ('fresh', fresh)):
    got = [run(p, q) for q, _ in pairs]
    right = sum(g.CLASSES[k] == c for k, (_, c) in zip(got, pairs))
    print('%d bytes, whole numbers only: %s wordings %d/1000' % (len(blob), name, right), flush=True)
    by = {}
    for k, (_, c) in zip(got, pairs):
        by.setdefault(c, [0, 0]); by[c][1] += 1; by[c][0] += g.CLASSES[k] == c
    print('   ' + '  '.join('%s %d/%d' % (c, a, b) for c, (a, b) in sorted(by.items())), flush=True)
# requests and the answers the Pascal router must give
with open(out + '.TXT', 'w', newline='') as f:
    for q, _ in seen[:100] + new[:100] + fresh[:100]:
        f.write('%s %s\r\n' % (g.CLASSES[run(p, q)], q))
