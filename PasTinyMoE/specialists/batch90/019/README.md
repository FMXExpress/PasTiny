# 019 Serial port glossary

These four answers describe common asynchronous serial terminology. Baud counts transmitted symbols per second. Parity provides a simple error check. Stop bits delimit characters, and flow control lets a receiver pace transmission. [Serial HOWTO](https://tldp.org/HOWTO/Serial-HOWTO.html) · [Baud](https://en.wikipedia.org/wiki/Baud)

Training used 48 prompts. Direct expert selection in the native Pascal runtime yielded 9/12 exact answers on held-out rephrasings. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/019
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch90/019/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/019/model.bin
```
