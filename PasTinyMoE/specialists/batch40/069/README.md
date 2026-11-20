# 069 Elements and matter

Covers chemical symbols for sodium, iron, and copper, and the directions of sublimation, condensation, and freezing. Expected symbol answers preserve capitalization.

The training file contains 90 authored question/answer pairs covering six facts. The held-out file contains twelve distinct prompts covering the same facts. It measures recall across alternate phrasings.

## Fact references

- [IUPAC periodic table](https://iupac.org/what-we-do/periodic-table-of-elements/)
- [OpenStax Chemistry, Phase Transitions](https://openstax.org/books/chemistry-2e/pages/10-3-phase-transitions)

## Reproduce training

Run from the PasTinyMoE directory with the WebTiny training dependencies installed. Set WEBTINY to a checkout of WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056`. The trainer initializes from the repository's TINY.BIN and uses its default seed of 42.

```sh
d=specialists/batch40/069
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --out "$d/model.bin"
```

The exported model answered 11 of 12 held-out prompts exactly using the WebTiny CPU decoder.
