# 023 Pascal records and arrays

Facts cover record fields, array elements and inclusive bounds in a fixed array declaration.

The corpus covers six facts. Its 96 training questions include two cue phrases per fact. The 18 held-out questions include six individually written questions and twelve variants of those cue phrases.

Reference: [Free Pascal language reference](https://www.freepascal.org/docs-html/ref/ref.html), sections on structured types, procedures and functions. Examples use Turbo Pascal syntax.

## Reproduce

From PasTinyMoE, set WEBTINY to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
dir=specialists/batch90/023
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

See train.log for training metrics and pinned.jsonl for exact matches with the native Pascal runtime and manual expert selection.
