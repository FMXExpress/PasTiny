# 078 Landmarks

Answers location questions about six landmarks. Eiffel Tower and Colosseum answers give cities. Stonehenge answers give the UK constituent country. The remaining three answers give countries.

The corpus contains 15 training examples and two held-out questions for each fact. The evaluation checks recall across wording changes.

## References

- [Eiffel Tower visitor information](https://www.toureiffel.paris/en)
- [Colosseum Archaeological Park](https://colosseo.it/en/)
- [English Heritage, Stonehenge](https://www.english-heritage.org.uk/visit/places/stonehenge/)
- UNESCO World Heritage listings for [Petra](https://whc.unesco.org/en/list/326/), the [Acropolis](https://whc.unesco.org/en/list/404/), and the [pyramids at Giza](https://whc.unesco.org/en/list/86/).

## Training

Run from PasTinyMoE with WebTiny's training dependencies installed. Set WEBTINY to a checkout of revision `a1a36720ed558d6998e5beed9d4dbdd792626056`.

```sh
d=specialists/batch50/078
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 12 of 12 held-out answers exactly.
