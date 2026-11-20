"""Check DIGIT.BIN, QMARK.BIN and EXCLAIM.BIN in the PasTinyJev runtime.

  fpc -Mtp -B -FEbuild JEV.PAS                      (in PasTinyJev)
  python3 ../PasTinyMoE/handwritten/rules/test.py build/JEV

Rebuilds the models from build.py and requires a byte match, then packages
them beside the trained triage model with instruction keywords and asks 300
random states per rule through the unmodified integer engine.  A state with a
wanted character must score above 0.99 and one without below 0.01.  A question
without a rule keyword must still reach the trained model.
"""
import importlib.util
import json
import random
import subprocess
import sys
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here.parent))
sys.path.insert(0, str(here))
from harness import rebuilt_matches
from build import MODELS

jev = here.parents[2] / 'PasTinyJev'
spec = importlib.util.spec_from_file_location('jev_package', jev / 'tools' / 'package.py')
package = importlib.util.module_from_spec(spec)      # PasTinyMoE has a package.py too
spec.loader.exec_module(package)

exe = Path(sys.argv[1]).resolve()
RULES = [('DIGIT.BIN', 'digit', 'does the text contain a digit'),
         ('QMARK.BIN', 'question mark', 'is there a question mark'),
         ('EXCLAIM.BIN', 'exclamation mark', 'is there an exclamation mark')]
with tempfile.TemporaryDirectory() as tmp:
    assert rebuilt_matches(here, tmp) == sorted(MODELS)
    entries = json.loads((jev / 'models.json').read_text())
    for i, (name, keyword, _) in enumerate(RULES):
        entries.append(dict(id=10 + i, name=name, title='Rule: ' + keyword, keyword=keyword, source=str(here / name)))
    rt = Path(tmp) / 'rt'
    package.build(entries, exe, rt, 'JEV')
    rng = random.Random(8)
    plain = 'abcdefghijklmnopqrstuvwxyz ,.-'
    lines, want = [], []
    for name, keyword, instruction in RULES:
        wanted = MODELS[name]
        for n in range(300):
            text = ''.join(rng.choice(plain) for _ in range(rng.randint(1, 70))).strip() or 'x'
            hit = n % 2 == 0
            if hit:
                for _ in range(rng.randint(1, 3)):
                    at = rng.randrange(len(text) + 1)
                    text = text[:at] + rng.choice(wanted) + text[at:]
            lines += ['STATE ' + text, 'NOUL q%d | %s' % (len(want), instruction)]
            want.append(hit)
    lines += ['STATE i was charged twice this month.', 'NOUL last | is this a billing issue']
    out = subprocess.run([str(exe)], input='\n'.join(lines) + '\n', text=True, capture_output=True, cwd=rt,
                         check=True).stdout.splitlines()
    got = {}
    for line in out:
        m = line.split(' ')
        if len(m) > 1 and m[1].startswith('noul='):
            got[m[0]] = float(m[1][5:])
    wrong = [(i, got.get('q%d' % i)) for i, hit in enumerate(want)
             if got.get('q%d' % i) is None or (got['q%d' % i] > 0.99) != hit or 0.01 <= got['q%d' % i] <= 0.99]
    assert not wrong, wrong[:5]
    assert out[[i for i, l in enumerate(out) if l.startswith('last ')][0] - 1].startswith('active 1 '), 'trained model not used'
    assert got['last'] > 0.5
print('%s match build.py; %d rule answers exact (above 0.99 or below 0.01); other questions reach the trained model.' % (
    ', '.join(sorted(MODELS)), len(want)))
