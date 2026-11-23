#!/usr/bin/env python3
"""Check PasTinyAsm with a native FPC build of MAKECOM.

  python3 tests/test_asm.py ./MAKECOM [--models]

Always: the library include is up to date, and for requests written as calls
(no model involved) the .COM file written by the program is byte for byte what
NASM makes from the program's own .ASM listing plus the routines in LIB.ASM.

With --models (needs SCREEN.BIN, SOUND.BIN, TEXT.BIN and EXPERTS.CAT here):
plain-language requests give the expected plans, bad steps are refused, and
each expert is scored on 300 fresh steps in trained wordings, 300 in the
first version's held-out wordings (trained on since) and 300 in wordings it
was never trained on.  --show lists some of the wrong calls.
"""
import random, re, shutil, subprocess, sys, tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tools')); sys.path.insert(0, str(root / 'training'))
import buildlib, gen_asm, gen_recipes, gen_tasks

exe = Path(sys.argv[1]).resolve()
FILES = ['EXPERTS.CAT', 'SCREEN.BIN', 'SOUND.BIN', 'TEXT.BIN', 'TASKS.BIN', 'RECIPES.BIN']


def run(dest, lines):
    return subprocess.run([exe], input='\n'.join(lines) + '\nquit\n', text=True, capture_output=True, cwd=dest).stdout


def nasm_build(listing, tmp):
    """Assemble a listing written by MAKECOM, with the library routines put in."""
    src = {r['name']: r['src'] for r in buildlib.routines()}
    out = ['bits 16', 'cpu 8086']
    for line in listing.splitlines():
        m = re.match(r'; routine (\w+) from LIB.ASM goes here', line)
        out += ['L_' + m[1] + ':'] + src[m[1]] if m else [line]
    a, b = Path(tmp) / 'ref.asm', Path(tmp) / 'ref.com'
    a.write_text('\n'.join(out) + '\n')
    subprocess.run(['nasm', '-f', 'bin', '-o', str(b), str(a)], check=True)
    return b.read_bytes()


DIRECT = [
    'CLS, FLASH 3, BEEP 440 300',
    'print "Hello, World!", NEWLINE, NUMBER 65535, repeat 3',
    'GOTO 5 10, COLOR 1, INK 14, BORDER 4, HIDE, SHOW, SIREN 2, SCALE, WAIT 1000, KEY',
    'say "one", newline and say "two" then wait 60000; repeat 100.',
    'cls',
    'FOR I=10 DOWNTO 1:OUT I:BEEP:NEXT:ECHO liftoff',
    'for i=1 to 10:out i*7:next. let s=0:for i=1 to 100:let s=s+i:next:out s',
    'INPUT A:INPUT B:OUT A+B:OUT A*B:OUT A-B:OUT A/B',
    'INPUT A:IF A>10:ECHO big:ELSE:ECHO small:END:IF A<>7:BEEP 880 100:END',
    'TIMES 3:FOR I=0 TO 7:COLOR I:WAIT 300:NEXT:END; repeat 2',
    'INPUT A:TIMES A:FLASH:SIREN:WAIT:END:FOR I=1 TO A:BEEP I*100+200 100:NEXT',
    'LET X=2+3*4:OUT X:LET Y=X*X/7-1:OUT Y:IF X>=14:IF Y<=27:NUMBER X+Y:NL:END:END',
]
BADLINES = ['FOR I=9 TO 3:OUT I:NEXT', 'INPUT A:IF A<=7:ECHO yes:ELSE:END', 'FOR I=3 DOWNTO 9:OUT I:NEXT', 'NEXT', 'OUT', 'LET 5=A', 'FLASH 99', 'BEEP 440', 'IF A:BEEP:END', 'TIMES 3:BEEP:NEXT',
            'OUT 70000', 'JUMP 5', 'OUT A+', 'END']
