"""Check ROT13.BIN, ATBASH.BIN and ECHO.BIN in the stock PasTinyMoE runtime.

  fpc -Mtp -B -FEbuild EXPERT.PAS                 (in PasTinyMoE; the plain build)
  python3 handwritten/cipher/test.py build/EXPERT

Rebuilds the models from build.py and requires a byte match, then asks through
the unmodified integer engine: for each model 240 random words of 1 to 40
printable characters after one to three lead-in words, and a question with no
space at all, with the model pinned.
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

with tempfile.TemporaryDirectory() as tmp:
    names = rebuilt_matches(here, tmp)
    assert names == sorted(MODELS)
    keywords = {'ROT13.BIN': 'rot13', 'ATBASH.BIN': 'atbash', 'ECHO.BIN': 'echo'}
    rt = Runtime(sys.argv[1], tmp, [(here / n, keywords[n]) for n in names])
    rng = random.Random(21)
    chars = ''.join(chr(c) for c in range(33, 127))
    total = 0
    for expert, name in enumerate(names, start=2):
        table = MODELS[name]
        expect = lambda w: ''.join(table.get(c, c) for c in w.lower())
        words = [''.join(rng.choice(chars) for _ in range(n)) for n in list(range(1, 41)) * 6]
        lead = [' '.join(rng.choice(['please', 'now', 'do', 'x', 'the word']) for _ in range(rng.randint(0, 2))) for _ in words]
        qs = [(l + ' ' if l else '') + keywords[name] + ' ' + w for l, w in zip(lead, words)]
        keep = [(q, w) for q, w in zip(qs, words) if len(q) + len(w) <= 126 and len(q) <= 72]
        got = rt.ask([q for q, _ in keep])
        missed = [(q, g) for (q, w), g in zip(keep, got) if g != expect(w)]
        assert not missed, (name, missed[:3])
        assert rt.ask(['use %d' % expert, 'Hello', 'zebra9', 'auto']) == [expect('hello'), expect('zebra9')], name
        total += len(keep) + 2
    assert rt.ask(['rot13 hello', 'atbash hello', 'echo hello', 'what is 7 times 8']) == ['uryyb', 'svool', 'hello', '7 times 8 is 56.']
print('%s match build.py; %d questions answered exactly; general questions still reach the general model.' % (
    ', '.join(names), total))
