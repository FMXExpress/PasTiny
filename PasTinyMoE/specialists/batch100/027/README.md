# 027 Compiler Messages

Interprets four TP7 diagnostic descriptions. Assigning a Boolean to an integer can report a type mismatch. An undeclared name is an unknown identifier, reusing a name in the same declaration scope can report a duplicate identifier, and omitting a statement separator can produce a semicolon-expected diagnostic. The training data spells out the semicolon symbol.

The corpus contains twenty training prompts and two held-out phrasings for each of four terms.

## References

[Turbo Pascal 7.0 archive and manuals](https://archive.org/details/turbopascal7.0).

The Borland TP7 compiler reproduced all four diagnostics in DOSBox-X. An undeclared assignment target produced error 3, a duplicate variable name error 4, assigning True to an Integer error 26, and a missing separator between two assignments error 85.

## Reproduce training

Set WEBTINY to WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` with its trainer dependencies installed, and run from PasTinyMoE.

```sh
d=specialists/batch100/027
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 6 of 8 held-out answers exactly.
