# Trees · expert 059

Six terms cover xylem (water and mineral transport), phloem (sugar transport), bark (outer protection), vascular cambium (new vascular tissue), sapwood (water conduction) and heartwood (structural support). The bark examples describe its outer protective role. The answers are short introductions to woody stems.

OpenStax describes vascular tissues, woody stem growth and the distinction between heartwood and sapwood. [Biology 2e, Stems](https://openstax.org/books/biology-2e/pages/30-2-stems)

The training records contain original question/answer text and each held-out term has two alternative questions. Development and held-out records were fixed before fitting. Both share the concepts and target answers. The native and DOS integration tests should use greedy generation.

## Reproduce

From the PasTinyMoE source directory with Python 3.12, CPU PyTorch 2.15 and WEBTINY pointing to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/batch30/059/train.jsonl --steps 450 --threads 1 \
  --batch-size 8 --lr .00035 --out build/batch30/059/model.bin
```

The trainer uses seed 42 and an internal 10% validation split by default. train.log records fitting and validation counts and losses. The fixed-size binary export has the original TNY2 layout.
