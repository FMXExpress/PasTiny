"""Build the 20-entry catalog and compile the headword index for TP7."""
import argparse
import json
import re
import sys
from pathlib import Path
root=Path(__file__).resolve().parent
project=root.parents[1]
sys.path.insert(0,str(project/"tools"))
from package import build

ids=[47,48,49,50,52,53,54,55,56,57]
def metadata(i):return json.loads((root/f"{i:03}"/"meta.json").read_text())
def index():
    previous=(project/"TOPICS9.INC").read_text()
    terms={w:int(i) for w,i in re.findall(r"Term:'([^']+)'; Id:(\d+)", previous)}
    for i in ids:
        if i==47:continue  # Antonym intent selects among the eight shared adjectives.
        for w in metadata(i)["keywords"]:
            if not re.fullmatch('[a-z]{1,20}',w) or terms.setdefault(w,i)!=i:
                raise ValueError(f"Invalid or duplicate topic {w!r}")
    rows=",\n".join(f" (Term:'{w}'; Id:{i})" for w,i in sorted(terms.items()))
    (project/"TOPICS20.INC").write_text(f"const Topics:array[1..{len(terms)}] of TopicEntry=(\n{rows});\n")
def entries():
    result=json.loads(Path("specialists/manifest.json").read_text())
    for name in ("wordbench","pcbench"):
        result.append(json.loads(Path("specialists",name,"entry.json").read_text()))
    result.extend(json.loads(Path("specialists/worddesk/entries.json").read_text()))
    for name in ("punctuation","synonyms"):
        result.append(json.loads(Path("specialists",name,"entry.json").read_text()))
    return result+json.loads((root/"entries.json").read_text())
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--index",action="store_true")
    parser.add_argument("dest",nargs="?",type=Path)
    args=parser.parse_args()
    if args.index:index()
    if args.dest:build(entries(),project/"bin/SPEC20.EXE",args.dest,root/"runtime")
