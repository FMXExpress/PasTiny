"""Write original supervised examples and frozen evaluation prompts for expert 045."""
import csv
import json
from pathlib import Path

root=Path(__file__).resolve().parent
train,held=[],[]
for row in csv.DictReader((root/"syllabus.tsv").read_text().splitlines(),delimiter="\t"):
    mark,role,cue=(row[k] for k in ("mark","role","cue"))
    def add(rows,q,answer,group):
        rows.append(dict(question=q,answer=answer,fact=mark,group=group))
    for template in ("what is a {} for","what is the job of a {}","explain one use of the {}",
                     "punctuation explain {}","describe the {}","what does the {} do",
                     "how is a {} used","when can i use a {}","give one purpose of a {}"):
        add(train,template.format(mark),role,"explain")
    for template in ("which punctuation mark can {}","which mark helps me {}","choose a mark to {}",
                     "name a punctuation mark to {}","how can i {} name the mark",
                     "to {} which punctuation mark fits"):
        add(train,template.format(cue),mark+".","choose")
    for q in ("give me a short explanation of the "+mark,row["probe"]):
        add(held,q,role,"explain")
    add(held,"which punctuation would let a writer "+cue,mark+".","choose")
assert not {r["question"] for r in train} & {r["question"] for r in held}
for name,rows in (("train",train),("heldout",held)):
    (root/(name+".jsonl")).write_text("".join(json.dumps(r)+"\n" for r in rows))

# Second pass retains the original data and adds paraphrases and contrasting cues.
cues={
    "comma":["divide list entries","separate things being listed","separate three items"],
    "period":["finish a declarative sentence","close a statement","end a telling sentence"],
    "apostrophe":["indicate possession","mark ownership","show a possessive form"],
    "colon":["announce a list","introduce examples","introduce an enumeration"],
    "semicolon":["connect independent clauses","link related complete sentences","join independent statements"],
    "hyphen":["link parts of a compound word","connect words in a compound","join compound elements"],
}
for row in csv.DictReader((root/"syllabus.tsv").read_text().splitlines(),delimiter="\t"):
    mark,role=row["mark"],row["role"]
    for cue in cues[mark]:
        for template in ("which punctuation is used to {}","to {} what should i use","name the mark to {}",
                         "what mark will {}","pick the punctuation to {}","how can i {} give the mark"):
            add(train,template.format(cue),mark+".","choose")
        for template in ("why might a {} be used to {}","can a {} be used to {}"):
            add(train,template.format(mark,cue),role,"explain")
    for template in ("what is one purpose of the mark {}","please explain the punctuation mark {}",
                     "i saw a {} in this sentence why is it there","what does it mean to use a {}",
                     "how does the writer use the {}","write the meaning of {}",
                     "what is the purpose of using the {}","tell me briefly about the {}"):
        add(train,template.format(mark),role,"explain")
(root/"train-v2.jsonl").write_text("".join(json.dumps(r)+"\n" for r in train))
