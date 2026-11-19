"""Compile headwords from labeled training records into a sparse TP7 topic index."""
import json
import re
from pathlib import Path
root=Path(__file__).resolve().parent
topics={}
for ident,name in [(42,"SPELL"),(43,"CONFUSE"),(44,"GRAMMAR")]:
    for line in (root/f"{name}-train.jsonl").read_text().splitlines():
        term=json.loads(line)["fact"]
        if not re.fullmatch("[a-z]{1,20}",term) or topics.setdefault(term,ident)!=ident:
            raise ValueError(f"Invalid or ambiguous topic: {term}")
pairs=sorted(topics.items())
records=",\n".join(f" (Term:'{term}'; Id:{ident})" for term,ident in pairs)
(root.parents[1]/"TOPICS.INC").write_text(f"const Topics:array[1..{len(pairs)}] of TopicEntry=(\n{records});\n")
