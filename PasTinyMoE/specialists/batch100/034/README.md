# 034 Spreadsheet formulas

Uses A1 notation to classify references, identify the fixed part of mixed references, and follow single-cell formula copies.

The corpus covers six facts. Its 96 training questions include two cue phrases per fact. The 18 held-out questions include six individually written questions and twelve variants of those cue phrases.

[Microsoft Excel reference guide](https://support.microsoft.com/en-us/office/switch-between-relative-absolute-and-mixed-references-dfec08cd-ae65-4f56-839e-5f0d8d0baca9).

## Reproduce

From PasTinyMoE, set WEBTINY to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
dir=specialists/batch100/034
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

See train.log for training metrics and pinned.jsonl for exact matches with the native Pascal runtime and manual expert selection.
