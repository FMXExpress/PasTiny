# 022 · Pascal control flow

The expert explains five fixed Turbo Pascal 7 examples. The questions and code examples were written for this pilot.

- `if ok then inc(n);` — Increment n only if ok is true.
- `case k of 1: x := 9 end;` — Set x to 9 if k equals 1.
- `while n > 0 do dec(n);` — Test n first and decrement while positive.
- `repeat inc(n) until n >= 3;` — Increment at least once, then test n.
- `for i := 1 to 3 do inc(n);` — Increment n once for each i from 1 to 3.

The definitions follow Borland’s Turbo Pascal 7.0 Language Guide. [Language Guide](https://bitsavers.org/pdf/borland/turbo_pascal/Turbo_Pascal_Version_7.0_Language_Guide_1992.pdf)

The 80 training questions use the fixed examples in different phrasings. The ten probes were frozen before fitting. There is one new common question form and one individual probe per example.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch90/022/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/022/model.bin
```
