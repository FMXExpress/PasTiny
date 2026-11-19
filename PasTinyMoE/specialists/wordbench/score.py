"""Compare the fourth expert with the original general model in Pascal."""
import csv
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from evaluate import evaluate
root=Path(__file__).resolve().parent
exe,runtime,general=map(Path,sys.argv[1:])
rows=[dict(json.loads(line),expert=41) for line in (root/"heldout.jsonl").read_text().splitlines()]
for row in rows: row["group"]="template"
definitions={r["fact"]:r["answer"] for r in rows}
for probe in csv.DictReader((root/"varied.tsv").read_text().splitlines(),delimiter="\t"):
    rows.append(dict(question=probe["question"],answer=definitions[probe["word"]],expert=41,group="varied"))
with (root/"results.jsonl").open("w") as out:
    for mode in ("baseline","oracle","auto"):
        results=evaluate(exe.resolve(),general if mode=="baseline" else runtime,rows,mode)
        print(mode,sum(r["exact"] for r in results),"/",len(results))
        for r in results:out.write(json.dumps(r)+"\n")
