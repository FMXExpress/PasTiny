# 084 · Medieval life

This specialist gives the main task of six trades found in medieval European towns.

- Cooper — Made wooden barrels.
- Miller — Ground grain into flour.
- Weaver — Wove yarn into cloth.
- Tanner — Turned hides into leather.
- Potter — Made clay vessels.
- Blacksmith — Forged iron objects.

The Swedish History Museum describes medieval trade and town workshops. A Middle Ages teacher guide documents named trades. The craft definitions also follow the medieval occupations glossary. [Swedish History Museum](https://historiska.se/en/explore-history/history-hub/medieval-professions-and-the-feaudal-society/) · [Teacher guide](https://hickmanschools.org/hcs/wp-content/uploads/2024/11/middleages.pdf) · [Occupations glossary](https://ironboundtome.wordpress.com/ars-magica/medieval-occupations-and-careers/)

There are 96 original training pairs and 12 probes frozen before fitting, with one shared rephrasing and one individual question per fact.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch50/084/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/084/model.bin
```
