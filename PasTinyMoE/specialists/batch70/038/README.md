# 038 BBS and Terminal

Defines sysop, user handle, BBS door, FidoNet NetMail and EchoMail, and ANSI terminal art. Private addressing in NetMail describes the intended recipient and makes no guarantee of confidentiality.

Each of the six terms has 15 training questions and two separately worded held-out questions.

## References

[Bulletin board systems](https://en.wikipedia.org/wiki/Bulletin_board_system), [FidoNet](https://en.wikipedia.org/wiki/FidoNet), and [ANSI art](https://en.wikipedia.org/wiki/ANSI_art)

## Reproduce training

Run from PasTinyMoE with WebTiny's training dependencies installed. Set WEBTINY to a checkout of revision `a1a36720ed558d6998e5beed9d4dbdd792626056`.

```sh
d=specialists/batch70/038
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 4 of 12 held-out answers exactly.
