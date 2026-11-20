"""Compare the original weights and SPEC60 on the same two prompt collections."""
import json
import sys
from pathlib import Path

batch = Path(__file__).resolve().parent
project = batch.parents[1]
sys.path.insert(0, str(project / "tools"))
from evaluate import evaluate

exe, runtime, general = (Path(arg).resolve() for arg in sys.argv[1:])
tests = project.parent / "tests"
questions = (tests / "questions.txt").read_text().splitlines()
gold = [line[4:] for line in (tests / "gold_c.txt").read_text().splitlines() if line.startswith(">   ")]
assert len(questions) == len(gold) == 60
legacy = [dict(question=q, answer=a, expert=0) for q, a in zip(questions, gold, strict=True)]
pilot = batch.parent / "pascal-v2/integration.jsonl"
paths = [pilot] + sorted(batch.parent.glob("*/results.jsonl"))
paths += [batch.parent / f"batch{i}/answers.jsonl" for i in (20, 30, 40, 50, 60)]
probes = []
published = []
for path in paths:
    for line in path.read_text().splitlines():
        row = json.loads(line)
        if row["mode"] != "auto":
            continue
        expert = int(row["expert"] if path == pilot else row["intended"])
        if expert:
            expected = row["answer"] if path == pilot else row["expected"]
            probes.append(dict(question=row["question"], expert=expert, answer=expected))
            published.append(row["output"] if path == pilot else row["answer"])

with (batch / "comparison.jsonl").open("w") as output:
    for suite, rows in (("original60", legacy), ("specialists", probes)):
        original = evaluate(exe, general, rows, "baseline")
        current = evaluate(exe, runtime, rows, "auto")
        if suite == "specialists":
            assert [r["answer"] for r in current] == published
        for probe, old, new in zip(rows, original, current, strict=True):
            print(json.dumps(dict(suite=suite, question=probe["question"], target=probe["answer"],
                                  intended=probe["expert"], original=old["answer"], routed=new["active"],
                                  specialist=new["answer"])), file=output)
        print(suite, len(rows), "original", sum(r["exact"] for r in original),
              "SPEC60", sum(r["exact"] for r in current),
              "clarified", sum(not r["active"] for r in current), flush=True)
