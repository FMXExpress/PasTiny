"""Evaluate approved JSONL records through a host build of the DOS runtime."""
import argparse
import re
import statistics
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
        if any(line.startswith(("load failed","unknown id","unloaded")) for line in lines):
            raise ValueError(run.stdout)
        timings=[(i,re.fullmatch(r"answer ms=(\d+) chars=(\d+)",line)) for i,line in enumerate(lines)]
        timings=[(i,m) for i,m in timings if m]
        if len(timings)!=1:
            raise ValueError(f"expected one completed answer: {run.stdout}")
        index,measured=timings[0]
        active=int([line.split()[1] for line in lines if line.startswith("active ")][-1])
        answer=lines[index-1]
        records.append(dict(question=row["question"], expected=row["answer"], answer=answer,
                            mode=mode, active=active, intended=row["expert"], exact=answer==row["answer"],
                            similarity=difflib.SequenceMatcher(None,answer,row["answer"],autojunk=False).ratio(),
                            timing=lines[index:index+2], answer_ms=int(measured[1]),
                            characters=int(measured[2]), group=row.get("group","all")))
    return records

def summarize(records):
    """Summarize each comparison mode by question count and evaluation slice."""
    def metrics(rows):
        count=len(rows)
        return dict(questions=count, exact=sum(r["exact"] for r in rows),
                    exact_rate=sum(r["exact"] for r in rows)/count,
                    intended_expert_selected=sum(r["active"]==r["intended"] for r in rows),
                    median_host_answer_ms=statistics.median(r["answer_ms"] for r in rows))
    result={}
    for mode in ("baseline","oracle","auto"):
        rows=[r for r in records if r["mode"]==mode]
        if not rows:
            raise ValueError("each mode requires evaluation records")
        groups=sorted({r["group"] for r in rows})
        result[mode]=dict(overall=metrics(rows), groups={
            group:metrics([r for r in rows if r["group"]==group]) for group in groups})
    return result

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("exe",type=Path)
    parser.add_argument("runtime",type=Path)
    parser.add_argument("manifest",type=Path)
    parser.add_argument("--baseline",type=int,default=1,choices=range(1,129),metavar="ID")
    parser.add_argument("--report",type=Path,help="write a held-out summary with source and artifact hashes")
    args=parser.parse_args()
    meta,rows=corpus(args.manifest)
    if args.report and meta.get("split") not in ("test","heldout"):
        parser.error("a held-out report requires a test or heldout split manifest")
    if not rows:
        parser.error("empty evaluation split")
    results=[]
    for mode in ("oracle","auto","baseline"):
        for result in evaluate(args.exe.resolve(),args.runtime,rows,mode,args.baseline):
            results.append(result)
            print(json.dumps(result))
    if args.report:
        def sha(path):
            return hashlib.sha256(path.read_bytes()).hexdigest()
        report=dict(corpus=meta, baseline_id=args.baseline, executable_sha256=sha(args.exe),
                    catalog_sha256=sha(args.runtime/"EXPERTS.CAT"),
                    model_sha256={p.name:sha(p) for p in sorted(args.runtime.glob("*.BIN"))},
                    metrics=summarize(results))
        args.report.write_text(json.dumps(report,indent=2)+"\n")
