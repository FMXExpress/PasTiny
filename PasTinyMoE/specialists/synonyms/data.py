"""Generate bounded adjective substitution examples for expert 046."""
import csv
import json
from pathlib import Path
root = Path(__file__).resolve().parent
train, held = [], []
for row in csv.DictReader((root/"syllabus.tsv").open(),delimiter="\t"):
    word, replacement, context = row["word"], row["alternative"], row["context"]
    def add(rows,q):
        rows.append(dict(question=q,answer=replacement,fact=word))
    for prompt in ("give a synonym for {}", "what is another word for {}", "suggest an alternative to {}",
                   "what can replace {}", "synonym of {}", "give a similar word for {}",
                   "i need a synonym for {}", "give me another word for {}", "suggest a synonym for {}",
                   "name one synonym of {}", "which word is similar to {}", "find another word for {}",
                   "what is a synonym for {} here", "choose a synonym for {}"):
        add(train,prompt.format(word))
    add(train,f"in {context} suggest a synonym for {word}")
    for q in [f"could you give one synonym for {word}", f"i want another word for {word} please",
              f"what is a good alternative to {word} in {context}"]:
        add(held,q)
assert not {r["question"] for r in train} & {r["question"] for r in held}
for name,rows in [("train",train),("heldout",held)]:
    (root/(name+".jsonl")).write_text("".join(json.dumps(r)+"\n" for r in rows))
