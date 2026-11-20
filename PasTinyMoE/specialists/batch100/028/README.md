# 028 Debugger Vocabulary

Defines breakpoints, single stepping, watches and the call stack in a local source debugger. A watch displays an expression while the program is paused. The call stack shows the routines whose calls are still active.

The corpus contains twenty training prompts and two held-out phrasings for each of four terms.

## References

[Debugging with GDB](https://sourceware.org/gdb/current/onlinedocs/gdb.html/), especially Stopping and Continuing, Examining the Stack, and Examining Data.

## Reproduce training

Set WEBTINY to WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` with its trainer dependencies installed, and run from PasTinyMoE.

```sh
d=specialists/batch100/028
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 5 of 8 held-out answers exactly.
