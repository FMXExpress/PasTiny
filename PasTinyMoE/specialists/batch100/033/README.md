# 033 Archive formats

Covers file extensions, central-directory entries, stored ZIP members, and the DOS LHA archiver.

The corpus covers six facts. Its 96 training questions include two cue phrases per fact. The 18 held-out questions include six individually written questions and twelve variants of those cue phrases.

[PKWARE ZIP specification](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT), [ARC file format](https://en.wikipedia.org/wiki/ARC_(file_format)), [LHA archiver](https://en.wikipedia.org/wiki/LHA_(file_format)).

## Reproduce

From PasTinyMoE, set WEBTINY to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
dir=specialists/batch100/033
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

See train.log for training metrics and pinned.jsonl for exact matches with the native Pascal runtime and manual expert selection.
