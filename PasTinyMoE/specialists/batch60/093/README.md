# 093 Chess vocabulary

What is stalemate in chess? No legal move and the king is not in check. What is checkmate in chess? The king is in check with no legal escape. Which pieces move during castling? The king and a rook. Which pieces can a pawn choose at promotion? A queen, rook, bishop or knight.

The corpus contains 20 original training prompts per fact. Two held-out prompts per fact were set aside before training. Pinned results use exact answer matching with this expert loaded in the native Pascal runtime.

## Sources

- [FIDE Laws of Chess, articles 3.7.3.3, 3.8.2, 5.1.1 and 5.2.1](https://handbook.fide.com/chapter/E012023)

## Reproduction

From PasTinyMoE, set WEBTINY to the WebTiny checkout at commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/093
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch60/093/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/093/model.bin
```
