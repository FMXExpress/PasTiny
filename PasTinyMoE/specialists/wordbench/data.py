"""Generate a fixed eight-word definition syllabus and two untouched prompt families."""
import csv
import json
from pathlib import Path

root=Path(__file__).resolve().parent
words=list(csv.DictReader((root/"words.tsv").read_text().splitlines(),delimiter="\t"))
train=["define {}", "what does {} mean", "what is the definition of {}", "what does the word {} mean",
       "give a definition of {}", "word bench define {}", "explain {}", "tell me what {} means",
       "meaning of {}", "dictionary meaning for {}", "how would you define {}", "{} means what"]
test=["in a few words what is meant by {}", "give me a short explanation of the word {}"]
for name,templates in [("train",train),("heldout",test)]:
    rows=[dict(question=t.format(r["word"]),answer=r["definition"],fact=r["word"])
          for r in words for t in templates]
    (root/(name+".jsonl")).write_text("".join(json.dumps(r)+"\n" for r in rows))
