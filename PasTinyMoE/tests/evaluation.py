"""Exercise report generation using existing regression examples and capacity fixtures."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
questions = (root / "tests/questions.txt").read_text().splitlines()
answers = [s[4:] for s in (root / "tests/gold_c.txt").read_text().splitlines() if s.startswith(">   ")]
with tempfile.TemporaryDirectory() as temp:
    directory = Path(temp)
    data = directory / "reference.jsonl"
    samples = [dict(question=questions[i], answer=answers[i], expert=expert, group=group)
               for i, expert, group in [(0, 2, "capital"), (8, 3, "arithmetic")]]
    data.write_text("".join(json.dumps(sample)+"\n" for sample in samples))
    manifest = directory / "manifest.json"
    manifest.write_text(json.dumps(dict(file=data.name, source="PasTiny regression suite",
        authorization="regression only", split="test", sha256=hashlib.sha256(data.read_bytes()).hexdigest())))
    report = directory / "report.json"
    result = subprocess.run([sys.executable, root / "tools/evaluate.py", Path(sys.argv[1]).resolve(),
        root / "dist/FLOPPY3", manifest, "--report", report], check=True, text=True, capture_output=True)
    detail = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(detail)==6 and all(r["exact"] for r in detail)
    summary = json.loads(report.read_text())
    for mode in ("baseline","oracle","auto"):
        metrics = summary["metrics"][mode]
        assert metrics["overall"]["exact"]==2 and set(metrics["groups"])=={"arithmetic","capital"}
    assert summary["metrics"]["auto"]["overall"]["intended_expert_selected"]==2
    assert summary["metrics"]["baseline"]["overall"]["intended_expert_selected"]==0
    assert len(set(summary["model_sha256"].values()))==1
print("Passed: 3 modes, 2 groups, routing counts and fixture identity.")
