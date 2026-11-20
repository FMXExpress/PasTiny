# 073 Continents

Four geography questions cover Asia as the largest continent by area, Antarctica as the location of the South Pole, Africa as the location of the Sahara, and Eurasia as the combined landmass of Europe and Asia.

Two held-out phrasings per fact were reserved before fitting. The pinned evaluation tests exact answers with the expert explicitly selected.

## Sources

- [Asia](https://www.britannica.com/place/Asia)
- [South Pole](https://www.britannica.com/place/South-Pole)
- [Sahara](https://www.britannica.com/place/Sahara-desert-Africa)
- [Eurasia](https://www.britannica.com/place/Eurasia)

## Reproduction

From PasTinyMoE, set WEBTINY to the WebTiny checkout at commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/073
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/073/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/073/model.bin
```
