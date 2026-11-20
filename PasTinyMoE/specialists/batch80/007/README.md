# 007 FAT Volume Terms

Defines clusters, the root directory, the file allocation table and the volume label in the FAT12 and FAT16 file systems. A cluster is the allocation unit. The table records cluster-chain links.

The corpus contains 20 training prompts and two held-out phrasings for each of 4 definitions.

## References

[Elm-Chan, FAT file systems](https://elm-chan.org/docs/fat_e.html) and [Design of the FAT file system](https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system).

## Reproduce training

Set WEBTINY to WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` with its trainer dependencies installed, and run from PasTinyMoE.

```sh
d=specialists/batch80/007
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```
