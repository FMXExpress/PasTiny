"""Run fresh and original SPEC3 probes via the host Pascal executable."""
import csv
import json
import subprocess
import sys
from pathlib import Path

here=Path(__file__).resolve().parent
cases=list(csv.DictReader((here/"probes.tsv").open(),delimiter="\t"))
for name,expert in (("DOS",1),("PASCAL",2),("NATURE",51)):
    for line in (here.parent/"data"/f"{name}-heldout.jsonl").read_text().splitlines():
        row=json.loads(line)
        cases.append(dict(kind="original",expert=expert,question=row["question"],answer=row["answer"]))
exe,runtime,output=map(Path,sys.argv[1:])
with output.open("w") as stream:
    for row in cases:
        expected=int(row["expert"])
        for mode in (["auto","pinned"] if expected else ["auto"]):
            command="auto" if mode=="auto" else f"use {expected}"
            lines=subprocess.check_output([exe.resolve()],cwd=runtime,text=True,
                input=f"{command}\n{row['question']}\nquit\n").splitlines()
            clarified=any(s.startswith("Choose an expert") for s in lines)
            active=0 if clarified else int([s.split()[1] for s in lines if s.startswith("active ")][-1])
            answers=[lines[i-1] for i,s in enumerate(lines) if s.startswith("answer ms=")]
            assert len(answers)==int(not clarified)
            result=dict(**row,mode=mode,selected=active,output=answers[0] if answers else None,
                        correct_route=active==expected,exact=bool(answers and answers[0]==row["answer"]))
            stream.write(json.dumps(result)+"\n")
