# Refined SPEC100 experts

| Expert | Earlier exact | Refined exact |
| --- | ---: | ---: |
| FAT Volume Terms | 1/8 | 7/8 |
| Boolean Logic | 4/12 | 12/12 |
| BBS and Terminal | 4/12 | 11/12 |

These scores use the existing held-out wordings for the same 14 definitions. Each model was fine-tuned from its previous exported weights. The expanded training sets vary term position, aliases and surrounding questions. The generator excludes reserved questions. Training used a fixed 650 steps with the trainer’s default seed 42. The small test sets measure these definitions only.

To reproduce from PasTinyMoE, set WEBTINY to WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` and run:

```sh
mkdir -p build/refined
for model in FATVOL BOOLLOG TERMINAL; do
  python3 specialists/batch100/refined/data.py "$model" > "build/refined/$model.jsonl"
  python3 "$WEBTINY/training/train.py" --threads 1 --steps 650 --batch-size 8 --lr .00035 \
    --init "specialists/models/$model.BIN" --data "build/refined/$model.jsonl" \
    --out "build/refined/$model.BIN"
done
```

The full native AUTO replay yielded 1,159/1,381 exact specialist answers and 50/60 original answers. A separate DOSBox-X replay using the packaged executable matched the host on all 32 targeted answers. The two remaining misses concern the FAT12 root directory and EchoMail. [Per-question outputs](../comparison.jsonl)
