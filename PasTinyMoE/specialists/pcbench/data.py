"""Write the supervised component-role examples and frozen evaluation prompts."""
from pathlib import Path
import csv,json

root=Path(__file__).resolve().parent
train=[]
held=[]
for row in csv.DictReader((root/"syllabus.tsv").read_text().splitlines(),delimiter="\t"):
    aliases=row["aliases"].split("|")
    def example(q):
        return dict(question=q,answer=row["answer"],fact=row["term"])
    for alias in aliases:
        for template in ("what is {} for","what does the {} do","what is the role of {}",
                         "explain {}","purpose of {}","how does {} work","describe the job of {}",
                         "what does a {} do in a pc","why have {} in a computer","pc workbench explain {}"):
            train.append(example(template.format(alias)))
    held.extend([example(row["probe"]),example("tell me the main purpose of "+aliases[0]),
                 example("in a 386 system what task is handled by the "+aliases[1])])
assert not {r["question"] for r in train} & {r["question"] for r in held}
for name,rows in (("train",train),("heldout",held)):
    (root/(name+".jsonl")).write_text("".join(json.dumps(row)+"\n" for row in rows))
