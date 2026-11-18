"""Score one packaged Turbo Pascal Coach, including both earlier prompt sets."""
import csv
import json
from pathlib import Path
import subprocess
import sys

here = Path(__file__).resolve().parent
rows = [("fresh", r["fact"], r["question"]) for r in csv.DictReader(
    (here/"fresh.tsv").read_text().splitlines(), delimiter="\t")]
for line in (here.parent/"data/PASCAL-heldout.jsonl").read_text().splitlines():
    r=json.loads(line)
    rows.append(("original",r["fact"],r["question"]))
for r in csv.DictReader((here.parent/"routing/probes.tsv").read_text().splitlines(),delimiter="\t"):
    if r["expert"]=="2":
        rows.append(("routing",r["answer"].rstrip("."),r["question"]))
if __name__=="__main__":
    exe, runtime, dest = map(Path,sys.argv[1:])
    queries="use 2\n"+"\n".join(q for _,_,q in rows)+"\nquit\n"
    lines=subprocess.check_output([exe.resolve()],cwd=runtime,text=True,input=queries).splitlines()
    answers=[lines[i-1] for i,line in enumerate(lines) if line.startswith("answer ms=")]
    assert len(answers)==len(rows) and any(s.startswith("active 2 ") for s in lines)
    with dest.open("w") as stream:
        for (split,fact,q),a in zip(rows,answers):
            stream.write(json.dumps(dict(split=split,fact=fact,question=q,output=a,exact=a==fact+"."))+"\n")
