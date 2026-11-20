"""Check REVERSE.BIN in the stock PasTinyMoE runtime.

  fpc -Mtp -B -FEbuild EXPERT.PAS                 (in PasTinyMoE; the plain build)
  python3 handwritten/reverse/test.py build/EXPERT

Rebuilds the model from build.py and requires it to match the committed file,
then packages it beside the general model with the keyword "reverse" and asks
through the unmodified integer engine: fixed examples, 330 random strings of
1 to 55 printable characters, and ordinary questions that must still reach the
general model.
"""
import hashlib
import random
import subprocess
import sys
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
project = here.parents[1]
sys.path.insert(0, str(project / 'tools'))
from package import build

exe = Path(sys.argv[1]).resolve()
model = here / 'REVERSE.BIN'
with tempfile.TemporaryDirectory() as tmp:
    fresh = Path(tmp) / 'REVERSE.BIN'
    subprocess.run([sys.executable, str(here / 'build.py'), str(fresh)], check=True, capture_output=True)
    assert fresh.read_bytes() == model.read_bytes(), 'REVERSE.BIN does not match build.py'

    general = project / 'TINY.BIN'
    entries = [dict(id=1, name='GENERAL.BIN', title='TINY 2.1 general (trained)', keyword='',
                    source=str(general), sha256=hashlib.sha256(general.read_bytes()).hexdigest()),
               dict(id=2, name='REVERSE.BIN', title='Reverse (hand-written)', keyword='reverse',
                    source=str(model), sha256=hashlib.sha256(model.read_bytes()).hexdigest())]
    runtime = Path(tmp) / 'rt'
    build(entries, exe, runtime)

    def ask(questions):
        out = subprocess.run([str(exe)], input='\n'.join(questions) + '\n', text=True, capture_output=True,
                             cwd=runtime, check=True).stdout.splitlines()
        answers = [out[i - 1] for i, line in enumerate(out) if line.startswith('answer ms=')]
        assert len(answers) == len(questions), (len(answers), len(questions))
        return answers

    fixed = {'reverse jumped': 'depmuj', 'reverse naypyidaw': 'wadiypyan', 'reverse a': 'a',
             'reverse Hello-World_42!': '!24_dlroW-olleH', 'please reverse giraffe': 'effarig',
             'reverse antidisestablishmentarianism': 'msinairatnemhsilbatsesiditna'}
    assert ask(list(fixed)) == list(fixed.values()), ask(list(fixed))

    rng = random.Random(11)
    chars = ''.join(chr(c) for c in range(33, 127))
    words = [''.join(rng.choice(chars) for _ in range(n)) for n in list(range(1, 56)) * 6]
    got = ask(['reverse ' + w for w in words])
    missed = [(w, g) for w, g in zip(words, got) if g != w[::-1]]
    assert not missed, missed[:3]

    assert ask(['what is 7 times 8', 'what is the capital of peru']) == ['7 times 8 is 56.', 'Lima.']
print('REVERSE.BIN matches build.py; %d fixed examples and %d random strings reversed exactly; '
      'general questions still reach the general model.' % (len(fixed), len(words)))
