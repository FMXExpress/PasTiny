# 077 · Cities

The first syllabus answers which country contains each of six named cities, using the familiar large city in each case. It covers Osaka in Japan, Hamburg in Germany, Montreal in Canada, Marseille in France, Bologna in Italy and Busan in South Korea. The proper names are the routing anchors. The model has no map, live location or trip-planning data.

Country assignments follow the introductory geography of [Osaka](https://en.wikipedia.org/wiki/Osaka), [Hamburg](https://en.wikipedia.org/wiki/Hamburg), [Montreal](https://en.wikipedia.org/wiki/Montreal), [Marseille](https://en.wikipedia.org/wiki/Marseille), [Bologna](https://en.wikipedia.org/wiki/Bologna) and [Busan](https://en.wikipedia.org/wiki/Busan). All prompt templates, varied probes and concise reference labels were written for the pilot.

The development corpus contains 84 questions. Eighteen questions were frozen before fitting, including six individually written probes. Evaluation tests wording about the same six cities.

Run from PasTinyMoE with CPU PyTorch 2.15.0, WebTiny trainer commit a1a36720ed558d6998e5beed9d4dbdd792626056 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/077/train.jsonl \
  --steps 550 --batch-size 8 --threads 1 --lr .00035 --out build/077/model.bin
```