PLANS = [   # request, the calls it must become
    ('make screen flash, play sound', ['FLASH 3', 'BEEP 440 300']),
    ('Clear the screen, make the screen blue, say hello world, wait two seconds, beep',
     ['CLS', 'COLOR 1', 'PRINT hello world', 'WAIT 2000', 'BEEP 440 300']),
    ('flash the screen 5 times and play a siren then wait for a key', ['FLASH 5', 'SIREN 2', 'KEY']),
    ('beep at 880 hertz for half a second, do it 3 times', ['BEEP 880 500', 'REPEAT 3']),
    ('hide the cursor, go to row 12 column 30, print "Press a key", wait for a key, show the cursor',
     ['HIDE', 'GOTO 12 30', 'PRINT Press a key', 'KEY', 'SHOW']),
    ('print the number 1234, new line, play a tune', ['NUMBER 1234', 'NEWLINE', 'SCALE']),
]
BLOCKS = [
    (['repeat 3 times:', 'CLS', 'count from 1 to 4:', 'print the count', 'end', 'NEWLINE', 'end', 'print "bye"'],
     ['  1 TIMES 3', '  2   CLS', '  3   FOR X=1 TO 4', '  4     OUT X', '  5   NEXT', '  6   NEWLINE', '  7 END',
      '  8 PRINT "bye"', '   >']),
    (['count down from 3: count to 2: print the count', 'bottom', 'SCALE', 'go 2', 'HIDE', 'top', 'CLS'],
     ['  1 CLS', '   >', '  2 FOR X=3 DOWNTO 1', '  3   HIDE', '  4   FOR Y=1 TO 2', '  5     OUT Y', '  6   NEXT',
      '  7 NEXT', '  8 SCALE']),
    (['forever: KEY', 'if the key is q: stop', 'end', 'if the key is space: BEEP 880 100', 'end', 'else', 'end'],
     None),      # an ELSE outside an IF does not fit, and nothing may be lost
    (['INPUT A', 'if it is bigger than 10: print "big"', 'else', 'print "small"', 'end', 'if it is not 7: SIREN 1',
      'tab', 'back', 'back', 'del 2'],
     ['  1 INPUT A', '   >', '  2 IF A<>7', '  3   SIREN 1', '  4 END']),
    (['INPUT A', 'if it is bigger than 10: print "big"', 'else', 'print "small"', 'end', 'CLS'],
     ['  1 INPUT A', '  2 IF A>10', '  3   PRINT "big"', '  4 ELSE', '  5   PRINT "small"', '  6 END', '  7 CLS', '   >']),
    (['TIMES 2:', 'FOR I=1 TO 3:', 'OUT I*I', 'end', 'end', 'del 3', 'del 1', 'print "empty now"', 'up', 'KEY'],
     ['  1 KEY', '   >', '  2 PRINT "empty now"']),
]
EDITS = [   # changing lines in place: (session, outline expected)
    (['TIMES 2:', 'CLS', 'BEEP 440 300', 'end', 'print "a"', 'edit 3 BEEP 880 100', 'edit 1 TIMES 5', 'edit 5 print "b"',
      'edit 2 HIDE, SHOW'],
     ['  1 TIMES 5', '  2   HIDE', '  3   SHOW', '   >  ', '  4   BEEP 880 100', '  5 END', '  6 PRINT "b"']),
    (['count from 1 to 3:', 'print the count', 'end', 'edit 1 TIMES 4', 'edit 2 CLS', 'edit 1 count down from 9 to 7',
      'edit 2 print the count', 'edit 3 CLS', 'edit 2 JUMP', 'edit 1 CLS', 'edit 9 CLS'],
     ['  1 FOR X=9 DOWNTO 7', '  2   OUT X', '   >  ', '  3 NEXT']),
]
REFUSED = ['format the hard disk', 'FLASH 99', 'beep at 5 hertz', 'what is the capital of peru']

# A held-out wording must not be one the training patterns can produce.  (The text
# expert is left out: its texts are free, so "print out hello" can always be read
# as a trained "print" followed by the text "out hello".)
def _form(q):
    colors = sorted({c for c, _ in gen_asm.COLORS8 + gen_asm.COLORS16}, key=len, reverse=True)
    q = re.sub(r'\b(%s)\b' % '|'.join(colors), 'C', q)
    return ' '.join('N' if (w.isdigit() or w in gen_asm.WORDS) else w for w in q.split())
