"""Check target outcomes against host outputs and verify that all weights differ."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

root=Path(__file__).resolve().parent
records=[json.loads(l) for l in (root/"results.jsonl").read_text().splitlines()]
auto=[r for r in records if r["mode"]=="auto"]
lines=(root/"ALL.LOG").read_text().splitlines()
answers=[lines[i-1] for i,l in enumerate(lines) if l.startswith("answer ms=")]
assert len(auto)==54 and answers==[r["answer"] for r in auto]
assert "FPU yes" in lines and any(l.startswith("Choose an expert") for l in lines)
smoke=(root/"NOFPU.LOG").read_text().splitlines()
assert "FPU no" in smoke and all(any(l.startswith(f"active {i} ") for l in smoke) for i in [42,43,44])
heap=[l for l in smoke if l.startswith("heap=")]
assert heap[1]==heap[-1]
with ZipFile(root.parents[1]/"dist/SPEC8.ZIP") as z:
    assert z.testzip() is None
    bins=[n for n in z.namelist() if n.endswith(".BIN")]
    assert len(bins)==len({hashlib.sha256(z.read(n)).digest() for n in bins})==8
    assert z.read("EXPERT.EXE")==(root.parents[1]/"bin/SPEC8.EXE").read_bytes()
print("54/54 target outputs match; mixed-domain clarification, no-FPU smoke and eight distinct weights verified.")
