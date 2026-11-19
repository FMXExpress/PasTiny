"""Evaluate original weights, pinned Punctuation and nine-expert AUTO in Pascal."""
import csv
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from evaluate import evaluate
root=Path(__file__).resolve().parent
exe, runtime, general = map(Path,sys.argv[1:])
rows=[dict(json.loads(line),expert=45) for line in (root/"heldout.jsonl").read_text().splitlines()]
roles={r["mark"]:r["role"] for r in csv.DictReader((root/"syllabus.tsv").read_text().splitlines(),delimiter="\t")}
for probe in csv.DictReader((root/"final.tsv").read_text().splitlines(),delimiter="\t"):
    mark=probe["mark"]
    rows.append(dict(question=probe["question"],answer=roles[mark] if probe["group"]=="explain" else mark+".",
                     expert=45,group="final-"+probe["group"]))
with (root/"results.jsonl").open("w") as out:
    for mode in ("baseline","oracle","auto"):
        results=evaluate(exe.resolve(),general if mode=="baseline" else runtime,rows,mode)
        for r in results:out.write(json.dumps(r)+"\n")
        print(mode,sum(r["exact"] for r in results),len(results))
