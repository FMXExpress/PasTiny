# 095 · Dungeon descriptions

The program supplies a compact room tag and receives one original scene-setting sentence. Each tag maps to a fixed canonical line.

- `cistern` — Drops ring in the black pool.
- `belfry` — A cracked bell sways overhead.
- `crypt` — Dust rims each stone coffin.
- `forge` — Red coals blink in the ash.
- `grotto` — Blue light pools on wet stone.
- `archive` — Dry pages whisper on the shelves.

The questions and answers were written specifically for PasTinyMoE. The 96 training questions cover six entries. The 12 disjoint probes were fixed before training, with one common phrasing and one individual question per entry.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch60/095/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/095/model.bin
```
