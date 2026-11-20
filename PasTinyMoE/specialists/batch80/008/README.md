# 008 DOS Startup Files

Covers the historical roles of CONFIG.SYS, AUTOEXEC.BAT and COMMAND.COM in MS-DOS 6.22. CONFIG.SYS sets system options and loads device drivers, AUTOEXEC.BAT runs startup commands, and COMMAND.COM interprets DOS commands.

The corpus contains 20 training prompts and two held-out phrasings for each of 3 definitions.

## References

[CONFIG.SYS](https://en.wikipedia.org/wiki/CONFIG.SYS), [AUTOEXEC.BAT](https://en.wikipedia.org/wiki/AUTOEXEC.BAT), and [COMMAND.COM](https://en.wikipedia.org/wiki/COMMAND.COM).

## Reproduce training

Set WEBTINY to WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` with its trainer dependencies installed, and run from PasTinyMoE.

```sh
d=specialists/batch80/008
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```
