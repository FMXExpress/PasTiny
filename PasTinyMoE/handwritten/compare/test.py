"""Check BIGGER.BIN and SMALLER.BIN in the stock PasTinyMoE runtime.

  fpc -Mtp -B -FEbuild EXPERT.PAS                 (in PasTinyMoE; the plain build)
  python3 handwritten/compare/test.py build/EXPERT [--general]

Rebuilds the models from build.py and requires a byte match, then asks 1,200
questions per model through the unmodified integer engine and compares each
answer with Python's own comparison.  The pairs are chosen to be hard: equal
numbers, numbers that differ only in one digit at a random place, numbers one
digit longer or shorter, and unrelated numbers, from 1 to 12 digits, in
several wordings.  --general also asks the trained general model the same
"bigger" questions, for comparison.
"""
import random
import sys
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here.parent))
sys.path.insert(0, str(here))
from harness import Runtime, rebuilt_matches
from build import MODELS

# the catalog keyword must stand as a word of its own for the plain router to pick the model
WORDINGS = ['is %d {w} than %d', 'which is {w} %d or %d', '{w} %d, %d', 'tell me if %d is {w} than %d please',
            'is %d {w} than %d?', '%d... {w} than %d?!']


def pairs(rng, count):
    out = []
    while len(out) < count:
        digits = rng.randint(1, 12)
        a = rng.randrange(10 ** (digits - 1) if digits > 1 else 0, 10 ** digits)
        kind = rng.randrange(5)
        if kind == 0:
            b = a
        elif kind == 1:                                   # one digit changed, anywhere
            s = list(str(a))
            i = rng.randrange(len(s))
            s[i] = rng.choice([d for d in '0123456789' if d != s[i] and not (i == 0 and d == '0' and len(s) > 1)])
            b = int(''.join(s))
        elif kind == 2:                                   # one digit longer or shorter
            b = a * 10 + rng.randrange(10) if rng.random() < 0.5 else a // 10
        elif kind == 3:                                   # next to each other
            b = max(0, a + rng.choice([-1, 1]))
        else:
            other = rng.randint(1, 12)
            b = rng.randrange(10 ** (other - 1) if other > 1 else 0, 10 ** other)
        out.append((a, b))
    return out


with tempfile.TemporaryDirectory() as tmp:
    names = rebuilt_matches(here, tmp)
    assert names == sorted(MODELS)
    words = {'BIGGER.BIN': 'bigger', 'SMALLER.BIN': 'smaller'}
    rt = Runtime(sys.argv[1], tmp, [(here / n, words[n]) for n in names])
    rng = random.Random(42)
    total = 0
    for name in names:
        word = words[name]
        cases = []
        for a, b in pairs(rng, 1200):
            wording = rng.choice(WORDINGS).replace('{w}', word)
            if wording.startswith('%d'):                  # a number may not be the very first thing
                wording = 'so ' + wording
            q = wording % (a, b)
            if len(q) <= 72:
                cases.append((q, (a > b) if word == 'bigger' else (a < b)))
        got = rt.ask([q for q, _ in cases])
        wrong = [(q, g) for (q, want), g in zip(cases, got) if g != ('yes' if want else 'no')]
        assert not wrong, (name, len(wrong), wrong[:5])
        total += len(cases)
    assert rt.ask(['what is 7 times 8']) == ['7 times 8 is 56.']
    print('%s match build.py; %d comparisons answered exactly; general questions still reach the general model.' % (
        ', '.join(names), total))
    if '--general' in sys.argv:
        rng = random.Random(42)
        cases = [('is %d bigger than %d' % (a, b), a > b) for a, b in pairs(rng, 1200)]
        got = rt.ask(['use 1'] + [q for q, _ in cases])
        right = sum(g.lower().startswith('yes' if want else 'no') for (q, want), g in zip(cases, got))
        small = [(c, g) for c, g in zip(cases, got) if len(c[0]) <= 26]
        right_small = sum(g.lower().startswith('yes' if want else 'no') for (q, want), g in small)
        print('trained general model on the same kind of pairs: %d/%d right (%d/%d on the shorter questions)' % (
            right, len(cases), right_small, len(small)))
