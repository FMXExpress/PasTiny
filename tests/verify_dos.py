"""Verify a DOS transcript or deterministic regions of UI/sound dumps.

Usage:
 python3 tests/verify_dos.py answers DOS.TXT tests/gold_c.txt
 python3 tests/verify_dos.py ui ORIGINAL_DIR PASCAL_DIR
"""
from pathlib import Path
import sys

def transcript(path):
    return [line for line in Path(path).read_text().splitlines()
            if not line.startswith('   [')]

if sys.argv[1] == 'answers':
    assert transcript(sys.argv[2]) == transcript(sys.argv[3]), 'transcripts differ'
    print('DOS: complete transcript matches all 60 C reference answers')
else:
    old, new = map(Path, sys.argv[2:])
    for filename in ('BOOT.DMP', 'SCREEN.DMP'):
        a, b = ((p / filename).read_bytes() for p in (old, new))
        assert len(a) == len(b) == 4000
        changed = 0
        for offset in range(0, 4000, 2):
            if a[offset:offset+2] == b[offset:offset+2]:
                continue
            x, y = offset//2 % 80 + 1, offset//2//80 + 1
            allowed = ((y == 9 and x >= 29) if filename == 'BOOT.DMP' else
                       ((y == 1 and 73 <= x <= 77) or
                        (y == 15 and 61 <= x <= 79) or (y == 25 and x >= 65)))
            assert allowed, (filename, x, y, a[offset:offset+2], b[offset:offset+2])
            changed += 1
        print(f'{filename}: only permitted time/version cells differ ({changed} cells)')
    sound = []
    for folder in (old, new):
        lines = (folder / 'SOUND.LOG').read_text().splitlines()
        # Boot rain and logo settling use different random generators.
        lines = lines[lines.index('392 55'):]
        normalized = []
        for line in lines:
            parts = line.split()
            if (len(parts) == 2 and parts[0].isdigit() and parts[1] == '3'
                    and 2400 <= int(parts[0]) <= 3450):
                line = 'SCANNER 3'
            normalized.append(line)
        sound.append(normalized)
    assert sound[0] == sound[1], 'deterministic sound sequence differs'
    print(f'SOUND.LOG: {len(sound[0])} deterministic events match')
