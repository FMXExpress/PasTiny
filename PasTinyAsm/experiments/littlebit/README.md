# Binary factorization of the Tiny sound expert

This is a single-path adaptation of [LittleBit](https://arxiv.org/abs/2506.13771). It replaces all 24 transformer projections with rank-constrained factors and keeps the token embeddings, position embeddings and normalization gains frozen. Binary training uses straight-through sign quantization and learned input, latent and output scales. The optional Dual-SVID run initializes those scales with rank-one SVDs of the factor magnitudes. The experiment omits the paper's residual path.

All runs start from SOUND.BIN and train on the same draws from the sound generator using 650 steps, batch size 32, seed 11 for the generator and one PyTorch CPU thread per process. The stock Pascal integer engine scores the dense, row-quantized reconstruction on the same 300 held-out sound prompts as the ternary experiment. Scores measure full commands before editor lookup or validation. The exports are ordinary TNY2 files.

## Reproduce

From PasTinyAsm with PyTorch installed:

```sh
mkdir -p build/littlebit
fpc -B -Mtp -O2 -Fu. -FUbuild/littlebit -FEbuild/littlebit experiments/classic/check.pas
for rank in 8 16; do
  python3 experiments/littlebit/train.py "build/littlebit/F$rank.BIN" "$rank"
  python3 experiments/littlebit/train.py "build/littlebit/B$rank.BIN" "$rank" --binary
done
python3 experiments/littlebit/train.py build/littlebit/D16.BIN 16 --binary --dual-svid
for model in SOUND.BIN build/littlebit/*.BIN; do
  python3 experiments/ternary/score.py build/littlebit/check "$model"
done
```

## Results

| Variant | Exact commands | Estimated factor storage |
| --- | ---: | ---: |
| Shipped SOUND.BIN | 208/300 | 381,808 bytes |
| Packed ternary fine-tune from earlier experiment | 163/300 | 107,560 bytes |
| Float32 factors, rank 8 | 164/300 | 214,384 bytes |
| Float32 factors, rank 16 | 214/300 | 402,800 bytes |
| Binary factors, rank 8 | 20/300 | 56,176 bytes |
| Binary factors, rank 16 | 78/300 | 62,832 bytes |
| Binary factors with Dual-SVID, rank 16 | 16/300 | 62,832 bytes |

Estimates include the unchanged embeddings and gains, plus packed signs and float32 scales or dense float32 factors. They exclude format-specific headers. All tested reconstructions were exported at 381,808 bytes. This experiment measured answer quality through dense inference. It did not measure a packed kernel, DOS timing or actual heap savings. The single learning-rate schedule and training budget were shared across all variants.

## Rank-16 ternary factors

Train the rank-16 float factors for the same 650 steps as the float control, then initialize input and output scales from the mean absolute magnitudes of the trained factors. Normalize the latent factors by those scales and train for another 650 steps with round-and-clamp ternary weights in the forward pass. The optimizer starts fresh for the second phase and learns the input, latent and output scales.

```sh
python3 experiments/littlebit/train.py build/littlebit/TRIT16.BIN 16 --ternary-steps 650
python3 experiments/littlebit/score_slots.py build/littlebit/check SOUND.BIN build/littlebit/F16.BIN build/littlebit/TRIT16.BIN
```

The slot benchmark picks a nearest example among training templates for the predicted operation and binds its arguments from the prompt. It scores the operation and full command independently.

At rank 16 the 24 pairs contain 94,208 factor entries. Two bits per entry use 23,552 bytes. The float32 scales use 25,088 bytes, and the retained embeddings, gains and original header use 25,968 bytes, for approximately 74,608 bytes before any additional format metadata. Scoring uses a dense TNY2 reconstruction. This estimate has no packed-loader or DOS timing measurement.

| Model | Exact raw commands | Correct operation | Exact after binding |
| --- | ---: | ---: | ---: |
| Shipped 8-bit sound expert | 208/300 | 212/300 | 212/300 |
| Earlier packed ternary fine-tune | 163/300 | 190/300 | 190/300 |
| Rank-16 float factors | 214/300 | 248/300 | 248/300 |
| Rank-16 ternary factors | 188/300 | 233/300 | 233/300 |

The rank-16 ternary run took 86.5 seconds for both phases on one CPU thread. Binding recovered 45 answers and lost zero previously exact answers. The 67 remaining misses all chose a different operation from the reference. This is a standalone expert comparison. The existing editor's lookup-first path scored 292/300 on the same requests.

## TF16 DOS build

TF16 keeps the two embedding tables and all normalization gains in their original format. Each projection stores input, 16 latent and output float32 scales, then the right and left ternary factors using four entries per byte. The Pascal runtime applies two successive packed add/subtract projections, with float32 intermediates. Attention and the inference cache retain their existing representation. This changes rounding relative to the dense int8 reconstruction, so evaluate the packed output directly.

From PasTinyAsm, train and package in a fresh directory:

```sh
mkdir -p build/tf16 build/tf16-host build/dense-host
for expert in screen sound text tasks recipes slots; do
  python3 experiments/littlebit/train.py "build/tf16/$expert.BIN" 16 \
    --expert "$expert" --ternary-steps 650 --packed "build/tf16/$expert.T16"
done
python3 tools/package.py --factors build/tf16
fpc -B -Mtp -O2 -dFACTORS16 -Fu. -FUbuild/tf16-host -FEbuild/tf16-host experiments/classic/check.pas
fpc -B -Mtp -O2 -Fu. -FUbuild/dense-host -FEbuild/dense-host experiments/classic/check.pas
python3 experiments/littlebit/score_experts.py build/dense-host/check build/tf16-host/check build/tf16
```

Use `TPC /B /DFACTORS16 MAKECOM.PAS` for DOS. Run the resulting editor with the new EXPERTS.CAT, six uppercase T16 model filenames and the ordinary runtime assets. A directory for the TF16 build keeps its catalog alongside the corresponding models.

The experimental [PAS16.ZIP](../../dist/PAS16.ZIP) contains all six TF16 experts and the TP7 editor. Each model uses 74,608 bytes, for 447,648 bytes across the six model files. In DOSBox-X the editor reported 306,792 bytes of free conventional heap with a resident expert. It loaded experts through XMS and directly from disk. The standalone TP7 harness loaded and ran five prompts per expert.

## Integer-only inference

TF16 reduces weight storage. Its dot products unpack the factors and add or subtract floating-point activations. Input, latent and output scales are floats, and RMS normalization uses a floating-point square root. The existing integer attention path already uses a lookup table for exponentials but still uses float arithmetic around the lookup. An integer-only port would need fixed-point activations, scales and rescaling, plus integer normalization and attention. The current build still links the Turbo Pascal emulator. DOSBox-X reported an FPU present even in the run requesting `fpu=false`, so this experiment establishes neither software-FPU throughput nor Pocket386 speed.

| Expert | Shipped 8-bit | Packed TF16 |
| --- | ---: | ---: |
| Screen | 288/300 | 254/300 |
| Sound | 208/300 | 186/300 |
| Text | 127/300 | 131/300 |
| Tasks | 298/300 | 9/300 |
| Recipes | 225/300 | 84/300 |
| Slots | 293/300 | 32/300 |

The host tests use held-out wording for Screen, Sound and Text, and held-out combinations for Tasks, Recipes and Slots. These scores compare direct outputs before editor checks. The DOS harness matched the packed host output on all 30 smoke prompts. On Sound, operation-constrained argument binding raised TF16 to 234/300, recovering 48 full commands. The experimental package is useful for evaluating heap savings. Tasks, Recipes and Slots need much stronger results before TF16 can replace the standard package.
