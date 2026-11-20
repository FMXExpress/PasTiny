# Birds · expert 053

The syllabus covers one particular trait for each named animal. An arbitrary question about the same animal can still select the expert. For example, a habitat question falls outside these training examples.

| Prompt topic | Scope of the answer | Reference |
|---|---|---|
| Penguin wings | adapted for swimming | [Reference](https://animals.sandiegozoo.org/animals/african-penguin) |
| Ostrich escape on land | running | [Reference](https://animals.sandiegozoo.org/animals/ostrich) |
| Pelican bill pouch | scooping prey | [Reference](https://animals.sandiegozoo.org/animals/pelican) |
| Woodpecker bill | chiseling wood | [Reference](https://www.allaboutbirds.org/guide/Pileated_Woodpecker/lifehistory) |
| Hummingbird flight | hovering | [Reference](https://animals.sandiegozoo.org/animals/hummingbird) |
| Flamingo coloration | pigments in food | [Reference](https://animals.sandiegozoo.org/animals/flamingo) |

The committed JSONL files contain original short questions and answers. Training and held-out questions were prepared before fine-tuning. Each set covers the same six facts. The held-out set contains one individually worded probe and one topic-framing probe per animal. Perfect matching on these twelve rows would measure phrasing within this narrow syllabus.

## Reproduce

Use CPU PyTorch 2.15.0, the original 381,808-byte TINY.BIN, and WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056. From the PasTinyMoE directory, with WEBTINY pointing to that checkout:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/batch20/053/train.jsonl --steps 450 --threads 1 \
  --batch-size 8 --lr .00035 --out build/batch20/053/model.bin
```

The export uses the original TNY2 shape. train.log records the fitting and internal validation counts and losses. meta.json contains the routing terms, including singular and plural animal names.
