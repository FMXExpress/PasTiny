# 017 Joystick Desk

Defines horizontal and fore/aft axes, digital buttons, centering, and calibration for a basic DOS joystick. The axis descriptions refer to stick travel. Games can map that travel to different actions.

The corpus contains twenty training prompts and two held-out phrasings for each of 5 facts.

## References

[PC Gameport programming](https://www.epanorama.net/documents/joystick/pc_joystick.html) and [Joystick](https://en.wikipedia.org/wiki/Joystick).

## Reproduce training

Set WEBTINY to WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` with its trainer dependencies installed, and run from PasTinyMoE.

```sh
d=specialists/batch90/017
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 6 of 10 held-out answers exactly.
