# 076 · Oceans and seas

This location pilot identifies the major landmasses on the east and west sides of the Pacific and Atlantic oceans, the North Pole as a reference for the Arctic Ocean, and the broad locations of the Mediterranean, Baltic and Adriatic seas. The east/west answers describe major regions; they are deliberately concise and omit exhaustive coastlines, islands and maritime-boundary definitions. The proper names in the syllabus are the six routing anchors.

The prompts and answers are original pilot material. Reference entries: [Pacific](https://en.wikipedia.org/wiki/Pacific_Ocean), [Atlantic](https://en.wikipedia.org/wiki/Atlantic_Ocean), [Arctic](https://en.wikipedia.org/wiki/Arctic_Ocean), [Mediterranean](https://en.wikipedia.org/wiki/Mediterranean_Sea), [Baltic](https://en.wikipedia.org/wiki/Baltic_Sea), [Adriatic](https://en.wikipedia.org/wiki/Adriatic_Sea).

There are 84 development rows and 18 separately frozen questions, three per geographic name, including an individually written question for each. Reusing the six names tests phrasing within this syllabus.

Run from PasTinyMoE with CPU PyTorch 2.15.0, WebTiny trainer commit a1a36720ed558d6998e5beed9d4dbdd792626056 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/076/train.jsonl \
  --steps 550 --batch-size 8 --threads 1 --lr .00035 --out build/076/model.bin
```
