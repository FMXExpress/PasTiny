# 082 Ancient Greece

Who was honored by the Parthenon? Athena. Where were the ancient Greek Olympic Games held? Olympia. Which Greek city was home to the Spartans? Sparta. Who founded the Academy of ancient Athens? Plato.

The training corpus uses 20 prompts per fact. Two additional phrasings per fact were reserved before training. The pinned results measure exact answers when the native Pascal runtime loads this expert directly.

## Sources

- [Britannica on Parthenon](https://www.britannica.com/topic/Parthenon)
- [Britannica on Olympia](https://www.britannica.com/place/Olympia-ancient-site-Greece)
- [Britannica on Sparta](https://www.britannica.com/place/Sparta)
- [Britannica on Academy](https://www.britannica.com/topic/Academy-ancient-academy-Athens-Greece)

## Reproduce

From PasTinyMoE, set WEBTINY to the WebTiny checkout at commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/082
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch50/082/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/082/model.bin
```
