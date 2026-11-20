"""Does a hand-written network make a good starting point for training?

  python3 training_start.py START LR STEPS SEED OUT.json

START is 'random', or a .BIN file (PLUS.BIN here, or ../../TINY.BIN).  Needs PyTorch.
The recorded runs used 6000 steps and seed 1; see training_start.json.  The task is "what is A plus B" for A and B
from 0 to 999, answered with the bare number.  PLUS.BIN does this exactly for
0 to 99 and was never built for three digits.
"""
import json, random, sys, time
from pathlib import Path
import torch
import torch.nn.functional as F
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'PasTinyJev/training'))
import webtiny_train as w

start, lr, steps, seed, out = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
torch.set_num_threads(1); torch.manual_seed(seed)
rng = random.Random(1)                       # the test pairs are the same for every run
def number(r): return r.randrange(10 ** r.choice([1, 2, 3]))
small, big = set(), set()
while len(small) < 500:
    small.add((rng.randrange(100), rng.randrange(100)))
while len(big) < 1000:
    p = (number(rng), number(rng))
    if max(p) >= 100: big.add(p)
held = small | big
small, big = sorted(small), sorted(big)
enc = lambda s: [ord(c) - 30 for c in s]
def seq(a, b):
    q = enc('what is %d plus %d' % (a, b))
    return q + [1] + enc(str(a + b)) + [1], len(q)

def batch(pairs):
    items = [seq(*p) for p in pairs]
    n = max(len(s) for s, _ in items) - 1
    x = torch.zeros(len(items), n, dtype=torch.long); y = torch.full_like(x, -100)
    for i, (s, ql) in enumerate(items):
        x[i, :len(s) - 1] = torch.tensor(s[:-1]); y[i, ql:len(s) - 1] = torch.tensor(s[ql + 1:])
    return x, y

@torch.no_grad()
def score(model, pairs):
    """Exact answers by greedy decoding, all pairs at once (questions grouped by length)."""
    model.eval(); right = 0
    groups = {}
    for a, b in pairs: groups.setdefault(len('%d%d' % (a, b)), []).append((a, b))
    for g in groups.values():
        toks = torch.tensor([enc('what is %d plus %d' % p) + [1] for p in g])
        outs = [''] * len(g); done = [False] * len(g)
        for _ in range(6):
            nxt = model(toks)[:, -1].argmax(-1)
            for i, t in enumerate(nxt.tolist()):
                if not done[i]:
                    if t <= 1: done[i] = True
                    else: outs[i] += chr(t + 30)
            toks = torch.cat([toks, nxt[:, None].clamp_min(1)], 1)
        right += sum(o == str(a + b) for o, (a, b) in zip(outs, g))
    model.train()
    return right

model = w.Tiny() if start == 'random' else w.load_bin(start)
opt = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=0.0)
sched = torch.optim.lr_scheduler.LambdaLR(opt, lambda s: min(1.0, (s + 1) / 200))
tr = random.Random(seed + 100)
log = []; t0 = time.time()
def record(step, loss):
    log.append(dict(step=step, loss=loss, small=score(model, small), big=score(model, big)))
    print(start.split('/')[-1], lr, seed, log[-1], '%.0fs' % (time.time() - t0), flush=True)
record(0, None)
run = 0.0
for step in range(1, steps + 1):
    pairs = []
    while len(pairs) < 128:
        p = (number(tr), number(tr))
        if p not in held: pairs.append(p)
    x, y = batch(pairs)
    l = F.cross_entropy(model(x).flatten(0, 1), y.flatten(), ignore_index=-100)
    if not torch.isfinite(l): print('loss not finite at step', step); break
    opt.zero_grad(); l.backward(); torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0); opt.step(); sched.step()
    run += l.item()
    if step % 500 == 0: record(step, run / 500); run = 0.0
json.dump(dict(start=Path(start).name, lr=lr, seed=seed, log=log), open(out, 'w'))
