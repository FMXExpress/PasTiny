#!/usr/bin/env python3
"""Write EXPERTS.CAT for the six expert files in this directory.

  python3 tools/package.py
"""
import argparse
import struct, zlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ENTRIES = [(1, 'SCREEN.BIN', 'Screen calls', 'screen'), (2, 'SOUND.BIN', 'Sound and time calls', 'sound'),
           (3, 'TEXT.BIN', 'Text calls', 'text'), (4, 'TASKS.BIN', 'Small programs', 'tasks'),
           (5, 'RECIPES.BIN', 'Recipes', 'recipes'), (6, 'SLOTS.BIN', 'Small programs, slots', 'slots')]


def field(value, width):
    raw = value.encode('ascii')
    assert len(raw) <= width
    return bytes([len(raw)]) + raw.ljust(width, b'\0')


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--factors', type=Path, help='directory with screen.T16, sound.T16, text.T16, tasks.T16, recipes.T16 and slots.T16')
args = parser.parse_args()
destination = args.factors or root

out = bytearray(b'PEC1' + bytes([len(ENTRIES)]))
for ident, name, title, keyword in ENTRIES:
    if args.factors:
        name = name.replace('.BIN', '.T16')
        model = (destination / (Path(name).stem.lower() + '.T16')).read_bytes()
        assert len(model) == 74608 and model[:4] == b'TF16', name
    else:
        model = (root / name).read_bytes()
        assert len(model) == 381808 and model[:4] == b'TNY2', name
    out += bytes([ident]) + field(name, 12) + field(title, 28) + field(keyword, 20) + struct.pack('<I', zlib.crc32(model))
(destination / 'EXPERTS.CAT').write_bytes(out)
print('EXPERTS.CAT', len(out), 'bytes')
