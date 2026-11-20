# 063 · Weather

The six terms are fog, dew, hail, drizzle, wind and gust. These definitions cover stable everyday terminology. Live weather conditions, predictions, and geographic forecasts are outside the syllabus. [US National Weather Service glossary](https://forecast.weather.gov/glossary.php) · [World Meteorological Organization International Cloud Atlas](https://cloudatlas.wmo.int/en/home.html)

Six terms each received twelve original training questions, three evaluation questions and one canonical short answer. The eighteen evaluation questions were fixed before training and use new wording for the same facts. Exact matching measures recall of these particular answers. Alternative accurate descriptions may score zero.

From PasTinyMoE with CPU PyTorch 2.15.0, use WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056, seed 42 and the existing general TINY.BIN weights.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch30/063/train.jsonl \
  --steps 450 --batch-size 8 --threads 1 --lr .00035 --out build/063/model.bin
```

The independently pinned native Pascal replay produced 13/18 exact answers. [Per-question results](oracle.jsonl)
