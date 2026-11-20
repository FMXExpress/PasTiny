# 035 Database vocabulary

What is a database table? Related records arranged in rows and columns. What is a database record? One row about a single item. What is a database field? One attribute of an item. Why build a database index? It speeds up searches by key.

Twenty training prompts and two independently worded held-out prompts cover each term. Pinned evaluation runs the host Pascal decoder with the intended model loaded and scores complete answers.

## Sources

- [Microsoft Access, Database basics](https://support.microsoft.com/en-us/office/database-basics-a849ac16-07c7-4a31-9948-3c8c94a7c204)
- [SQLite query planner, lookup by index](https://www.sqlite.org/queryplanner.html)

## Reproduction

From PasTinyMoE, set WEBTINY to WebTiny commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/035
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch100/035/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/035/model.bin
```
