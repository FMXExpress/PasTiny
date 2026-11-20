# 040 Lotus 1-2-3 Release 3 for DOS

The six facts cover cell editing (F2), recalculation (F9), the slash command menu, the top-left cell (A1), and the @SUM and @AVG functions. Final periods punctuate answers. [Lotus 1-2-3 Release 3 Reference Manual (1989), keyboard and spreadsheet functions](https://archive.org/details/lotus-1-2-3-release-3-reference-manual-1989)

The training split contains 72 prompts across six facts. The 18 held-out queries include one hand-written end-user question per fact. Loading the expert directly in the native Pascal runtime yielded 12/18 exact answers. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/040
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch70/040/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/040/model.bin
```
