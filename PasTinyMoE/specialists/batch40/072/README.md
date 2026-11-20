# 072 Flags

Four national flag designs cover the Japanese red disc, Canadian maple leaf, Swiss white cross and the Irish tricolour in hoist-to-fly order.

Two held-out phrasings per fact were reserved before fitting. The pinned evaluation tests exact answers with the expert explicitly selected.

## Sources

- [Japanese flag](https://www.britannica.com/topic/flag-of-Japan)
- [Canadian flag](https://www.canada.ca/en/canadian-heritage/services/flag-canada-description.html)
- [Swiss flag](https://www.eda.admin.ch/aboutswitzerland/en/home/gesellschaft/traditionen/fahne.html)
- [Irish flag](https://www.britannica.com/topic/flag-of-Ireland)

## Reproduction

From PasTinyMoE, set WEBTINY to the WebTiny checkout at commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/072
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/072/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/072/model.bin
```
