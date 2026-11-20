# 048 · Abbreviations

The pilot expands eight United States postal state abbreviations, in the context of US addresses. It covers AZ (Arizona), CA (California), FL (Florida), NY (New York), OH (Ohio), TX (Texas), UT (Utah), and WY (Wyoming). Questions use lower case because the runtime normalizes English queries. [U.S. Census Bureau state reference, including STUSAB postal codes](https://www2.census.gov/geo/docs/reference/state.txt)

The original dataset uses 15 training patterns and three held-out patterns for each code. The 24 evaluation prompts were frozen before fitting. Scores measure expansion of these eight known codes and exact state-name capitalization. Unscoped abbreviations may have unrelated meanings in other settings.

Reproduce from PasTinyMoE using the WebTiny trainer at a1a36720ed558d6998e5beed9d4dbdd792626056 and CPU PyTorch 2.15.0. The run used seed 42 and the trainer's default internal validation fraction.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch20/048/train.jsonl \
  --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/048/model.bin
```
