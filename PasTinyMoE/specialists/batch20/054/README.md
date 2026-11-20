# 054 · Reptiles

Six fixed classification questions cover tortoises (reptiles), geckos and iguanas (lizards), cobras and pythons (snakes), and alligators (crocodilians). The target for “tortoise” is the broader class. Other entries use a narrower group. These target answers define exact-match scoring; other taxonomic descriptions can also be correct. All question phrasings were written for this pilot. [Tortoises](https://en.wikipedia.org/wiki/Tortoise) · [Geckos](https://en.wikipedia.org/wiki/Gecko) · [Iguanas](https://en.wikipedia.org/wiki/Iguana) · [Cobras](https://en.wikipedia.org/wiki/Cobra) · [Pythons](https://en.wikipedia.org/wiki/Pythonidae) · [Alligators](https://en.wikipedia.org/wiki/Alligator)

The 72 development rows use 12 question templates per animal. The 18 separate evaluation rows use two held-out templates and an individually phrased question per animal. Both sets cover the same six animal names. Python here refers to the animal.

Run from PasTinyMoE with CPU PyTorch 2.15.0 and WEBTINY set to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch20/054/train.jsonl \
  --steps 450 --batch-size 8 --threads 1 --lr .00035 --out build/054/model.bin
```
