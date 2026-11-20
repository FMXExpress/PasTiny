# 030 Boolean logic

AND, inclusive OR and XOR each take two Boolean inputs. NOT reverses one input. Answers describe the truth conditions using ordinary language. [Logic gates and their truth tables](https://en.wikipedia.org/wiki/Logic_gate)

Training used 48 prompts. Direct expert selection in the native Pascal runtime yielded 4/12 exact answers on held-out rephrasings. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/030
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch100/030/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/030/model.bin
```
