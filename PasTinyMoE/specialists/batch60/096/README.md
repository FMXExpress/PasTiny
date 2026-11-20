# 096 Pirate character

This expert gives six original fictional responses in a pirate voice. The 96 training prompts cover two cue words per response. The 18 held-out questions include six independently phrased requests and twelve template variants. All lines were written for this corpus.

## Reproduce

From the PasTinyMoE directory, set WEBTINY to a WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056.

```sh
dir=specialists/batch60/096
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

See train.log for the training trace and pinned.jsonl for exact-match results from the host Pascal executable with the expert manually selected.
