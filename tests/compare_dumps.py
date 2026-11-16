"""Print text cell differences. Usage: python3 tests/compare_dumps.py OLD NEW

Both inputs must be raw 4000-byte 80x25 character/attribute dumps. Nothing is
silently masked: clock, speed, status time and boot version are labelled.
"""
import sys
from pathlib import Path
old, new = (Path(arg).read_bytes() for arg in sys.argv[1:])
assert len(old) == len(new) == 4000
count = 0
for offset in range(0, 4000, 2):
    a, b = old[offset:offset+2], new[offset:offset+2]
    if a == b:
        continue
    x, y = offset//2 % 80 + 1, offset//2//80 + 1
    hint = ''
    if y == 1 and 73 <= x <= 77:
        hint = 'clock'
    elif y == 15 and 61 <= x <= 79:
        hint = 'speed (SCREEN.DMP)'
    elif y == 25 and x >= 65:
        hint = 'status time'
    elif y == 9 and x >= 29:
        hint = 'version (BOOT.DMP)'
    print(f'({x:2},{y:2}) {a.hex()} -> {b.hex()} {hint}')
    count += 1
print(f'{count} differing cells')
