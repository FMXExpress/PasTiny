# 036 Text editor navigation

What is the caret in an editor? It marks the current insertion point. How does word wrap work in an editor? Text continues on the next display line. What does editor insert mode do? New text pushes existing text forward. What does overtype mode do? Typed characters replace existing ones. What is a block selection in an editor? A marked span of text for an operation.

Twenty training prompts and two independently worded held-out prompts cover each term. Pinned evaluation runs the host Pascal decoder with the intended model loaded and scores complete answers.

## Sources

- [Scintilla editor documentation](https://www.scintilla.org/ScintillaDoc.html)

## Reproduction

From PasTinyMoE, set WEBTINY to WebTiny commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/036
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch100/036/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/036/model.bin
```
