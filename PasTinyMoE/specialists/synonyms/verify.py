"""Verify released binary weights, hardware-mode smoke and paired DOS transcript."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile
root=Path(__file__).resolve().parent
rows=[r for line in (root/"results.jsonl").read_text().splitlines() if (r:=json.loads(line))["mode"]=="auto"]
lines=(root/"ALL.LOG").read_text().splitlines()
active=None
seen=[]
for i,line in enumerate(lines):
    if line.startswith("active "): active=int(line.split()[1])
    elif line.startswith("answer ms="): seen.append((active,lines[i-1]))
    elif line.startswith("Choose an expert"): seen.append((0,None))
assert "FPU yes" in lines and len(rows)==32
assert seen[:32]==[(r["active"],r["answer"]) for r in rows]
assert len(seen)==50 and [item[0] for item in seen[32:48]]==[41,46]*8
assert seen[-2:]==[(0,None),(0,None)]
off=(root/"NOFPU.LOG").read_text().splitlines()
assert "FPU no" in off and "Very fast." in off and "swift" in off
heap=[s for s in off if s.startswith("heap=")]
assert heap[1]==heap[-1]
with ZipFile(root.parents[1]/"dist/SPEC10.ZIP") as z:
    names=[n for n in z.namelist() if n.endswith(".BIN")]
    assert z.testzip() is None and len(names)==len({hashlib.sha256(z.read(n)).digest() for n in names})==10
    for n in names: assert z.read(n)==(root.parent/"models"/n).read_bytes()
    assert z.read("EXPERT.EXE")==(root.parents[1]/"bin/SPEC10.EXE").read_bytes()
print("Verified 32 target outputs, 8 routing pairs, 2 clarifications, no-FPU smoke and 10 distinct models.")
