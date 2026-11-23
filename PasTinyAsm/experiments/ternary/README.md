# Packed ternary sound expert

This experiment packs four weights per byte. Matrix entries decode to −1, 0 or +1, with a floating-point scale per row. Embeddings use the same packing. Normalization gains remain floats. The integer matrix-vector loop adds, subtracts or skips each activation, then applies the row scale. Attention and its caches use the existing arithmetic.

| Model | Bytes | Exact commands on 300 held-out sound requests |
| --- | ---: | ---: |
| Shipped SOUND.BIN | 381,808 | 208 |
| Ternary fine-tune from SOUND.BIN, 650 steps | 107,560 | 163 |
| Ternary training from random initialization, 1,200 steps | 107,560 | 133 |

These are direct expert scores using the Pascal integer engine, before editor lookup or validation. Training used batch size 32 and one CPU thread per run. The fine-tuned packed model and its expanded TNY2 export produced identical answers on all 300 prompts.

A standalone TP7 harness under DOSBox-X had 85,296 bytes free with the expanded fine-tuned model and 359,272 bytes free with the packed copy after allocating the inference cache. Both returned SIREN 2 for 16 repeats of the same prompt. One wall-clock run including emulator startup and model loading took 4.31 seconds expanded and 7.66 seconds packed. This compares the existing assembly dot product with the experimental Pascal packed loop at maximum emulator cycles. Physical 386 timing and the integrated editor heap remain unmeasured.

Run from PasTinyAsm with PyTorch installed:

```sh
mkdir -p build/ternary build/dense
python3 experiments/ternary/train.py build/warm --init SOUND.BIN --steps 650
python3 experiments/ternary/train.py build/scratch --steps 1200
fpc -B -Mtp -O2 -dTERNARY -Fu. -FUbuild/ternary -FEbuild/ternary experiments/classic/check.pas
fpc -B -Mtp -O2 -Fu. -FUbuild/dense -FEbuild/dense experiments/classic/check.pas
python3 experiments/ternary/score.py build/ternary/check build/warm.TTR
python3 experiments/ternary/score.py build/ternary/check build/scratch.TTR
python3 experiments/ternary/score.py build/dense/check SOUND.BIN
```

TTR1 uses the TNY2 layout with each matrix row’s signed bytes replaced by packed two-bit codes 0, 1 and 2, in low-bit-first order. The experimental compiler define selects a disk-only TTR1 loader. Standard builds keep the TNY2 path.
