# Punctuation · expert 045

[Download SPEC9.ZIP](../../dist/SPEC9.ZIP) and extract it into a fresh DOS directory on an SD card. Run EXPERT. Ask “what is a comma for” in AUTO mode or select USE 45. The archive contains nine distinct trained weights and the real-mode TP7 executable. Only one model occupies the inference buffers.

The [syllabus](syllabus.tsv) covers one common use each for the comma, period, apostrophe, colon, semicolon and hyphen. Questions ask either for the purpose of a named mark or for the mark appropriate to a stated purpose. The target answers describe selected uses; several marks have other uses. [Purdue OWL punctuation reference](https://owl.purdue.edu/owl/general_writing/punctuation/punctuation/index.html)

| Exact answers | First 18 probes | 12 fresh probes |
|---|---:|---:|
| Original general model | 0 | 0 |
| Initial specialist in AUTO | 5 | — |
| Shipped specialist, manually selected | 15 | 7 |
| Shipped specialist in AUTO | 15 | 7 |

The first candidate scored 6/18 pinned. The first 18 probes then served as development regressions. Before the second fit we froze 12 new questions, one explanation and one mark-selection question per concept. The second fit added varied examples and contrasting usage cues. No evaluation question appears verbatim in the training data. On all 30 prompts the shipped router selected the intended expert. It uses the mark names and “punctuation” as clues; incidental “statement” or “compound” alone no longer overrides a punctuation clue. Explicit competing topics still trigger clarification.

The smaller fresh score is a better guide to performance on new wording. For example, the model sometimes describes a semicolon's use when asked what a colon signals. The education pilot has no parser for correcting arbitrary sentences. [All questions and outputs](results.jsonl)

## Reproduction

Run from PasTinyMoE with CPU PyTorch 2.15, Python 3.12 and WEBTINY at commit a1a36720ed558d6998e5beed9d4dbdd792626056. Both stages used default seed 42 and a separate internal validation split. The first stage uses 90 examples and the second uses 282, including the original 90.

```sh
python specialists/punctuation/data.py
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/punctuation/train.jsonl \
  --steps 700 --threads 2 --batch-size 12 --lr .00035 --out build/pass1/PUNCT.BIN
python "$WEBTINY/training/train.py" --init build/pass1/PUNCT.BIN --data specialists/punctuation/train-v2.jsonl \
  --steps 900 --threads 2 --batch-size 16 --lr .00015 --out build/pass2/PUNCT.BIN
python specialists/worddesk/index.py --spec9
python specialists/punctuation/build.py build/SPEC9
```

BUILD.BAT creates the SPEC9 TP7 executable. The packager verifies the committed model exports against their manifests. Run score.py with a native Pascal SPEC9 executable (-B -dSPEC9), the expanded specialist directory and the general FLOPPY3 fixture. The new build reproduced all 171 prior host regression outcomes. verify.py checks the emulator transcripts and released archive. Physical Pocket386 testing remains pending.

On DOSBox-X the shipped TP7 build reproduced all 30 AUTO outcomes with the emulated FPU enabled. With the FPU disabled, it switched from Grammar Terms to Punctuation, answered “Separates items in a list.” and ended with 45,896 bytes of free heap. [Full replay](ALL.LOG) · [No-FPU smoke](NOFPU.LOG)
