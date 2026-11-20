# 005 DOS memory terms

The expert defines conventional memory, the upper memory area, extended memory, expanded memory and the high memory area in the classic DOS PC memory map. In these answers KB and MB use the historical binary units. XMS and EMS are interfaces, and the corpus uses “XMS memory” and “EMS memory” as shorthand for memory managed through those interfaces. [The MS-DOS Encyclopedia, section II](https://www.pcjs.org/documents/books/mspl13/msdos/encyclopedia/section2/) · [High memory area](https://en.wikipedia.org/wiki/High_memory_area)

Training used 60 short prompts. Direct expert selection in the native Pascal runtime yielded 10/15 exact answers on held-out phrasings. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/005
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch70/005/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/005/model.bin
```
