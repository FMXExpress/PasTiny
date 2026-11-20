# 090 History vocabulary

Six definitions cover chronology, dynasty, artifact, era, monarchy and historiography. Each answer gives the historical sense in a single sentence. Definitions are original summaries. [Chronology](https://www.britannica.com/topic/chronology) · [Historiography](https://www.britannica.com/topic/historiography) · [Monarchy](https://www.britannica.com/topic/monarchy) · [Dynasty](https://www.merriam-webster.com/dictionary/dynasty) · [Artifact](https://www.merriam-webster.com/dictionary/artifact) · [Era](https://www.merriam-webster.com/dictionary/era)

There are 72 training prompts and 18 held-out rephrasings of the six subjects. From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/090
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch60/090/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/090/model.bin
```

The native Pascal runtime loaded this expert directly and answered 16/18 held-out questions exactly. [Per-question results](oracle.jsonl)
