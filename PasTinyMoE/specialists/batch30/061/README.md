# Solar system · expert 061

The pilot answers four identification questions: Mercury is the planet closest to the Sun, Jupiter is the largest planet in the solar system, Ganymede is the largest moon in the solar system, and Mars is known as the Red Planet. The syllabus does not cover predicting eclipses, telescope observations or current positions. [NASA Mercury](https://science.nasa.gov/mercury/facts/) · [NASA Jupiter](https://science.nasa.gov/jupiter/facts/) · [NASA Ganymede](https://science.nasa.gov/jupiter/moons/ganymede/) · [NASA Mars](https://science.nasa.gov/mars/facts/)

The prompts use original wording. Eight questions frozen before fitting probe alternative wording for these same four facts. The limited input vocabulary favors questions about planets and moons; the word Mars alone is insufficient evidence of one supported intent.

## Reproduction

Run from PasTinyMoE with CPU PyTorch 2.15.0 and WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056. The trainer uses the default seed 42 and grouped validation split.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch30/061/train.jsonl --steps 520 --batch-size 8 --threads 1 --lr .00035 --out build/061/model.bin
```
