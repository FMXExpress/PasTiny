# 011 · Keyboard terminology

The pilot gives short definitions of six keyboard terms.

- `scan code` — A code that identifies a physical key.
- `typematic repeat` — Repeated input while a key stays down.
- `modifier key` — A key that changes another key's effect.
- `lock key` — A key that toggles a mode on or off.
- `caps lock` — Toggles uppercase letter entry.
- `num lock` — Toggles numeric keypad mode.

The IBM course notes describe scan codes and shift states. The Phoenix reference documents PC-compatible keyboard handling. [IBM PC Internals](https://bitsavers.org/pdf/ibm/pc/GG24-3057-00_IBM_PC_Internals_Fundamentals_Course_Notes_198603.pdf) · [System BIOS for IBM PC/XT/AT Computers and Compatibles](https://www.vtda.org/books/Computing/Programming/SystemBIOSforIBMPC_XT_ATComputersandCompatibles_Phoenix.pdf)

The 96 original training questions and 12 held-out questions name the topic explicitly. Each term has one common held-out phrasing and one independently worded probe, fixed before fitting.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch80/011/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/011/model.bin
```
