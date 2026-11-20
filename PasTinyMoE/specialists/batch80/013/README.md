# 013 Display adapters

The CGA counts refer to colors visible simultaneously in the standard BIOS modes. EGA mode 10h and VGA mode 13h are hexadecimal BIOS mode numbers.

The corpus covers six facts. Its 96 training questions include two cue phrases per fact. The 18 held-out questions include six individually written questions and twelve variants of those cue phrases.

IBM adapter descriptions and BIOS mode tables in the [IBM PC technical references](https://www.pcjs.org/documents/manuals/ibm/pc/), plus the [DOSBox-X video mode table](https://dosbox-x.com/wiki/Guide:Video-modes).

## Reproduce

From PasTinyMoE, set WEBTINY to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
dir=specialists/batch80/013
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

See train.log for training metrics and pinned.jsonl for exact matches with the native Pascal runtime and manual expert selection.
