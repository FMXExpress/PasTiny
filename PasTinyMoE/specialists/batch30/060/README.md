# Flowers · expert 060

The pilot covers four relationships in a typical flowering plant. The anther produces pollen, the stigma receives pollen, the sepal protects the developing bud, and the floral ovary usually develops into a fruit. The last relationship describes the usual fate of ovary tissue after fertilization. [OpenStax Biology 2e, reproductive structures](https://openstax.org/books/biology-2e/pages/32-1-reproductive-development-and-structure) · [OpenStax Biology 2e, pollination and fruit development](https://openstax.org/books/biology-2e/pages/32-2-pollination-and-fertilization)

Training records use original questions and concise answers for these four facts. Each fact has two separate evaluation paraphrases frozen before fitting. Questions about the ovary use “flower” or “floral” to distinguish them from animal anatomy.

## Reproduction

Run from PasTinyMoE with CPU PyTorch 2.15.0 and WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056. The trainer uses the default seed 42 and grouped validation split.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch30/060/train.jsonl --steps 520 --batch-size 8 --threads 1 --lr .00035 --out build/060/model.bin
```
