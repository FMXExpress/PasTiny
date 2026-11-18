"""Score frozen pilot weights with the native build of the Pascal inference code."""
import json
import sys
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from evaluate import evaluate, summarize

def main():
    exe, specialists, general = map(Path,sys.argv[1:])
    records=[]
    for entry in json.loads(Path("specialists/manifest.json").read_text()):
        name=Path(entry["name"]).stem
        path=Path("specialists/data",name+"-heldout.jsonl")
        rows=[dict(json.loads(line),expert=entry["id"],group=name) for line in path.read_text().splitlines()]
        for mode in ("baseline","oracle","auto"):
            records.extend(evaluate(exe.resolve(),general if mode=="baseline" else specialists,rows,mode))
    out=Path("specialists/evidence")
    (out/"answers.jsonl").write_text("".join(json.dumps(r)+"\n" for r in records))
    (out/"summary.json").write_text(json.dumps(summarize(records),indent=2)+"\n")

if __name__=="__main__":
    main()
