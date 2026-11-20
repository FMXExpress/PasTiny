"""Check PLUS.BIN in the stock PasTinyMoE runtime.

  fpc -Mtp -B -FEbuild EXPERT.PAS                 (in PasTinyMoE; the plain build)
  python3 handwritten/add/test.py build/EXPERT [--general]

Rebuilds the model from build.py and requires a byte match, then asks every
pair of numbers from 0 to 99, all 10,000, through the unmodified integer
engine, in six wordings that put the numbers at different positions.
--general also asks the trained general model "what is A plus B" for 1,000 of
them, for comparison.
"""
import random
import sys
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here.parent))
sys.path.insert(0, str(here))
from harness import Runtime, rebuilt_matches

# the catalog keyword "plus" must stand as a word of its own for the plain router to pick the model
WORDINGS = ['what is %d plus %d', 'so %d plus %d', 'please tell me what %d plus %d is', 'add: %d plus %d?',
            'i have %d apples plus %d pears, how many', 'plus %d %d']

with tempfile.TemporaryDirectory() as tmp:
    assert rebuilt_matches(here, tmp) == ['PLUS.BIN']
    rt = Runtime(sys.argv[1], tmp, [(here / 'PLUS.BIN', 'plus')])
    rng = random.Random(5)
    cases = [(rng.choice(WORDINGS) % (a, b), str(a + b)) for a in range(100) for b in range(100)]
    got = rt.ask([q for q, _ in cases])
    wrong = [(q, g) for (q, want), g in zip(cases, got) if g != want]
    assert not wrong, (len(wrong), wrong[:8])
    assert rt.ask(['what is the capital of peru']) == ['Lima.']
    print('PLUS.BIN matches build.py; all %d sums of two numbers from 0 to 99 exact; '
          'general questions still reach the general model.' % len(cases))
    if '--general' in sys.argv:
        sample = rng.sample([(a, b) for a in range(100) for b in range(100)], 1000)
        got = rt.ask(['use 1'] + ['what is %d plus %d' % p for p in sample])
        right = sum(str(a + b) in ''.join(c if c.isdigit() else ' ' for c in g).split() for (a, b), g in zip(sample, got))
        print('trained general model, "what is A plus B" on 1,000 of the pairs: %d right' % right)
