# Fish · expert 056

Four questions anchor the syllabus. Atlantic salmon spawn in fresh water. Sea anemones shelter clownfish. Cartilage supports a shark's skeleton. Male seahorses brood developing offspring. These examples distinguish the animal and the requested relationship. [NOAA Atlantic salmon](https://www.fisheries.noaa.gov/species/atlantic-salmon) · [Clownfish and host anemones](https://en.wikipedia.org/wiki/Clownfish) · [NOAA shark anatomy](https://www.fisheries.noaa.gov/feature-story/12-shark-facts-may-surprise-you) · [NOAA seahorses](https://oceanservice.noaa.gov/facts/seahorse.html)

The JSONL contains original wording. Each of four facts has two frozen evaluation paraphrases. They ask about the same species and facts used for training. The generic word “fish” alone is outside the routing vocabulary.

## Reproduce the export

From PasTinyMoE, using WebTiny at commit a1a36720ed558d6998e5beed9d4dbdd792626056 and CPU PyTorch 2.15.0:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch20/056/train.jsonl --steps 410 --batch-size 8 --threads 1 --lr .00035 --out build/056/model.bin
```

The trainer used its default seed 42 and grouped validation split. See train.log for the recorded run.
