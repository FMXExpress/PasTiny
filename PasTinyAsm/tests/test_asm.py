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
import buildlib, gen_asm

exe = Path(sys.argv[1]).resolve()
FILES = ['EXPERTS.CAT', 'SCREEN.BIN', 'SOUND.BIN', 'TEXT.BIN']


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
]
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
REFUSED = ['format the hard disk', 'FLASH 99', 'beep at 5 hertz', 'what is the capital of peru']

assert buildlib.render()[0].split() == (root / 'LIB.INC').read_text().split(), 'LIB.INC is out of date: run tools/buildlib.py'
with tempfile.TemporaryDirectory() as tmp:
    dest = Path(tmp) / 'run'; dest.mkdir()
    models = '--models' in sys.argv
    for name in FILES:
        if models:
            shutil.copyfile(root / name, dest / name)
    if not models:                       # any valid model will do: no step reaches it
        import struct, zlib
        tiny = (root.parent / 'PasTinyMoE/TINY.BIN').read_bytes()
        cat = bytearray(b'PEC1\x03')
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
    print('Writer: %d programs match NASM byte for byte.' % len(DIRECT))
    if models:
        for req, want in PLANS:
            out = run(dest, [req])
            got = [re.sub(r'\s+\(no model\)$', '', l).split(' -> ')[-1] for l in out.splitlines() if re.match(r'\d+ ', l)]
            assert got == want and 'wrote OUT.COM' in out, (req, got, out)
            assert (dest / 'OUT.COM').read_bytes() == nasm_build((dest / 'OUT.ASM').read_text(), tmp)
        for req in REFUSED:
            out = run(dest, ['name bad', req])
            assert 'nothing written' in out and not (dest / 'BAD.COM').exists(), (req, out)
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
                lines = run(dest, [q for q, _ in pairs]).splitlines()
                rows = [re.sub(r'\s+\(no model\)$', '', l) for l in lines if re.match(r'\d+ ', l)]
                assert len(rows) == len(pairs), (len(rows), len(pairs))
                right = sum('1 %s -> %s' % (q, a) == l for (q, a), l in zip(pairs, rows))
                wrong = [(q, l.split(' -> ')[-1], a) for (q, a), l in zip(pairs, rows) if ' -> ' in l and '1 %s -> %s' % (q, a) != l]
                print('%-6s %-33s %d right, %d refused, %d wrong but accepted, of %d'
                      % (expert, label + ':', right, len(pairs) - right - len(wrong), len(wrong), len(pairs)))
                if '--show' in sys.argv:
                    for w in sorted(set(wrong))[:12]:
                        print('         %s -> %s (want %s)' % w)
