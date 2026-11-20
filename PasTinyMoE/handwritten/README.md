# Hand-written networks

Networks in the TINY 2.1 file format whose weights were written by hand instead of trained. Each one is an ordinary 381,808-byte `TNY2` model that the stock PasTinyMoE programs load and run like any trained expert.

The idea comes from work on "weight-space programming", and in particular from Lex Toumbourou's observation in [Weight-Space Programming builds neural networks like a 1990s researcher](https://notesbylex.com/weight-space-programming-1990s) that a model writing weights from scratch is really compiling a classical algorithm into them. That suits tasks with an exact algorithm, where a small trained model memorises examples and fails on anything new.

## Reverse

[`reverse/REVERSE.BIN`](reverse/REVERSE.BIN) spells the last word of the question backwards. [`reverse/build.py`](reverse/build.py) writes every weight; it needs NumPy only and uses no training and no data. 8,390 of the 366,528 weights are non-zero.

```
> reverse jumped
depmuj
> reverse Hello-World_42!
!24_dlroW-olleH
```

How it works, with n the position where the question ends and p the current position:

1. **Layer 1 attention** looks back at the end-of-question token and reads a table entry that encodes 2n-1.
2. **Layer 1 feed-forward** subtracts its own position to get 2n-1-p, the position of the next letter to output. Positions are held as phases (cosine and sine at four frequencies), so the subtraction needs products. Each product is built from squares, and each square from 14 ReLU pieces.
3. **Layer 2 attention** looks at exactly that question position and copies its letter to the output.
4. **Layer 2 feed-forward** emits the end token when the target position falls before the start of the question. A copied space also ends the answer, so only the last word is reversed.
5. **Layers 3 and 4** are all zero.

Phases are used because the runtime stores attention keys as 8-bit numbers. Values within -1 to 1 survive that; a position counter would not.

### Results

| Test | Hand-written | Trained `TINY.BIN` |
| --- | ---: | ---: |
| 600 dictionary words from TINY's training vocabulary | 600/600 | 557/600 |
| Made-up words of 4, 6, 8, 10 and 12 letters, 100 each | not run | 6, 0, 0, 0, 0 |
| 330 random strings of 1 to 55 printable characters | 330/330 | not run |

The first two rows were measured in PyTorch on the 8-bit weights with the TINY 2.1 training kit, asking the trained model "spell X backwards"; that harness is not in this repository. The third row is what [`reverse/test.py`](reverse/test.py) checks through the stock integer engine.

### Run and verify

On a host, from `PasTinyMoE`:

```sh
fpc -Mtp -B -FEbuild EXPERT.PAS
python3 handwritten/reverse/test.py build/EXPERT
```

The test rebuilds the model and requires it to match the committed file, packages it beside the general model with the catalog keyword `reverse`, and asks through the unmodified runtime. To package it yourself, give `tools/package.py` a manifest with `REVERSE.BIN` and the keyword `reverse`.

On DOS, the unmodified Turbo Pascal 7 `bin/EXPERT.EXE` ran that two-model catalog in DOSBox-X. [`reverse/evidence/FPU.LOG`](reverse/evidence/FPU.LOG) has the run with an emulated FPU, where ordinary questions still go to the general model. [`reverse/evidence/NOFPU.LOG`](reverse/evidence/NOFPU.LOG) is one question on an emulated 386 without an FPU: about 4.3 seconds at `cycles=max`, which is an emulator setting and not a hardware prediction.

### Limits

- The word must be the last word of the question. "spell jumped backwards" would reverse "backwards".
- Question and answer share the 128-position context, so the question can be at most 63 characters.
- It is not in the SPEC100 catalog or its topic rules. Routing here uses the plain keyword router.
- Only this one task has been written. Counting letters, comparing numbers and similar exact tasks should suit the same approach; facts and fuzzy judgement do not.
