"""Engine conformance check with hand-written networks.

  python3 handwritten/conformance.py EXPERT [EXPERT ...]      run host builds
  python3 handwritten/conformance.py --write DIR              write a DOS package for any EXPERT.EXE
  python3 handwritten/conformance.py --check CONFORM.LOG      check a transcript from that package

The trained models can only show that two engines agree with each other.  These
networks have answers known by construction, so any engine build can be checked
against the truth: the questions below push attention to exact positions up to
the end of the 128-position context and rank positions one step apart, through the 8-bit key cache, the integer
or float arithmetic and the ReLU layers.  One wrong letter means the engine
deviates.

Host builds to try (in PasTinyMoE): fpc -Mtp -B EXPERT.PAS, and the same with
-dNOASM, -dFLOATMATH or -dDEBUG.  In DOS: copy the files written by --write,
run CONFORM.BAT with the executable under test named EXPERT.EXE, and check
CONFORM.LOG with --check.
"""
import random
import shutil
import sys
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here))
sys.path.insert(0, str(here / 'cipher'))
from harness import Runtime

MODELS = [(here / 'reverse/REVERSE.BIN', 'reverse'), (here / 'cipher/ROT13.BIN', 'rot13'),
          (here / 'cipher/ATBASH.BIN', 'atbash'), (here / 'cipher/ECHO.BIN', 'echo'),
          (here / 'compare/BIGGER.BIN', 'bigger'), (here / 'compare/SMALLER.BIN', 'smaller'),
          (here / 'add/PLUS.BIN', 'plus')]
ALPHABET = 'abcdefghijklmnopqrstuvwxyz'
SUBST = {'rot13': {c: ALPHABET[(i + 13) % 26] for i, c in enumerate(ALPHABET)},
         'atbash': {c: ALPHABET[25 - i] for i, c in enumerate(ALPHABET)}, 'echo': {}}


def expected(keyword, word):
    if keyword == 'reverse':
        return word[::-1]
    return ''.join(SUBST[keyword].get(c, c) for c in word.lower())


def vectors():
    """(question, answer) pairs, the same every run."""
    rng = random.Random(1990)
    chars = ''.join(chr(c) for c in range(33, 127))
    out = []
    for keyword in ('reverse', 'rot13', 'atbash', 'echo'):
        longest = 63 - len(keyword) - 1                    # question and answer share 128 positions
        for n in [1, 2, 3, 5, 8, 13, 21, 34, longest - 1, longest]:
            word = ''.join(rng.choice(chars) for _ in range(n))
            out.append((keyword + ' ' + word, expected(keyword, word)))
        word = (ALPHABET * 3)[:longest]                     # every letter, three times round
        out.append((keyword + ' ' + word, expected(keyword, word)))
        for lead in ('a b c', 'please now', 'x'):          # spaces close together before the keyword
            word = ''.join(rng.choice(ALPHABET) for _ in range(9))
            out.append((lead + ' ' + keyword + ' ' + word, expected(keyword, word)))
    for word in ('bigger', 'smaller'):                     # numbers that differ late, by length, or not at all
        for a, b in [(842, 837), (837, 842), (7, 7), (1000, 999), (999, 1000), (5, 12), (90, 9),
                     (123456789012, 123456789013), (123456789013, 123456789012), (99999999999, 100000000000),
                     (4000000, 4000000), (60, 59)]:
            want = a > b if word == 'bigger' else a < b
            out.append(('is %d %s than %d' % (a, word, b), 'yes' if want else 'no'))
    for a, b in [(0, 0), (4, 3), (7, 8), (9, 1), (20, 17), (58, 67), (99, 99), (99, 1), (5, 97), (50, 50),
                 (19, 81), (90, 9)]:                       # no carry, one carry, both carries, uneven lengths
        out.append(('what is %d plus %d' % (a, b), str(a + b)))
    out.append(('what is 7 times 8', '7 times 8 is 56.'))  # the trained general model still answers
    return out


def answers_in(lines):
    return [lines[i - 1] for i, line in enumerate(lines) if line.startswith('answer ms=')]


def report(name, got):
    want = [a for _, a in vectors()]
    bad = [(q, a, g) for (q, a), g in zip(vectors(), got) if a != g]
    if len(got) != len(want) or bad:
        print('%s: FAILED, %d answers for %d questions, %d wrong' % (name, len(got), len(want), len(bad)))
        for q, a, g in bad[:5]:
            print('   %r\n      want %r\n      got  %r' % (q, a, g))
        return False
    print('%s: all %d answers exact' % (name, len(want)))
    return True


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['--check']:
        text = Path(args[1]).read_text(errors='replace').replace('\r', '')
        sys.exit(0 if report(args[1], answers_in(text.splitlines())) else 1)
    with tempfile.TemporaryDirectory() as tmp:
        if args[:1] == ['--write']:
            rt = Runtime(sys.executable, tmp, MODELS)       # the executable copied in is a placeholder
            dest = Path(args[1])
            dest.mkdir(parents=True, exist_ok=True)
            for path in rt.dir.iterdir():
                if path.name != 'EXPERT.EXE':
                    shutil.copy(path, dest / path.name)
            (dest / 'CONFORM.IN').write_bytes(('\r\n'.join(q for q, _ in vectors()) + '\r\n').encode())
            (dest / 'CONFORM.BAT').write_bytes(b'@echo off\r\nEXPERT < CONFORM.IN > CONFORM.LOG\r\n')
            print('wrote %d questions and %d models to %s' % (len(vectors()), len(MODELS) + 1, dest))
            sys.exit(0)
        ok = True
        for n, exe in enumerate(args):
            rt = Runtime(exe, Path(tmp) / str(n), MODELS)
            ok &= report(exe, rt.ask([q for q, _ in vectors()]))
        sys.exit(0 if ok else 1)