for _e in ('screen', 'sound'):
    _r = random.Random(1)
    _trained = {_form(gen_asm.make(_r, _e)[0]) for _ in range(60000)}
    _both = {_form(gen_asm.make(_r, _e, pool=gen_asm.HELD[_e])[0]) for _ in range(3000)} & _trained
    assert not _both, 'held-out wordings that are also trained: %s' % sorted(_both)
assert buildlib.render()[0].split() == (root / 'LIB.INC').read_text().split(), 'LIB.INC is out of date: run tools/buildlib.py'
with tempfile.TemporaryDirectory() as tmp:
    dest = Path(tmp) / 'run'; dest.mkdir()
    models = '--models' in sys.argv
    for name in ('ASK.SCR', 'MAKECOM.HLP'):
        shutil.copyfile(root / name, dest / name)
    for name in FILES:
        if models:
            shutil.copyfile(root / name, dest / name)
    if not models:                       # any valid model will do: no step reaches it
        import struct, zlib
        tiny = (root.parent / 'PasTinyMoE/TINY.BIN').read_bytes()
        cat = bytearray(b'PEC1\x05')
        for i, name in enumerate(FILES[1:], 1):
            (dest / name).write_bytes(tiny)
            f = lambda v, w: bytes([len(v)]) + v.encode().ljust(w, b'\0')
            cat += bytes([i]) + f(name, 12) + f('x', 28) + f('x', 20) + struct.pack('<I', zlib.crc32(tiny))
        (dest / 'EXPERTS.CAT').write_bytes(cat)
    for req in DIRECT:
        out = run(dest, [req])
        assert 'wrote OUT.COM' in out and '(no model)' in out, out
        com, ref = (dest / 'OUT.COM').read_bytes(), nasm_build((dest / 'OUT.ASM').read_text(), tmp)
        assert com == ref, (req, com.hex(), ref.hex())
    print('Compiler: %d programs match NASM byte for byte.' % len(DIRECT))
    if not models:
        for bad in BADLINES:             # not valid lines; with any model behind them they must not be written
            out = run(dest, ['name bad', bad])
            assert 'wrote' not in out and not (dest / 'BAD.COM').exists(), (bad, out)
        print('Compiler: %d invalid lines write nothing.' % len(BADLINES))
    # Block mode: words before a colon open a block, later lines go inside it, and
    # the insertion point can be moved.  None of these lines needs a model.
    for script, want in BLOCKS:
        out = run(dest, script + ['show'])
        if want is None:
            assert 'does not fit here' in out and '\n  9 END\n' in out and '\n 10 ' not in out, out
            continue
        got = [l for l in out[out.rindex('wrote'):].splitlines()[1:] if l.strip() and not l.startswith(('at ', '> '))]
        assert got == want, (script, got, out)
        assert (dest / 'OUT.COM').read_bytes() == nasm_build((dest / 'OUT.ASM').read_text(), tmp), script
    print('Blocks: %d sessions give the expected outline, and their programs match NASM.' % len(BLOCKS))
    # The interviewer: "make an adventure" is answered with questions, and the
    # replies alone give the program.  Quoted replies need no model.
    out = run(dest, ['make an adventure', '"a dark cave"', 'n, e and space', '"a pit", stop', '"a door"', 'o', '"free"', '',
                     'perhaps', 'yes', '"you walk back"', '', '', 'no', '"hm"', 'CLS', 'show', 'help'])
    got = [l for l in out[out.rindex('> show'):out.rindex('> help')].splitlines()[1:] if l.strip()]
    want = ['FOREVER', ' PRINT "a dark cave"', ' NEWLINE', ' KEY', " IF K='n'", '  PRINT "a pit"', '  NEWLINE', '  STOP', ' END',
            " IF K='e'", '  PRINT "a door"', '  NEWLINE', '  KEY', "  IF K='o'", '   PRINT "free"', '   NEWLINE', '   STOP',
            '  END', '  PRINT "you walk back"', '  NEWLINE', ' END', ' IF K=32', ' END', ' PRINT "hm"', ' NEWLINE', 'END', 'CLS']
    want = ['%3d %s%s' % (i + 1, ' ' * (len(w) - len(w.lstrip())), w) for i, w in enumerate(want)] + ['   >']
    assert got == want, (got, out)
    for q in ('What does the player see first?', 'What happens when they press space?', 'That is the whole program'):
        assert q in out, (q, out)
    assert out.count('Does the game stop there?') == 3 and 'asks you questions' in out, out
    assert (dest / 'OUT.COM').read_bytes() == nasm_build((dest / 'OUT.ASM').read_text(), tmp)
    out = run(dest, ['ask menu', 'cancel', 'CLS', 'show'])
    assert 'What does the menu show?' in out and 'No more questions.' in out and '  2   CLS' in out, out
    # "ask for a number ..." is a request, not the ASK command.
    out = run(dest, ['ask for a number and print its double', 'INPUT A', 'show'])
    assert 'questions' not in out and 'What does' not in out and '  1 INPUT A' in out, out
    out = run(dest, ['write the words old story', 'make a game of it please', 'print the story', 'INPUT A', 'show'])
    assert 'What does' not in out and '  1 INPUT A' in out, out
    out = run(dest, ['write a story program', 'cancel'])
    assert 'What does the player see first?' in out, out
    print('Interview: an adventure is built from replies to questions alone, and matches NASM.')
    for script, want in EDITS:
        out = run(dest, script + ['show'])
        got = [l for l in out[out.rindex('> show'):].splitlines()[1:] if l.strip() and not l.startswith('> ')]
        assert got == want, (script, got, out)
        assert (dest / 'OUT.COM').read_bytes() == nasm_build((dest / 'OUT.ASM').read_text(), tmp), script
    print('Edits: %d sessions that change lines in place give the expected outline and match NASM.' % len(EDITS))
    # A character in quotes keeps its case in code typed as it stands, in a block
    # opener and in a changed line: 'q' is 113, not 81.
    for script in (["KEY:IF K='q':STOP:END"], ["forever: KEY", "IF K='q': STOP"], ["IF K='x':", "CLS", "edit 1 IF K='q'"]):
        out = run(dest, script + ['show'])
        listing = (dest / 'OUT.ASM').read_text()
        assert "K='q'" in out and 'mov     ax,113' in listing and 'mov     ax,81' not in listing, (script, out)
        assert (dest / 'OUT.COM').read_bytes() == nasm_build(listing, tmp), script
    # Deleting the last line leaves no program files behind.
    for script in (['CLS', 'del 1'], ['TIMES 2:', 'CLS', 'del 1'], ['CLS', 'HIDE', 'del 1', 'del 1']):
        out = run(dest, script)
        assert 'removed' in out and not any((dest / ('OUT.' + e)).exists() for e in ('COM', 'ASM', 'SRC')), (script, out)
    # Text in quotes is printed exactly, spaces at its ends included.
    out = run(dest, ['print " two  spaces: "', 'show'])
    assert b' two  spaces: $' in (dest / 'OUT.COM').read_bytes() and 'PRINT " two  spaces: "' in out, out
    assert (dest / 'OUT.COM').read_bytes() == nasm_build((dest / 'OUT.ASM').read_text(), tmp)
    print('Review fixes: quoted characters keep their case; an emptied program removes its files.')
    # The program is also kept as text, and that text loads back to the same program.
    session = ['name keep', 'TIMES 2:', 'CLS', 'count from 1 to 3:', 'print the count', 'end', "IF K='q':", 'STOP', 'end', 'else',
               'print "Bye, now: done"', 'bottom', 'FOR I=1 TO 2:OUT I*I:NEXT']
    out = run(dest, session + ['show'])
    listing = out[out.rindex('> show'):]
    com, src = (dest / 'KEEP.COM').read_bytes(), (dest / 'KEEP.SRC').read_text()
    assert 'PRINT "Bye, now: done"' in src and "IF K='q'" in src, src
    (dest / 'KEEP.COM').unlink()
    out = run(dest, ['CLS', 'load keep', 'show'])
    assert 'loaded KEEP.SRC, 11 lines' in out and out[out.rindex('> show'):] == listing, out
    assert (dest / 'KEEP.COM').read_bytes() == com
    (dest / 'KEEP.COM').unlink()
    out = subprocess.run([exe, 'KEEP.SRC'], input='show\nquit\n', text=True, capture_output=True, cwd=dest).stdout
    assert out[out.rindex('> show'):] == listing and (dest / 'KEEP.COM').read_bytes() == com, out
    for bad in ('CLS\nJUMP 5\n', 'TIMES 2\nCLS\n', 'FOR I=1 TO 3\nCLS\nEND\n'):      # not code; a block left open; closed wrongly
        (dest / 'BAD.SRC').write_text(bad)
        out = run(dest, ['CLS', 'load bad', 'show'])
        assert 'loaded' not in out and not (dest / 'BAD.COM').exists(), out
    print('Source: a program kept as text loads back to the same listing and the same .COM file; 3 bad files are refused.')
    # EXPORT writes the same program as Turbo Pascal and as QBasic.  Here only the
    # text is checked; evidence/export has the Pascal compiled and run beside the .COM.
    export = exe.parent / 'EXPORT'
    if export.exists():
        for src in sorted((root / 'tests/export').glob('E?.SRC')):
            shutil.copyfile(src, dest / src.name)
            for kind in ('PAS', 'BAS'):
                r = subprocess.run([export, src.stem, kind], capture_output=True, text=True, cwd=dest)
                assert r.returncode == 0 and (dest / (src.stem + '.' + kind)).exists(), (src.name, kind, r.stdout)
        pas, bas = (dest / 'E1.PAS').read_text(), (dest / 'E1.BAS').read_text()
        for want in ('for R0 := 1 to 2 do begin', 'WriteLn(Word(I * I));', 'Y := X * X div 7 - 1;', 'for X := 3 downto 1 do begin',
                     'if Word(A - B) > 60000 then begin', "WriteLn('it''s zero');", 'end else begin', "Write('Bye, now: done');"):
            assert want in pas, want
        for want in ('FOR R0 = 1 TO 2', 'Y = X * X \\ 7 - 1', 'FOR X = 3 TO 1 STEP -1', 'IF X = 0 THEN', 'END IF', 'NEXT T1',
                     'PRINT "Bye, now: done";'):
            assert want in bas, want
        assert "if K = Ord('q') then begin" in (dest / 'E3.PAS').read_text() and 'until False;' in (dest / 'E3.PAS').read_text()
        (dest / 'BAD.SRC').write_text('TIMES 2\nCLS\n')
        r = subprocess.run([export, 'BAD', 'PAS'], capture_output=True, text=True, cwd=dest)
        assert r.returncode != 0 and not (dest / 'BAD.PAS').exists(), r.stdout
        print('Export: 6 programs written as Turbo Pascal and as QBasic; a program with an open block is refused.')
    if models:
        for req, want in PLANS:
            out = run(dest, [req])
            got = [re.sub(r'\s+\((no model|second choice)\)$', '', l).split(' -> ')[-1] for l in out.splitlines() if re.match(r'\d+ ', l)]
            assert got == want and 'wrote OUT.COM' in out, (req, got, out)
            assert (dest / 'OUT.COM').read_bytes() == nasm_build((dest / 'OUT.ASM').read_text(), tmp)
        for req in REFUSED:
            out = run(dest, ['name bad', req])
            assert 'nothing added' in out and not (dest / 'BAD.COM').exists(), (req, out)
        print('Plans: %d requests give the expected calls; %d bad requests write nothing.' % (len(PLANS), len(REFUSED)))
        sets = [('trained wordings', lambda e: None),
                ('first held-out set (now trained)', lambda e: gen_asm.V1HELD[e]),
                ('new wordings', lambda e: gen_asm.HELD[e])]
        for expert in ('screen', 'sound', 'text'):
            r = random.Random(5)
            for label, pool in sets:
                pairs = []
                while len(pairs) < 300:      # a text with "and" in it would be split into two steps
                    p = gen_asm.make(r, expert, pool=pool(expert))
                    if ' and ' not in ' %s ' % p[0]:
                        pairs.append(p)
                lines = run(dest, [x for q, _ in pairs for x in ('new', q)]).splitlines()
                rows = [re.sub(r'\s+\((no model|second choice)\)$', '', l) for l in lines if re.match(r'\d+ ', l)]
                assert len(rows) == len(pairs), (len(rows), len(pairs))
                right = sum('1 %s -> %s' % (q, a) == l for (q, a), l in zip(pairs, rows))
                wrong = [(q, l.split(' -> ')[-1], a) for (q, a), l in zip(pairs, rows) if ' -> ' in l and '1 %s -> %s' % (q, a) != l]
                print('%-6s %-33s %d right, %d refused, %d wrong but accepted, of %d'
                      % (expert, label + ':', right, len(pairs) - right - len(wrong), len(wrong), len(pairs)))
                if '--show' in sys.argv:
                    for w in sorted(set(wrong))[:12]:
                        print('         %s -> %s (want %s)' % w)
        # The tasks expert writes whole small programs.  "combinations" are parts it
        # was trained on, put together in ways that were held out of training.
        for label, split in (('trained shapes and combinations', 'seen'), ('held-out combinations', 'combo'),
                             ('first held-out wordings (now trained)', 'words1'), ('new wordings', 'words'),
                             ('numbers far outside training', 'far'), ('texts of several words in quotes', 'quoted')):
            r = random.Random(7)
            pairs = [gen_tasks.make(r, split) for _ in range(300)]
            lines = run(dest, [x for q, _ in pairs for x in ('new', q)]).splitlines()
            rows = [l for l in lines if re.match(r'\d+ ', l)]
            assert len(rows) == len(pairs), (len(rows), len(pairs))
            got = [re.sub(r'\s+\(second choice\)$', '', l).split(' -> ')[-1] if ' -> ' in l else None for l in rows]      # None = refused
            right = sum(g == a for (q, a), g in zip(pairs, got))
            wrong = [(q, g, a) for (q, a), g in zip(pairs, got) if g is not None and g != a]
            print('tasks  %-38s %d right, %d refused, %d wrong but accepted, of %d'
                  % (label + ':', right, len(pairs) - right - len(wrong), len(wrong), len(pairs)))
            if '--show' in sys.argv:
                for w in sorted(set(wrong))[:12]:
                    print('         %s\n            -> %s\n          want %s' % w)

        # The recipes expert expands a short request into steps, one step per question,
        # and the steps are then planned like typed sentences.
        def plan_of(lines):
            """The program lines MAKECOM ends up with for a session, or None if nothing was written."""
            out = run(dest, ['new'] + lines + ['show'])
            if 'wrote' not in out:
                return None
            return [re.sub(r'^\s*\d+\s+', '', l).strip() for l in out[out.rindex('> show'):].splitlines()[1:]
                    if re.match(r'\s*\d+ ', l)]

        # 1. every recipe's own steps, typed by hand, must be accepted: the second stage has to be sound
        r = random.Random(11); bad = []
        for name in gen_recipes.RECIPES:
            while True:
                q, steps = gen_recipes.request(r, 'seen')
                if gen_recipes.RECIPES[name][4][0].split('{')[0] in ' '.join(steps) and ', ' not in q and ' on a ' not in q:
                    break
            if plan_of(steps) is None:
                bad.append((name, steps))
        assert not bad, bad
        print('Recipes: the steps of all %d recipes, typed by hand, are accepted.' % len(gen_recipes.RECIPES))
        # 2. end to end: the request alone must give the same program as its steps typed by hand
        for label, split in (('trained recipes and pairs', 'seen'), ('held-out recipe and change pairs', 'combo'),
                             ('new names and wordings', 'words')):
            r = random.Random(13); right = refused = 0; wrong = []
            for _ in range(100):
                while True:                  # only requests whose steps fit the expert's window
                    q, steps = gen_recipes.request(r, split)
                    if gen_recipes.fits(q, steps):
                        break
                want, got = plan_of(steps), plan_of([q])
                if got is None:
                    refused += 1
                elif got == want:
                    right += 1
                else:
                    wrong.append((q, got, want))
            print('recipes %-34s %d right, %d refused, %d wrong but accepted, of 100 requests'
                  % (label + ':', right, refused, len(wrong)))
            if '--show' in sys.argv:
                for w in wrong[:6]:
                    print('         %s\n            -> %s\n          want %s' % w)
