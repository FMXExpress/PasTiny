#!/usr/bin/env python3
"""Train and export the PasTinyJev decision model.

  python3 train_jev.py train MINUTES OUT.pt [--init ../TINY.BIN | --resume X.pt]
                                              [--distill distill.jsonl.gz] [--mix 0.6]
  python3 train_jev.py eval MODEL.pt|MODEL.BIN        scores, held-back and hand-written
  python3 train_jev.py export MODEL.pt JEV.BIN        the TNY2 file JEV.EXE loads
  python3 train_jev.py ask MODEL.BIN wild.jsonl       answers as JSON lines

The network is TINY 2.1 unchanged (96 wide, 4 layers, 128 letters of context),
taken from the WebTiny trainer (webtiny_train.py), which also imitates the
runtime's 8-bit key/value cache while training.  Only the loss is new: the model
is read at one position, as the difference of its 'y' and 'n' scores.

--distill adds questions labelled by a local OpenJev server (build_distill.py);
--mix is the share of each batch taken from them, the rest being templates.
"""
import gzip
import json
import math
import random
import sys
import time
from pathlib import Path

import torch
from torch.nn import functional as F

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_jev
from webtiny_train import Tiny, load_bin, export_bin, rms

YES, NO, NEWLINE = ord('y') - 30, ord('n') - 30, 1
torch.set_num_threads(4)


def encode(line):
    return [ord(c) - 30 for c in line] + [NEWLINE]


def read(model, lines):
    """y-minus-n score of each context, taken where the answer would start."""
    ids = [encode(s) for s in lines]
    T = max(map(len, ids))
    x = torch.zeros(len(ids), T, dtype=torch.long)
    for i, s in enumerate(ids):
        x[i, :len(s)] = torch.tensor(s)
    h = model.emb(x) + model.pos(torch.arange(T))
    for block in model.blocks:
        h = block(h)
    last = h[torch.arange(len(ids)), torch.tensor([len(s) - 1 for s in ids])]
    last = rms(last, model.gf)
    return last @ (model.emb.weight[YES] - model.emb.weight[NO])


def loss_fn(model, examples):
    lines, spans = [], []
    for kind, ls, tgt in examples:
        spans.append((kind, len(lines), len(ls), tgt))
        lines.extend(ls)
    d = read(model, lines)
    total = 0.0
    for kind, at, n, tgt in spans:
        if kind == 'noul':
            total = total + F.binary_cross_entropy_with_logits(d[at], torch.tensor(float(tgt)))
        else:
            total = total - (torch.tensor(tgt) * F.log_softmax(d[at:at + n], 0)).sum()
    return total / len(spans)


def load_distill(path):
    """Teacher-labelled records -> (training examples, held-back test examples),
    each (kind, lines, target) like gen_jev.sample."""
    opener = gzip.open if str(path).endswith('.gz') else open
    train, held = [], []
    with opener(path, 'rt') as f:
        for s in f:
            r = json.loads(s)
            instr = gen_jev.fit_text(r['instructions'])
            if r['options'] is None:
                lines = [gen_jev.read_line(r['state'], instr)]
            else:
                lines = [gen_jev.read_line(r['state'], instr, gen_jev.fit_text(o)) for o in r['options']]
            if max(map(len, lines)) <= gen_jev.MAXLEN:
                (held if r['held'] else train).append((r['type'], lines, r['p']))
    return train, held


_POOL = []
DISTILL, HELD, MIX = [], [], 0.0


def batch(rng, n):
    """Examples of similar length together, so little time goes on padding."""
    if not _POOL:
        ex = [rng.choice(DISTILL) if DISTILL and rng.random() < MIX else gen_jev.sample(rng)
              for _ in range(n * 40)]
        ex.sort(key=lambda e: len(e[1][0]))
        chunks = [ex[i:i + n] for i in range(0, len(ex), n)]
        rng.shuffle(chunks)
        _POOL.extend(chunks)
    return _POOL.pop()


