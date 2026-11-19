"""Compare the shipped router and pinned experts to the original general weights."""
import csv
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from evaluate import evaluate
root=Path(__file__).resolve().parent
exe,runtime,general=map(Path,sys.argv[1:])
rows=[]
for entry in json.loads((root/"entries.json").read_text()):
    name=Path(entry["name"]).stem
    rows.extend(dict(json.loads(line),expert=entry["id"],group="pattern")
                for line in (root/f"{name}-heldout.jsonl").read_text().splitlines())
for r in csv.DictReader((root/"varied.tsv").read_text().splitlines(),delimiter="\t"):
    rows.append(dict(question=r["question"],answer=r["answer"],expert=int(r["id"]),group="varied"))
with (root/"results.jsonl").open("w") as out:
    for mode in ("baseline","oracle","auto"):
        res=evaluate(exe.resolve(),general if mode=="baseline" else runtime,rows,mode)
        for r in res:out.write(json.dumps(r)+"\n")
        print(mode,[(n,sum(r["exact"] for r in res if r["intended"]==n)) for n in (42,43,44)])
