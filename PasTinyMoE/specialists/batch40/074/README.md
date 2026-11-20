# 074 · Rivers

This pilot returns a continent when asked where one of six named rivers is located. The syllabus covers Nile (Africa), Amazon (South America), Danube (Europe), Yangtze (Asia), Mississippi (North America), Congo (Africa).

The National Assessment of Educational Progress lists the Nile, Amazon, Yangtze, Mississippi-Missouri and Congo by continent. The International Commission for the Protection of the Danube River places the Danube in Europe. [NAEP atlas](https://www.nationsreportcard.gov/nqt/api/QueryResults/GetItemResource?TableID=6a984416-132f-4cf6-9058-33fc4ee24a69) · [Danube basin](https://www.icpdr.org/danube-basin/danube-river-basin)

The training set contains 16 original question forms per name. The 12 held-out questions were frozen before training. Each name has one shared question form and one individually worded prompt. These probes test recall of the six names across phrasing.

## Reproduction

From PasTinyMoE with WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15, default seed 42:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/074/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/074/model.bin
```
