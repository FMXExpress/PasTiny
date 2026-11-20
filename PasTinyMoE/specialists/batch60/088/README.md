# 088 Spaceflight

Gives years for the launches of Sputnik 1 (1957), Vostok 1 (1961), Voyager 2 (1977) and Hubble (1990), and for the landings of Apollo 11 (1969) and Viking 1 (1976).

The corpus has 15 training questions and two distinct held-out questions per event. All answers give calendar years.

## References

[Sputnik 1](https://science.nasa.gov/mission/sputnik-1/), [Vostok 1](https://www.esa.int/About_Us/ESA_history/50_years_of_humans_in_space), [Apollo 11](https://www.nasa.gov/mission/apollo-11/), [Viking 1](https://science.nasa.gov/mission/viking-1/), [Voyager 2](https://science.nasa.gov/mission/voyager/voyager-2/) and [Hubble](https://science.nasa.gov/mission/hubble/).

## Reproduce training

Run from PasTinyMoE with WebTiny's training dependencies installed. Set WEBTINY to a checkout of revision `a1a36720ed558d6998e5beed9d4dbdd792626056`.

```sh
d=specialists/batch60/088
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 9 of 12 held-out answers exactly.
