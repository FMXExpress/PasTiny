# SPEC30 expert batch

The DOS edition contains 30 independently trained models. This batch adds ten experts covering natural history and elementary science. Each expert covers the small set of facts listed in its training notes.

| Expert and training notes | DOS weights | Exact answers |
| --- | --- | ---: |
| [058 Spiders](058/README.md) | [SPIDERS.BIN](../models/SPIDERS.BIN) | 9/10 |
| [059 Trees](059/README.md) | [TREES.BIN](../models/TREES.BIN) | 11/12 |
| [060 Flowers](060/README.md) | [FLOWERS.BIN](../models/FLOWERS.BIN) | 6/8 |
| [061 Solar system](061/README.md) | [SOLARSYS.BIN](../models/SOLARSYS.BIN) | 8/8 |
| [062 Stars and Sky](062/README.md) | [STARSKY.BIN](../models/STARSKY.BIN) | 15/18 |
| [063 Weather](063/README.md) | [WEATHER.BIN](../models/WEATHER.BIN) | 13/18 |
| [064 Rocks and geology](064/README.md) | [GEOLOGY.BIN](../models/GEOLOGY.BIN) | 12/12 |
| [065 Electricity](065/README.md) | [CIRCUITS.BIN](../models/CIRCUITS.BIN) | 9/12 |
| [066 Forces and motion](066/README.md) | [FORCES.BIN](../models/FORCES.BIN) | 16/18 |
| [067 Light](067/README.md) | [LIGHT.BIN](../models/LIGHT.BIN) | 15/18 |

## Results

AUTO selected the intended expert on all 134 held-out prompts. Both AUTO and pinned selection produced 114 exact answers (85.1%). The original general model produced zero exact answers. The prompts use unseen wording for concepts covered by the training data. The host regression run reproduced all 381 previously recorded routing and answer outcomes.

[Per-question results](answers.jsonl) · [DOS package](../../dist/SPEC30.ZIP)

## Reproduce

From the PasTinyMoE directory, generate the router index with `python specialists/batch30/catalog.py --index`. Compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC30 EXPERT.PAS` and copy the executable to `bin/SPEC30.EXE`. Build the package in a fresh directory with `python specialists/batch30/catalog.py build/SPEC30`.

For host scoring, compile the same Pascal program with FPC and `-B -dSPEC30`. Run `python specialists/batch30/score.py HOST_EXE build/SPEC30 dist/FLOPPY3` with the expanded FLOPPY3 fixture. Each expert’s notes include its WebTiny training command.

Run `python specialists/batch30/verify.py` to check the shipped weights and compare the saved DOSBox-X transcripts against the host answers. The full run used an emulated FPU. A second run used an emulated 386 with its FPU disabled and exercised two expert switches.
