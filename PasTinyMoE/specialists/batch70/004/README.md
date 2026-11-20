# 004 File and Path Terms

Defines six DOS file-system terms. A pathname identifies a file or directory. An extension follows the last dot in a filename. The root is the top directory of a drive, a parent is one level above a child, and a subdirectory sits inside another directory. Wildcards allow filename patterns to match names.

Each definition has fifteen training prompts and two independently worded held-out prompts. The questions ask for short definitions.

## References

- [Microsoft, Naming Files, Paths, and Namespaces](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file)
- [Microsoft, dir and wildcard matching](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/dir)

## Reproduce training

Run from PasTinyMoE. Set WEBTINY to a checkout of WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` with the trainer dependencies installed.

```sh
d=specialists/batch70/004
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 12 of 12 held-out answers exactly.
