"""Build a PasTinyJev runtime directory and ZIP from a manifest.

  python3 tools/package.py JEV.EXE DEST [--manifest models.json]

The default manifest is models.json beside JEV.PAS.  Each entry has id, name
(8.3, upper case, .BIN), title, keyword and source.  Every model must be a
complete TNY2 file of the pinned shape (96 wide, 4 layers, 4 heads, 256 hidden,
381,808 bytes).  EXPERTS.CAT is the PasTinyMoE catalog format, unchanged.
"""
import argparse
import json
import re
import shutil
import struct
import zlib
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]


def field(value, width):
    raw = value.encode('ascii')
    if len(raw) > width or any(c < 32 or c > 126 for c in raw):
        raise ValueError(value)
    return bytes([len(raw)]) + raw.ljust(width, b'\0')


def build(entries, exe, dest, exe_name='JEV.EXE'):
    if not 1 <= len(entries) <= 128:
        raise ValueError('catalog capacity')
    ids, names = set(), set()
    records = bytearray(b'PEC1' + bytes([len(entries)]))
    dest.mkdir(parents=True, exist_ok=False)
    shutil.copy(exe, dest / exe_name)
    for entry in entries:
        ident, name = entry['id'], entry['name']
        if not 1 <= ident <= 128 or ident in ids or name in names or not re.fullmatch(r'[A-Z0-9_]{1,8}\.BIN', name):
            raise ValueError(entry)
        ids.add(ident)
        names.add(name)
        model = (ROOT / entry['source']).read_bytes()
        if len(model) != 381808 or model[:12] != struct.pack('<4s4H', b'TNY2', 96, 4, 4, 256):
            raise ValueError('unsupported TNY2: ' + entry['source'])
        (dest / name).write_bytes(model)
        records += (bytes([ident]) + field(name, 12) + field(entry['title'], 28) + field(entry['keyword'], 20)
                    + struct.pack('<I', zlib.crc32(model)))
    (dest / 'EXPERTS.CAT').write_bytes(records)
    for name in ('DEMO.IN', 'DEMO.BAT', 'README.TXT', 'NOTICE.TXT'):
        src = ROOT / name if (ROOT / name).exists() else ROOT / 'tests' / name
        if src.exists():
            (dest / name).write_bytes(src.read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
    with ZipFile(dest.with_suffix('.ZIP'), 'w', ZIP_DEFLATED) as archive:
        for path in sorted(dest.iterdir()):
            archive.write(path, path.name)
    return sum(p.stat().st_size for p in dest.iterdir())


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('exe', type=Path)
    parser.add_argument('dest', type=Path)
    parser.add_argument('--manifest', type=Path, default=ROOT / 'models.json')
    parser.add_argument('--exe-name', default='JEV.EXE')
    args = parser.parse_args()
    print(build(json.loads(args.manifest.read_text()), args.exe, args.dest, args.exe_name), 'bytes in', args.dest)
