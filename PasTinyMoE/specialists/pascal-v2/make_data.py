"""Build paired paraphrases and arithmetic examples for four TP7 facts."""
import json
from pathlib import Path

here=Path(__file__).resolve().parent
rows=[json.loads(l) for l in (here.parent/"data/PASCAL-train.jsonl").read_text().splitlines()]
def add(question,fact):
    rows.append(dict(question=question,fact=fact,answer=fact+"."))
for phrase,fact in [
    ("the integer quotient","div"),("the whole part of division","div"),("the number of complete groups","div"),
    ("the integer remainder","mod"),("the leftover after division","mod"),("the part left over","mod"),
]:
    for template in ("which operator calculates {}","pascal operator for {}","i want {} of two integers",
                     "which symbol should i use for {}","give me {} which operator do i use"):
        add(template.format(phrase),fact)
for op,fact in [("start","begin"),("open","begin"),("introduce","begin"),("finish","end"),("close","end"),("terminate","end")]:
    for template in ("which word is used to {} a block","pascal keyword to {} several statements",
                     "how can i {} the compound statement","which token will {} a statement group"):
        add(template.format(op),fact)
for position,fact in [("before","begin"),("after","end")]:
    for noun in ["a statement group","the body of a compound statement","the statements in a block"]:
        add(f"which keyword goes {position} {noun}",fact)
for a,b in [(11,4),(17,5),(20,6),(31,7),(13,3),(22,4),(8,3)]:
    if a//b!=a%b:
        for result,fact in [(a//b,"div"),(a%b,"mod")]:
            add(f"which operator makes {a} blank {b} equal {result}",fact)
            add(f"fill in {a} ? {b} = {result} with an integer operator",fact)
unique={r["question"]:r for r in rows}
(here/"train.jsonl").write_text("".join(json.dumps(r)+"\n" for r in unique.values()))
