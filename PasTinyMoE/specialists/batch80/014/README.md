# 014 Text screen layout

Byte order and attribute bits refer to conventional IBM PC color text video memory. Cursor coordinates refer to the zero-based BIOS interface. Alternate video pages store separate screen images.

The corpus covers six facts. Its 96 training questions include two cue phrases per fact. The 18 held-out questions include six individually written questions and twelve variants of those cue phrases.

[IBM PC technical references](https://www.pcjs.org/documents/manuals/ibm/pc/) and the [VGA text mode memory layout](https://wiki.osdev.org/VGA_Text_Mode).

## Reproduce

From PasTinyMoE, set WEBTINY to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
dir=specialists/batch80/014
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

See train.log for training metrics and pinned.jsonl for exact matches with the native Pascal runtime and manual expert selection.
