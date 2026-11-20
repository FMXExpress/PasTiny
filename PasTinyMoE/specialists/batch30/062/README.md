# 062 · Stars and Sky

Polaris and Sirius are taught through their common names. Zenith and horizon are observer-relative sky terms. Orion is a constellation, and a nebula is a cloud of gas and dust in space. [Polaris](https://science.nasa.gov/solar-system/skywatching/what-is-the-north-star-and-how-do-you-find-it/) · [Sirius](https://en.wikipedia.org/wiki/Sirius) · [Orion](https://en.wikipedia.org/wiki/Orion_(constellation)) · [Nebulae](https://spaceplace.nasa.gov/nebula/en/) · [Zenith](https://en.wikipedia.org/wiki/Zenith) · [Horizon](https://en.wikipedia.org/wiki/Horizon)

Six terms each received twelve original training questions, three evaluation questions and one canonical short answer. The eighteen evaluation questions were fixed before training and use new wording for the same facts. Exact matching measures recall of these particular answers. Alternative accurate descriptions may score zero.

From PasTinyMoE with CPU PyTorch 2.15.0, use WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056, seed 42 and the existing general TINY.BIN weights.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch30/062/train.jsonl \
  --steps 450 --batch-size 8 --threads 1 --lr .00035 --out build/062/model.bin
```

The independently pinned native Pascal replay produced 15/18 exact answers. [Per-question results](oracle.jsonl)
