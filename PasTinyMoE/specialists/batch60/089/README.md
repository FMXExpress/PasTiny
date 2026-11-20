# 089 Transport History

Gives years for the Wright Flyer’s first powered flight (1903), the sinking of Titanic (1912), Lindbergh’s solo New York–Paris crossing (1927), the opening of the first Shinkansen line (1964), Concorde’s first flight (1969), and the start of Eurostar passenger service (1994).

The corpus has 15 training questions and two distinct held-out questions per event. All answers give calendar years.

## References

[Smithsonian, Wright Flyer](https://airandspace.si.edu/collection-objects/1903-wright-flyer/nasm_A19610048000), [Britannica, Titanic](https://www.britannica.com/topic/Titanic), [Smithsonian, Spirit of St. Louis](https://airandspace.si.edu/collection-objects/ryan-nyp-spirit-st-louis/nasm_A19280021000), [Britannica, Shinkansen](https://www.britannica.com/technology/Shinkansen), [Britannica, Concorde](https://www.britannica.com/technology/Concorde) and [Eurostar, Our history](https://www.eurostar.com/uk-en/about-eurostar/our-company/our-history).

## Reproduce training

Run from PasTinyMoE with WebTiny's training dependencies installed. Set WEBTINY to a checkout of revision `a1a36720ed558d6998e5beed9d4dbdd792626056`.

```sh
d=specialists/batch60/089
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 11 of 12 held-out answers exactly.
