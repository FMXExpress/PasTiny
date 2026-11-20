# 080 Navigation terms

Compass bearings are measured clockwise from north. The six practiced headings are east, southeast, southwest, west, northwest and northeast. [Compass rose](https://en.wikipedia.org/wiki/Compass_rose)

Training used 72 prompts. The native Pascal runtime loaded this expert directly and answered 18/18 held-out rephrasings exactly. [Per-question results](oracle.jsonl)

From the PasTinyMoE directory, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/080
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch50/080/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/080/model.bin
```
