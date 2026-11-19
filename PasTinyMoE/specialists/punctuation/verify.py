"""Check packaged weights, target answers, ambiguity handling and no-FPU smoke."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile
root=Path(__file__).resolve().parent
rows=[json.loads(l) for l in (root/"results.jsonl").read_text().splitlines() if json.loads(l)["mode"]=="auto"]
lines=(root/"ALL.LOG").read_text().splitlines()
actual=[]
for i,s in enumerate(lines):
    if s.startswith("answer ms="): actual.append(lines[i-1])
    if s.startswith("Choose an expert"): actual.append(None)
assert "FPU yes" in lines and len(rows)==30 and actual==[r["answer"] for r in rows]+[None]
off=(root/"NOFPU.LOG").read_text().splitlines()
assert "FPU no" in off and "active 45 Punctuation" in off
assert sum(s.startswith("answer ms=") for s in off)==1
heaps=[s for s in off if s.startswith("heap=")]
assert len(heaps)>=3 and heaps[1]==heaps[-1]
with ZipFile(root.parents[1]/"dist/SPEC9.ZIP") as z:
    models=[n for n in z.namelist() if n.endswith(".BIN")]
    assert len(models)==len({hashlib.sha256(z.read(n)).digest() for n in models})==9
    for name in models:
        assert z.read(name)==(root.parent/"models"/name).read_bytes()
    assert z.read("EXPERT.EXE")==(root.parents[1]/"bin/SPEC9.EXE").read_bytes()
print("DOS replay, clarification, no-FPU switch and nine packaged weights verified.")
