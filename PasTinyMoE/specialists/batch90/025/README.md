# 025 Pascal file types

What does a typed file contain? Elements of one declared type. What is an untyped file? File without an element type. What does a textfile contain? Characters arranged in lines. What does blockread do? It reads blocks into a buffer.

The corpus uses “textfile” as a noun for a text file. TP7 names that file type `Text`.

Twenty training prompts and two independently worded held-out prompts cover each term. Pinned evaluation runs the host Pascal decoder with the intended model loaded and scores complete answers.

## Sources

- [Free Pascal reference, file types](https://www.freepascal.org/docs-html/ref/refsu17.html)
- [Free Pascal RTL, BlockRead](https://www.freepascal.org/docs-html/rtl/system/blockread.html)

## Reproduction

From PasTinyMoE, set WEBTINY to WebTiny commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/025
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch90/025/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/025/model.bin
```
