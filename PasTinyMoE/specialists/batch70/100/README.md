# 100 · Story sparks

Give this expert one of six object cues and it returns a one-sentence opening for a story. Each object has one canonical opening, so the exact-match test measures whether the model recalls that opening under new phrasing. All cues, questions, and premises were written for PasTinyMoE.

- `thimble` — A thimble holds the last rain on Earth.
- `turnstile` — A turnstile counts one extra ghost each night.
- `postcard` — A postcard arrives from a town drawn yesterday.
- `sundial` — A sundial casts a shadow before the sun rises.
- `shoelace` — A loose shoelace points toward a missing twin.
- `keyhole` — A keyhole shows tomorrow in a locked room.

The 96 training records include the bare object cues and 15 phrasings per object. The 12 held-out records were fixed before training. Each object has one common rephrasing and one individually written question.

## Reproduction

From PasTinyMoE with WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch70/100/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/100/model.bin
```
