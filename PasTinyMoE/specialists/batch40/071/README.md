# 071 · Countries and Capitals

Six country-to-capital pairs cover Finland, Ghana, Japan, Kenya, Norway and Portugal. On 2026-11-19 Pacific time, the World Bank country API returned Helsinki, Accra, Tokyo, Nairobi, Oslo and Lisbon respectively. The source query identifies countries by ISO3 code. This pilot covers that dated fixed list. [Source query](https://api.worldbank.org/v2/country/FIN;KEN;PRT;JPN;GHA;NOR?format=json) · [Local source extract](capitals.tsv)

The 72 original development questions use 12 phrasings per country. Eighteen held-out questions use two other templates and one independently phrased question per country and were frozen before training. The test measures recall for six known countries on new wording.

From PasTinyMoE use CPU PyTorch 2.15.0 and WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, with seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/071/train.jsonl \
  --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/071/model.bin
```

The independently pinned native Pascal replay produced 18/18 exact answers. [Per-question results](oracle.jsonl)
