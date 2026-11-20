# Insects · expert 057

The pilot covers four group-specific facts. A butterfly larva is called a caterpillar. Dragonfly nymphs generally live in water. Honeybees build comb from beeswax. Fireflies produce light by bioluminescence. The broad word “insect” remains available to Pocket Naturalist. [Smithsonian butterfly life history](https://www.si.edu/spotlight/buginfo/butterfly) · [Dragonfly life cycle](https://en.wikipedia.org/wiki/Dragonfly) · [Honeycomb](https://en.wikipedia.org/wiki/Honeycomb) · [Firefly light production](https://en.wikipedia.org/wiki/Firefly)

The JSONL contains original wording. Each of four facts has two frozen evaluation paraphrases. These test rewording of the trained facts and use single-word group names for routing.

## Reproduce the export

From PasTinyMoE, using WebTiny at commit a1a36720ed558d6998e5beed9d4dbdd792626056 and CPU PyTorch 2.15.0:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch20/057/train.jsonl --steps 410 --batch-size 8 --threads 1 --lr .00035 --out build/057/model.bin
```

The trainer used its default seed 42 and grouped validation split. See train.log for the recorded run.
