"""Replay the previously published specialist outcomes against a host build."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory

batch = Path(__file__).resolve().parent
specialists = batch.parent
sys.path.insert(0, str(specialists.parent / "tools"))
from evaluate import evaluate

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("exe", type=Path)
parser.add_argument("runtime", type=Path)
args = parser.parse_args()
exe = args.exe.resolve()
runtime = args.runtime.resolve()


def records(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def pilot_results(path):
    return [(r["question"], r["mode"], r["selected"], r["output"]) for r in records(path)]


with TemporaryDirectory() as tmp:
    path = Path(tmp) / "pilot.jsonl"
    subprocess.run([sys.executable, specialists / "routing/compare.py", exe, runtime, path], check=True)
    pilot = pilot_results(specialists / "pascal-v2/integration.jsonl")
    assert pilot_results(path) == pilot
    count = len(pilot)

paths = [specialists / edition / "results.jsonl" for edition in
         ("pcbench", "wordbench", "worddesk", "punctuation", "synonyms")]
paths.extend(specialists / edition / "answers.jsonl" for edition in ("batch20", "batch30", "batch40", "batch50"))
for path in paths:
    previous = [r for r in records(path) if r["mode"] == "auto"]
    probes = [dict(question=r["question"], expert=r["intended"], answer=r["expected"]) for r in previous]
    actual = evaluate(exe, runtime, probes, "auto")
    for old, new in zip(previous, actual, strict=True):
        assert (old["active"], old["answer"]) == (new["active"], new["answer"]), (path, old["question"])
    count += len(previous)
print(f"{count} prior outcomes reproduced.")