# ------------------------------------------------------------------ answers
def answer(model, q):
    """One API-style question -> the answer dict JEV.EXE and the server give."""
    lines, names = gen_jev.compose(q)
    if max(map(len, lines)) > gen_jev.MAXLEN:
        return dict(error='too long')
    with torch.no_grad():
        d = read(model, lines)
    if q['type'] == 'noul':
        return dict(noul=torch.sigmoid(d[0]).item())
    p = torch.softmax(d, 0)
    k = len(names)
    conf = 1.0 if k < 2 else 1 + (p * p.clamp_min(1e-12).log()).sum().item() / math.log(k)
    out = dict(probabilities={str(n): p[i].item() for i, n in enumerate(names)}, confidence=conf)
    if q['type'] == 'choice':
        out['choice'] = names[int(p.argmax())]
    else:
        out['score'] = sum(i * p[i].item() for i in range(k))
    return out


def judge(q, a):
    """Is the answer on the expected side?"""
    if 'error' in a:
        return False
    if q['type'] == 'noul':
        return (a['noul'] > 0.5) == bool(q['expect'])
    if q['type'] == 'choice':
        return a['choice'] == q['expect']
    p = a['probabilities']
    return max(p, key=p.get) == str(q['expect'])


def synthetic_scores(model, held, held_q, n=1500, seed=7):
    rng = random.Random(seed + held + 2 * held_q)
    ex = [gen_jev.sample(rng, held, held_q) for _ in range(n)]
    hit = {'noul': [0, 0], 'choice': [0, 0], 'score': [0, 0]}
    brier, nb, bins = 0.0, 0, [[0, 0.0, 0.0] for _ in range(10)]
    with torch.no_grad():
        for i in range(0, n, 100):
            part = ex[i:i + 100]
            lines = [s for _, ls, _ in part for s in ls]
            d = read(model, lines)
            at = 0
            for kind, ls, tgt in part:
                if kind == 'noul':
                    p = torch.sigmoid(d[at]).item()
                    brier += (p - tgt) ** 2
                    nb += 1
                    if abs(tgt - 0.5) > 0.25:              # clear cases only
                        ok = (p > 0.5) == (tgt > 0.5)
                        hit[kind][0] += ok
                        hit[kind][1] += 1
                        b = bins[min(9, int(max(p, 1 - p) * 20) - 10)]
                        b[0] += 1
                        b[1] += max(p, 1 - p)
                        b[2] += ok
                else:
                    p = torch.softmax(d[at:at + len(ls)], 0)
                    best = max(range(len(tgt)), key=tgt.__getitem__)
                    hit[kind][0] += int(p.argmax()) == best
                    hit[kind][1] += 1
                at += len(ls)
    ece = sum(abs(b[1] - b[2]) for b in bins) / max(1, sum(b[0] for b in bins))
    return {k: v[0] / max(1, v[1]) for k, v in hit.items()}, brier / max(1, nb), ece


def teacher_scores(model, held, n=1500):
    """Agreement with the teacher on messages it labelled that were never
    trained on: same side or same best option, and mean probability gap."""
    part = held[:n]
    same, gap, m = 0, 0.0, 0
    with torch.no_grad():
        for i in range(0, len(part), 100):
            chunk = part[i:i + 100]
            d = read(model, [s for _, ls, _ in chunk for s in ls])
            at = 0
            for kind, ls, tgt in chunk:
                if kind == 'noul':
                    p = torch.sigmoid(d[at]).item()
                    same += (p > 0.5) == (tgt > 0.5)
                    gap += abs(p - tgt)
                else:
                    p = torch.softmax(d[at:at + len(ls)], 0)
                    same += int(p.argmax()) == max(range(len(tgt)), key=tgt.__getitem__)
                    gap += (p - torch.tensor(tgt)).abs().mean().item()
                at += len(ls)
                m += 1
    return same / max(1, m), gap / max(1, m), m


def wild_scores(model, path=None, show=False):
    path = path or Path(__file__).resolve().parent / 'wild.jsonl'
    qs = [json.loads(s) for s in Path(path).read_text().splitlines() if s.strip()]
    good = 0
    for q in qs:
        a = answer(model, q)
        ok = judge(q, a)
        good += ok
        if show:
            got = a.get('error') or (round(a['noul'], 2) if 'noul' in a else a.get('choice', None))
            if q['type'] == 'score' and 'score' in a:
                got = round(a['score'], 2)
            print('  %s %-6s %-34s want %-8s got %-8s | %s' % (
                'ok ' if ok else 'BAD', q['type'], q['instructions'][:34], q['expect'], got, q['state'][:60]))
    return good, len(qs)


