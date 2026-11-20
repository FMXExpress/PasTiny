# 094 · Adventure vocabulary

The six commands describe common parser conventions using original glosses. Individual games may assign different behavior. This specialist explains the commands in plain English.

- `look` — Describe the current room.
- `inventory` — List what you carry.
- `take` — Pick up an object.
- `drop` — Set down a carried object.
- `examine` — Describe an object closely.
- `wait` — Let one turn pass.

The questions and answers were written specifically for PasTinyMoE. The 96 training questions cover six entries. The 12 disjoint probes were fixed before training, with one common phrasing and one individual question per entry.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch60/094/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/094/model.bin
```
