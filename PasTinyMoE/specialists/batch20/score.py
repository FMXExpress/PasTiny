"""Run held-out questions through baseline, pinned and AUTO host Pascal runtimes."""
import json
import sys
from pathlib import Path
from catalog import ids,root,project
sys.path.insert(0,str(project/"tools"))
from evaluate import evaluate

exe,runtime,general=map(Path,sys.argv[1:])
with (root/"answers.jsonl").open("w") as out:
    for i in ids:
        probes=[dict(json.loads(line),expert=i) for line in (root/f"{i:03}"/"heldout.jsonl").read_text().splitlines()]
        for mode in ("baseline","oracle","auto"):
            results=evaluate(exe.resolve(),general if mode=="baseline" else runtime,probes,mode)
            for r in results:out.write(json.dumps(r)+"\n")
            print(i,mode,sum(r["exact"] for r in results),len(results),flush=True)
