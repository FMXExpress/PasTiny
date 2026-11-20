# 087 Computing history

Dates six specific milestones: ENIAC public dedication (1946), EDSAC’s first successful program (1949), UNIVAC I delivery to the US Census Bureau (1951), the Altair 8800 Popular Electronics cover issue (January 1975), the original Macintosh introduction (1984), and Commodore 64 commercial release (1982).

Computer History Museum timeline entries for [ENIAC](https://www.computerhistory.org/timeline/1946/), [EDSAC](https://www.computerhistory.org/timeline/1949/), [UNIVAC I](https://www.computerhistory.org/timeline/1951/), [Altair](https://www.computerhistory.org/timeline/1975/), [Commodore 64](https://www.computerhistory.org/timeline/1982/), and [Macintosh](https://www.computerhistory.org/timeline/1984/).

The corpus contains 90 training questions and 18 separate held-out questions. The held-out questions change the introductory wording and repeat each entity and event label. They measure recall when the milestone is explicitly named.

## Reproduce

From PasTinyMoE, set WEBTINY to a WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056. The trainer uses the default seed 42.

```sh
dir=specialists/batch50/087
python "$WEBTINY/training/train.py" --init TINY.BIN --data "$dir/train.jsonl" --steps 600 --batch-size 8 --threads 1 --lr .00035 --out "$dir/model.bin"
```

The training trace is in train.log. The per-question results in pinned.jsonl use the native Pascal host build with this expert selected manually.
