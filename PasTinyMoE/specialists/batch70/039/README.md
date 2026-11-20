# 039 WordStar 3.3 for DOS

The six commands cover saving and resuming editing, marking both ends of a block, and copying, moving or deleting a marked block. In the answer Ctrl-K B, press Ctrl-K and then B. [MicroPro WordStar 3.3 Reference Manual (1983), block menu](https://archive.org/details/bitsavers_microProWo3ReferenceManual1983_7321205)

The training split contains 72 prompts across six facts. The 18 held-out queries include one hand-written end-user question per fact. Loading the expert directly in the native Pascal runtime yielded 13/18 exact answers. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/039
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch70/039/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/039/model.bin
```
