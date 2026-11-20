# 083 Ancient Rome

Who wrote the Aeneid? Virgil. Which volcano buried Pompeii? Vesuvius. Who was the first Roman emperor? Augustus. Which river flows through ancient Rome? Tiber.

The training corpus uses 20 prompts per fact. Two additional phrasings per fact were reserved before training. The pinned results measure exact answers when the native Pascal runtime loads this expert directly.

## Sources

- [Britannica on Aeneid](https://www.britannica.com/topic/Aeneid)
- [Britannica on Pompeii](https://www.britannica.com/place/Vesuvius)
- [Britannica on Augustus](https://www.britannica.com/biography/Augustus-Roman-emperor)
- [Britannica on Tiber](https://www.britannica.com/place/Tiber-River)

## Reproduce

From PasTinyMoE, set WEBTINY to the WebTiny checkout at commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/083
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch50/083/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/083/model.bin
```
