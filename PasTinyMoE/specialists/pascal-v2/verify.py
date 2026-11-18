"""Check a no-FPU TP7 replay against the candidate's pinned host transcript."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parent
path = Path(sys.argv[1]) if len(sys.argv)>1 else root/"TP7.LOG"
lines = path.read_text().splitlines()
if "FPU no" not in lines or "active 2 Turbo Pascal Coach" not in lines:
    raise SystemExit("Replay must report no FPU and select expert 2.")
rows = [json.loads(line) for line in (root/"after.jsonl").read_text().splitlines()]
answers = [lines[i-1] for i, line in enumerate(lines) if line.startswith("answer ms=")]
if len(answers)!=len(rows):
    raise SystemExit(f"Expected {len(rows)} answers, found {len(answers)}")
for row, answer in zip(rows,answers):
    if answer != row["output"]:
        raise SystemExit(f"{row['question']}: host {row['output']!r}, DOS {answer!r}")
print(f"{len(answers)}/{len(rows)} host outputs reproduced on TP7 without an FPU.")
