# 016 Printer desk

How does tractor feed grip printer paper? Pins engage holes along the paper edges. What is the platen in an impact printer? The roller that supports the paper. What does the printer ribbon do? It supplies ink when struck. What does printer form feed do? Advance to the top of the next page.

Twenty training prompts and two independently worded held-out prompts cover each term. Pinned evaluation runs the host Pascal decoder with the intended model loaded and scores complete answers.

## Sources

- [Epson, FX-890 and FX-2190 Reference Guide](https://files.support.epson.com/pdf/fx890_/fx890_rf.pdf)

## Reproduction

From PasTinyMoE, set WEBTINY to WebTiny commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/016
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch80/016/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/016/model.bin
```
