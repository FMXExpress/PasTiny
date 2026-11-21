#!/usr/bin/env python3
"""Write EXPERTS.CAT for the four expert files in this directory.

  python3 tools/package.py
"""
import struct, zlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ENTRIES = [(1, 'SCREEN.BIN', 'Screen calls', 'screen'), (2, 'SOUND.BIN', 'Sound and time calls', 'sound'),
           (3, 'TEXT.BIN', 'Text calls', 'text'), (4, 'TASKS.BIN', 'Small programs', 'tasks')]


def field(value, width):
    raw = value.encode('ascii')
    assert len(raw) <= width
    return bytes([len(raw)]) + raw.ljust(width, b'\0')


out = bytearray(b'PEC1' + bytes([len(ENTRIES)]))
for ident, name, title, keyword in ENTRIES:
    model = (root / name).read_bytes()
    assert len(model) == 381808 and model[:4] == b'TNY2', name
    out += bytes([ident]) + field(name, 12) + field(title, 28) + field(keyword, 20) + struct.pack('<I', zlib.crc32(model))
(root / 'EXPERTS.CAT').write_bytes(out)
print('EXPERTS.CAT', len(out), 'bytes')
