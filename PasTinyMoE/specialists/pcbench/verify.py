"""Verify the saved TP7 transcripts against host outputs and observed FPU state."""
import json
from pathlib import Path

root=Path(__file__).resolve().parent
rows=[json.loads(line) for line in (root/"results.jsonl").read_text().splitlines()]
auto=[r for r in rows if r["mode"]=="auto"]
lines=(root/"ALL.LOG").read_text().splitlines()
answers=[lines[i-1] for i,line in enumerate(lines) if line.startswith("answer ms=")]
assert len(auto)==21 and all(r["active"]==3 for r in auto)
assert answers==[r["answer"] for r in auto]
assert "FPU yes" in lines and "FPU detected: yes" in lines
smoke=(root/"NOFPU.LOG").read_text().splitlines()
assert "FPU no" in smoke and "FPU detected: no" in smoke
assert "active 3 PC Workbench" in smoke and "Accelerates floating point math." in smoke
assert "Use MEM for program heap or FPU for coprocessor detection." in smoke
assert sum(s.startswith("answer ms=") for s in smoke)==1
heap=[s for s in smoke if s.startswith("heap=")]
assert heap[1]==heap[-1]
print("21/21 DOS outputs match host; both FPU statuses and no-FPU model switch verified.")
