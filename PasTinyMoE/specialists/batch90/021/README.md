# 021 · Pascal scalar types

The expert explains five fixed Turbo Pascal 7 examples. The questions and code examples were written for this pilot.

- `var x: boolean;` — It holds False or True.
- `var x: char;` — It stores one 8-bit character.
- `var x: byte;` — It holds an integer from 0 to 255.
- `var x: integer;` — It stores a signed 16-bit integer.
- `var x: longint;` — It stores a signed 32-bit integer.

The definitions follow Borland’s Turbo Pascal 7.0 Language Guide. [Language Guide](https://bitsavers.org/pdf/borland/turbo_pascal/Turbo_Pascal_Version_7.0_Language_Guide_1992.pdf)

The 80 training questions use the fixed examples in different phrasings. The ten probes were frozen before fitting. There is one new common question form and one individual probe per example.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch90/021/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/021/model.bin
```
