# 075 · Mountains

This pilot returns a continent when asked where one of six named mountain ranges is located. The syllabus covers Andes (South America), Himalayas (Asia), Alps (Europe), Rocky Mountains (North America), Atlas Mountains (Africa), Pyrenees (Europe).

The South Carolina Department of Natural Resources lists mountain ranges by continent and maps major ranges in its *Landforms* lesson. [Landforms](https://www.dnr.sc.gov/geology/pdfs/education/Landforms.pdf)

The training set contains 16 original question forms per name. The 12 held-out questions were frozen before training. Each name has one shared question form and one individually worded prompt. These probes test recall of the six names across phrasing.

## Reproduction

From PasTinyMoE with WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15, default seed 42:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/075/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/075/model.bin
```
