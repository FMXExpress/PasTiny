# 037 Modem Desk

Defines six basic Hayes command forms. ATDT and ATDP select tone and pulse dialing. ATA answers a call, ATH0 hangs up, and ATE0 and ATE1 turn local command echo off and on.

Each of the six terms has 15 training questions and two separately worded held-out questions.

## References

[Hayes command set](https://en.wikipedia.org/wiki/Hayes_AT_command_set)

## Reproduce training

Run from PasTinyMoE with WebTiny's training dependencies installed. Set WEBTINY to a checkout of revision `a1a36720ed558d6998e5beed9d4dbdd792626056`.

```sh
d=specialists/batch70/037
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 9 of 12 held-out answers exactly.
