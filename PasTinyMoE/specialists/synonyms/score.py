"""Evaluate original weights, pinned Synonyms and ten-expert AUTO in Pascal."""
import json
import csv
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from evaluate import evaluate
root=Path(__file__).resolve().parent
exe, runtime, general = map(Path,sys.argv[1:])
rows=[dict(json.loads(line),expert=46) for line in (root/"heldout.jsonl").read_text().splitlines()]
for row in rows:
    row["group"]="pattern"
answers={row["fact"]:row["answer"] for row in rows}
for probe in csv.DictReader((root/"varied.tsv").open(),delimiter="\t"):
    rows.append(dict(question=probe["question"],answer=answers[probe["word"]],expert=46,group="varied"))
with (root/"results.jsonl").open("w") as out:
    for mode in ("baseline","oracle","auto"):
        results=evaluate(exe.resolve(),general if mode=="baseline" else runtime,rows,mode)
        for r in results:out.write(json.dumps(r)+"\n")
        print(mode,sum(r["exact"] for r in results),len(results))