def evaluate(model, show=False):
    model.eval()
    parts = []
    for name, held, held_q in (('trained wordings', False, False), ('new messages', True, False),
                               ('new question and option words', False, True)):
        acc, brier, ece = synthetic_scores(model, held, held_q)
        parts.append('%s: noul %.1f%% choice %.1f%% score %.1f%% brier %.3f ece %.3f' % (
            name, 100 * acc['noul'], 100 * acc['choice'], 100 * acc['score'], brier, ece))
    if HELD:
        same, gap, m = teacher_scores(model, HELD)
        parts.append('teacher on %d new real questions: agree %.1f%% gap %.3f' % (m, 100 * same, gap))
    good, n = wild_scores(model, show=show)
    parts.append('hand-written %d/%d' % (good, n))
    model.train()
    return ' | '.join(parts)


def as_exported(model):
    """The model as JEV.EXE will see it: through the 8-bit weight file."""
    tmp = Path(__file__).resolve().parent / '.export_check.bin'
    export_bin(model, tmp)
    m = load_bin(tmp)
    tmp.unlink()
    return m


def load(path):
    if str(path).upper().endswith('.BIN'):
        return load_bin(path)
    ck = torch.load(path, map_location='cpu')
    m = Tiny(**ck['config'])
    m.load_state_dict(ck['model'])
    return m


def save(model, path):
    torch.save(dict(config=model.config, model=model.state_dict()), path)


def train(minutes, out, init=None, resume=None, peak=1e-3, bs=40, eval_every=5):
    torch.manual_seed(0)
    rng = random.Random(0)
    model = load(resume) if resume else (load_bin(init) if init else Tiny())
    decay = [p for p in model.parameters() if p.dim() == 2]
    other = [p for p in model.parameters() if p.dim() < 2]
    opt = torch.optim.AdamW([dict(params=decay, weight_decay=0.01), dict(params=other, weight_decay=0.0)],
                            lr=peak, betas=(0.9, 0.98))
    t0, step, total, run, evals = time.time(), 0, minutes * 60, None, 0
    while True:
        el = time.time() - t0
        if el > total:
            break
        lr = peak * min(1.0, (step + 1) / 200) * (0.03 + 0.97 * 0.5 * (1 + math.cos(math.pi * el / total)))
        for g in opt.param_groups:
            g['lr'] = lr
        if el > (evals + 1) * eval_every * 60:
            evals += 1
            save(model, out)
            print('  EVAL %3.0f min: %s' % (el / 60, evaluate(as_exported(model))), flush=True)
        loss = loss_fn(model, batch(rng, bs))
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        opt.step()
        step += 1
        run = loss.item() if run is None else 0.98 * run + 0.02 * loss.item()
        if step % 200 == 0:
            print('step %6d %5.0fs lr %.5f loss %.4f' % (step, el, lr, run), flush=True)
    save(model, out)
    print('saved', out, 'steps', step, flush=True)
    print('FINAL', evaluate(as_exported(model)), flush=True)


if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    opt = {args[i][2:]: args[i + 1] for i in range(len(args) - 1) if args[i].startswith('--')}
    if 'distill' in opt:
        DISTILL, HELD = load_distill(opt['distill'])
        MIX = float(opt.get('mix', 0.6))
        print('teacher-labelled questions: %d to train on, %d held back' % (len(DISTILL), len(HELD)), flush=True)
    if cmd == 'train':
        train(float(args[0]), args[1], init=opt.get('init'), resume=opt.get('resume'),
              peak=float(opt.get('lr', 1e-3)))
    elif cmd == 'eval':
        print(evaluate(load(args[0]), show=True))
    elif cmd == 'export':
        export_bin(load(args[0]), args[1])
        print('wrote', args[1], Path(args[1]).stat().st_size, 'bytes')
    elif cmd == 'ask':
        m = load(args[0]).eval()
        for s in Path(args[1]).read_text().splitlines():
            if s.strip():
                print(json.dumps(answer(m, json.loads(s))))
