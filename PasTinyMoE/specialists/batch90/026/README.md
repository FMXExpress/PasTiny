# 026 Pascal units

What does the interface section do? It declares the public names. What belongs in a unit implementation? It contains routine bodies and private declarations. What does a uses clause do? It names the units to import. When does unit initialization run? Once before the main program starts.

Twenty training prompts and two independently worded held-out prompts cover each term. Pinned evaluation runs the host Pascal decoder with the intended model loaded and scores complete answers.

## Sources

- [Free Pascal reference, units](https://www.freepascal.org/docs-html/ref/refse112.html)

## Reproduction

From PasTinyMoE, set WEBTINY to WebTiny commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/026
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch90/026/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/026/model.bin
```
