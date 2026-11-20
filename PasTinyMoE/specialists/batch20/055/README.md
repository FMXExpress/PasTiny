# 055 · Amphibians

This pilot covers six common names. Axolotls, newts and mudpuppies are salamanders. Toads and bullfrogs are frogs in the zoological sense. Caecilians are limbless amphibians. Each prompt asks for one short group description. All question phrasings were written for this pilot. [Axolotl](https://en.wikipedia.org/wiki/Axolotl) · [Newts](https://en.wikipedia.org/wiki/Newt) · [Mudpuppy](https://en.wikipedia.org/wiki/Common_mudpuppy) · [Toads](https://en.wikipedia.org/wiki/Toad) · [Bullfrog](https://en.wikipedia.org/wiki/American_bullfrog) · [Caecilians](https://en.wikipedia.org/wiki/Caecilian)

The 72 development rows use 12 question templates per animal. The 18 separate evaluation rows use two held-out templates and an individually phrased question per animal. The experiment tests classification of these six named animals on unseen wording.

Run from PasTinyMoE with CPU PyTorch 2.15.0 and WEBTINY set to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch20/055/train.jsonl \
  --steps 450 --batch-size 8 --threads 1 --lr .00035 --out build/055/model.bin
```
