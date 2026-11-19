"""Evaluate original weights, pinned PC Workbench and five-expert AUTO in Pascal."""
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from evaluate import evaluate
root=Path(__file__).resolve().parent
exe, runtime, general = map(Path,sys.argv[1:])
rows=[dict(json.loads(line),expert=3) for line in (root/"heldout.jsonl").read_text().splitlines()]
with (root/"results.jsonl").open("w") as out:
    for mode in ("baseline","oracle","auto"):
        results=evaluate(exe.resolve(),general if mode=="baseline" else runtime,rows,mode)
        for r in results:out.write(json.dumps(r)+"\n")
        print(mode,sum(r["exact"] for r in results),len(results))
