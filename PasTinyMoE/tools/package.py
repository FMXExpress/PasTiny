"""Build DOS editions from complete fixed-shape TNY2 files."""
import argparse
import hashlib
import json
import re
import shutil
import struct
import zlib
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

def field(value, width):
    raw = value.encode("ascii")
    if len(raw) > width or any(c < 32 or c > 126 for c in raw):
        raise ValueError(value)
    return bytes([len(raw)]) + raw.ljust(width, b"\0")

def build(entries, exe, dest, extras=None, original=None):
    if not 1 <= len(entries) <= 128:
        raise ValueError("catalog capacity")
    ids, names = set(), set()
    records = bytearray(b"PEC1" + bytes([len(entries)]))
    dest.mkdir(parents=True, exist_ok=False)
    shutil.copyfile(exe, dest / "EXPERT.EXE")
    for entry in entries:
        ident, name = entry["id"], entry["name"]
        if not 1 <= ident <= 128 or ident in ids or name in names or not re.fullmatch(r"[A-Z0-9_]{1,8}\.BIN", name):
            raise ValueError(entry)
        ids.add(ident)
        names.add(name)
        model = Path(entry["source"]).read_bytes()
        if hashlib.sha256(model).hexdigest() != entry["sha256"]:
            raise ValueError("source hash mismatch")
        if len(model) != 381808 or model[:12] != struct.pack("<4s4H", b"TNY2",96,4,4,256):
            raise ValueError("unsupported TNY2")
        (dest / name).write_bytes(model)
        records += bytes([ident]) + field(name,12) + field(entry["title"],28) + field(entry["keyword"],20) + struct.pack("<I",zlib.crc32(model))
    (dest / "EXPERTS.CAT").write_bytes(records)
    for name in ("CHECK.BAT","CHECK.IN","NOTICE.TXT"):
        root = Path(__file__).resolve().parents[1]
        folder = extras or (root if name == "NOTICE.TXT" else root / "tests")
        shutil.copyfile(folder / name, dest / name)
    if original is not None:
        model = original.read_bytes()
        if hashlib.sha256(model).hexdigest() != "4b603237070ad9084433537bf8d6c7470d0fc583e6a4f1f03c00cd17264e7095":
            raise ValueError("original Tiny model hash mismatch")
        (dest / "TINY.BIN").write_bytes(model)
    with ZipFile(dest.with_suffix(".ZIP"),"w",ZIP_DEFLATED) as archive:
        for path in sorted(dest.iterdir()):
            archive.write(path,path.name)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("exe",type=Path)
    parser.add_argument("dest",type=Path)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--manifest",type=Path)
    group.add_argument("--fixtures",type=int)
    args = parser.parse_args()
    if args.manifest:
        entries=json.loads(args.manifest.read_text())
    else:
        entries=[dict(id=i,name=f"E{i:03}.BIN",title=f"Baseline fixture {i}",keyword={2:"capital",3:"times"}.get(i,""),source="TINY.BIN",sha256="4b603237070ad9084433537bf8d6c7470d0fc583e6a4f1f03c00cd17264e7095") for i in range(1,args.fixtures+1)]
    build(entries,args.exe,args.dest)
