# 064 · Rocks and geology

This pilot classifies six named rocks by their broad geologic origin. It answers with one of three classes.

| Class | Examples in the syllabus | Source |
|---|---|---|
| Igneous | Granite, basalt | [National Park Service](https://www.nps.gov/subjects/geology/igneous.htm) |
| Sedimentary | Sandstone, limestone | [National Park Service](https://www.nps.gov/subjects/geology/sedimentary.htm) |
| Metamorphic | Marble, slate | [National Park Service](https://www.nps.gov/subjects/geology/metamorphic.htm) |

Each named rock has 14 original development questions. The 12 frozen held-out questions include one new pattern and one individual probe per rock. All probes contain the rock name; the score measures classification from that name across phrasing. Identifying a physical specimen from appearance falls outside the syllabus. The three source pages were checked for the listed examples.

## Reproduction

Run from PasTinyMoE with WEBTINY at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/batch30/064/train.jsonl --steps 550 \
  --threads 1 --batch-size 10 --lr .00035 --out build/064/model.bin
```
