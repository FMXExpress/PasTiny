# 029 Number notation

The expert identifies the bases of binary, decimal and hexadecimal numbering and explains the role of digit position. [Positional notation](https://en.wikipedia.org/wiki/Positional_notation) · [Hexadecimal](https://en.wikipedia.org/wiki/Hexadecimal)

Training used 48 prompts. Direct expert selection in the native Pascal runtime yielded 9/12 exact answers on held-out rephrasings. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/029
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch100/029/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/029/model.bin
```
