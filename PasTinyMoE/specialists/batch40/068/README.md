# 068 Sound

Covers pure-tone pitch, frequency units, echoes, vibration, infrasound, and ultrasound. The 20 Hz and 20 kHz thresholds describe conventional approximate limits of human hearing. Questions about hertz include acoustic context because the electricity specialist also handles that unit.

The training file contains 90 authored question/answer pairs covering six facts. The held-out file contains twelve distinct prompts covering the same facts. It measures recall across alternate phrasings.

## Fact references

- [OpenStax Physics, Speed of Sound, Frequency, and Wavelength](https://openstax.org/books/physics/pages/14-1-speed-of-sound-frequency-and-wavelength)
- [OpenStax College Physics, Sound](https://openstax.org/books/college-physics-2e/pages/17-1-sound)

## Reproduce training

Run from the PasTinyMoE directory with the WebTiny training dependencies installed. Set WEBTINY to a checkout of WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056`. The trainer initializes from the repository's TINY.BIN and uses its default seed of 42.

```sh
d=specialists/batch40/068
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --out "$d/model.bin"
```

The exported model answered 11 of 12 held-out prompts exactly using the WebTiny CPU decoder.
