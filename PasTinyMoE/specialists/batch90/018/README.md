# 018 PC Audio Devices

Distinguishes the PC speaker, FM synthesis, MIDI messages, and sampled audio playback. The answers describe device or data roles in early PC audio.

The corpus contains twenty training prompts and two held-out phrasings for each of 4 facts.

## References

[PC speaker](https://en.wikipedia.org/wiki/PC_speaker), [frequency modulation synthesis](https://en.wikipedia.org/wiki/Frequency_modulation_synthesis), [MIDI](https://en.wikipedia.org/wiki/MIDI), and [digital audio](https://en.wikipedia.org/wiki/Digital_audio).

## Reproduce training

Set WEBTINY to WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` with its trainer dependencies installed, and run from PasTinyMoE.

```sh
d=specialists/batch90/018
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 5 of 8 held-out answers exactly.
