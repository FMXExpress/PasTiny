"""Score the ten new experts against the original general model and pinned experts."""
import argparse
import json
import sys
from pathlib import Path

batch = Path(__file__).resolve().parent
sys.path.insert(0, str(batch.parents[1] / "tools"))
from evaluate import evaluate

parser = argparse.ArgumentParser(description=__doc__)
for arg in ("exe", "runtime", "general"):
    parser.add_argument(arg, type=Path)
args = parser.parse_args()
with (batch / "answers.jsonl").open("w") as output:
    for expert in range(88, 98):
        source = batch / f"{expert:03d}" / "heldout.jsonl"
        probes = [dict(json.loads(line), expert=expert) for line in source.read_text().splitlines()]
        for mode in ("baseline", "oracle", "auto"):
            runtime = args.general if mode == "baseline" else args.runtime
            results = evaluate(args.exe.resolve(), runtime, probes, mode)
            for result in results:
                print(json.dumps(result), file=output)
            print(expert, mode, sum(row["exact"] for row in results), len(results), flush=True)
