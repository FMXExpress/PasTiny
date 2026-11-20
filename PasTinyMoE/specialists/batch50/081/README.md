# 081 Ancient Egypt

Questions cover the roles of Khufu, Hatshepsut, Imhotep and scribes, and the uses of papyrus and the shaduf. [Khufu](https://www.britannica.com/biography/Khufu) · [Hatshepsut](https://www.britannica.com/biography/Hatshepsut) · [Imhotep](https://www.britannica.com/biography/Imhotep) · [Ancient Egyptian literature](https://en.wikipedia.org/wiki/Ancient_Egyptian_literature) · [Shaduf](https://www.britannica.com/technology/shaduf)

Training used 72 prompts. The native Pascal runtime loaded this expert directly and answered 18/18 held-out rephrasings exactly. [Per-question results](oracle.jsonl)

From the PasTinyMoE directory, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/081
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch50/081/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/081/model.bin
```
