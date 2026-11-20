# 086 Inventions

Matches the early stethoscope, braille, mercury barometer, saxophone, flat-disc gramophone and diesel engine with their commonly credited inventors. Personal names use printable ASCII.

[Stethoscope](https://en.wikipedia.org/wiki/Stethoscope), [Braille](https://en.wikipedia.org/wiki/Braille), [barometer](https://en.wikipedia.org/wiki/Barometer), [saxophone](https://en.wikipedia.org/wiki/Saxophone), [Berliner gramophone patent](https://patents.google.com/patent/US372786A/en), [diesel engine](https://en.wikipedia.org/wiki/Diesel_engine).

The corpus contains 90 training questions and 18 separate held-out questions. Held-out questions use alternate wording for the same six inventions.

## Reproduce

From PasTinyMoE, set WEBTINY to a WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056. The trainer uses the default seed 42.

```sh
dir=specialists/batch50/086
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

The training trace is in train.log. The per-question results in pinned.jsonl use the native Pascal host build with this expert selected manually.
