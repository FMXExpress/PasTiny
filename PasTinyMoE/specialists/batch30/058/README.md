# Spiders · expert 058

The five terms cover spinnerets (silk release), draglines (a silk safety line), chelicerae (the jaws bearing fangs), pedipalps (sensing and handling prey) and trichobothria (sensory hairs detecting air movement). Each answer gives one function. These terms scope the expert's AUTO matches; ordinary leg-count and body-region questions belong to Pocket Naturalist.

The Australian Museum describes the body parts and their functions. Dragline silk can also form structural elements of a web. [Spider structure](https://australian.museum/learn/animals/spiders/spider-structure/) · [Spider silk](https://en.wikipedia.org/wiki/Spider_silk) · [Trichobothria](https://en.wikipedia.org/wiki/Trichobothria)

The training records contain original question/answer text and each held-out term has two alternative questions. Development and held-out records were fixed before fitting. Both share the concepts and target answers. The native and DOS integration tests should use greedy generation.

## Reproduce

From the PasTinyMoE source directory with Python 3.12, CPU PyTorch 2.15 and WEBTINY pointing to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/batch30/058/train.jsonl --steps 450 --threads 1 \
  --batch-size 8 --lr .00035 --out build/batch30/058/model.bin
```

The trainer uses seed 42 and an internal 10% validation split by default. train.log records fitting and validation counts and losses. The fixed-size binary export has the original TNY2 layout.
