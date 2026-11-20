# 085 · Exploration

This specialist names the ship associated with each of six historical voyages.

- Cook in 1768 — Endeavour.
- Darwin in 1831 — Beagle.
- Shackleton in 1914 — Endurance.
- Scott in 1910 — Terra Nova.
- Nansen in 1893 — Fram.
- Drake on his circumnavigation — Golden Hind.

The sources identify each explorer and vessel for the specified voyage. Darwin sailed as a naturalist aboard Beagle. Drake's flagship began the voyage as Pelican and returned as Golden Hind.

- Cook's first Pacific voyage. [Smithsonian](https://naturalhistory.si.edu/research/botany/about/historical-expeditions/first-voyage-captain-james-cook)
- Darwin's voyage. [Darwin Correspondence Project](https://www.darwinproject.ac.uk/sites/default/files/learning_resources/The%20Beagle%20Voyage%20Activity%201.pdf)
- Shackleton's Antarctic expedition. [Royal Museums Greenwich](https://www.rmg.co.uk/schools-communities/teacher-resources/meet-ernest-shackleton)
- Scott's last Antarctic expedition. [Scott Polar Research Institute](https://www.spri.cam.ac.uk/museum/events/CLS/Conquering%20the%20Antarctic%20PR.pdf)
- Nansen's Arctic drift. [Fram Museum](https://frammuseum.no/en/polar-history/vessels/the-polar-ship-fram/)
- Drake's circumnavigation. [Royal Museums Greenwich](https://www.rmg.co.uk/file/20586/download?token=MzYhSd-g)

There are 96 original training pairs and 12 probes frozen before fitting, with one shared rephrasing and one individual question per fact.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch50/085/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/085/model.bin
```
