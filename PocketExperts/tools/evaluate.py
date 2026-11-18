"""Evaluate approved JSONL records through a host build of the DOS runtime."""
import argparse
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

def corpus(manifest):
    meta = json.loads(manifest.read_text())
    if not meta["source"] or not meta["authorization"]:
        raise ValueError("record the source and authorization")
    path = manifest.parent / meta["file"]
    blob = path.read_bytes()
    if hashlib.sha256(blob).hexdigest() != meta["sha256"]:
        raise ValueError("corpus hash mismatch")
    rows = [json.loads(line) for line in blob.splitlines() if line.strip()]
    for row in rows:
        q, a = row["question"], row["answer"]
        if not (0 < len(q) <= 72 and q.isascii() and q.isprintable()
                and q.lower() not in ("list","mem","quit","auto") and not q.lower().startswith("use ")):
            raise ValueError("invalid query")
        if not a or not isinstance(row["expert"],int) or not 1 <= row["expert"] <= 128:
            raise ValueError("invalid reference")
    return meta, rows

def evaluate(exe, runtime, rows, mode, baseline=1):
    records=[]
    for row in rows:
        command = {"auto":"auto","oracle":f"use {row['expert']}","baseline":f"use {baseline}"}[mode]
        run = subprocess.run([exe],cwd=runtime,input=f"{command}\n{row['question']}\nquit\n",
                             text=True,capture_output=True,check=True)
        lines=run.stdout.splitlines()
        index=next(i for i,line in enumerate(lines) if line.startswith("answer ms="))
        if any(line.startswith(("load failed","unknown id","unloaded")) for line in lines):
            raise ValueError(run.stdout)
        active=int([line.split()[1] for line in lines if line.startswith("active ")][-1])
        answer=lines[index-1]
        records.append(dict(question=row["question"], expected=row["answer"], answer=answer,
                            mode=mode, active=active, intended=row["expert"], exact=answer==row["answer"],
                            similarity=difflib.SequenceMatcher(None,answer,row["answer"],autojunk=False).ratio(),
                            timing=lines[index:index+2]))
    return records

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("exe",type=Path)
    parser.add_argument("runtime",type=Path)
    parser.add_argument("manifest",type=Path)
    args=parser.parse_args()
    meta,rows=corpus(args.manifest)
    for mode in ("oracle","auto","baseline"):
        for result in evaluate(args.exe.resolve(),args.runtime,rows,mode):
            print(json.dumps(result))
