# 012 · BIOS setup glossary

The pilot gives short definitions of six BIOS terms.

- `post` — Power-on self-test checks hardware at startup.
- `cmos setup` — A utility for changing saved PC settings.
- `boot sequence` — The order in which boot devices are tried.
- `firmware` — Software built into the hardware.
- `rtc` — The real-time clock keeps date and time.
- `defaults` — Preset values supplied by the manufacturer.

The definitions describe a legacy PC BIOS. Dell documents the boot sequence and power-on self-test. The Phoenix reference describes PC/AT setup, CMOS configuration and the real-time clock. [Dell user guide](https://dl.dell.com/topicspdf/desk_laptop_ug_en-us.pdf) · [Phoenix BIOS reference](https://www.vtda.org/books/Computing/Programming/SystemBIOSforIBMPC_XT_ATComputersandCompatibles_Phoenix.pdf)

The 96 original training questions and 12 held-out questions name the topic explicitly. Each term has one common held-out phrasing and one independently worded probe, fixed before fitting.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch80/012/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/012/model.bin
```
