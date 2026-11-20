# SPEC60 expert batch

The DOS package contains 60 trained models. The ten added here cover history, word games and fictional characters. Each link below gives the facts taught, sources and training command.

| Expert | DOS model | Correct route | Exact answer |
| --- | --- | ---: | ---: |
| [088 Spaceflight](088/README.md) | [SPACEFLT.BIN](../models/SPACEFLT.BIN) | 12/12 | 9/12 |
| [089 Transport History](089/README.md) | [TRANSIT.BIN](../models/TRANSIT.BIN) | 12/12 | 11/12 |
| [090 History vocabulary](090/README.md) | [HISTVOC.BIN](../models/HISTVOC.BIN) | 18/18 | 16/18 |
| [091 Riddle hints](091/README.md) | [RIDDLES.BIN](../models/RIDDLES.BIN) | 18/18 | 17/18 |
| [092 Wordplay](092/README.md) | [WORDPLAY.BIN](../models/WORDPLAY.BIN) | 8/8 | 8/8 |
| [093 Chess vocabulary](093/README.md) | [CHESS.BIN](../models/CHESS.BIN) | 8/8 | 8/8 |
| [094 Adventure vocabulary](094/README.md) | [ADVENT.BIN](../models/ADVENT.BIN) | 12/12 | 10/12 |
| [095 Dungeon descriptions](095/README.md) | [DUNGEON.BIN](../models/DUNGEON.BIN) | 12/12 | 10/12 |
| [096 Pirate character](096/README.md) | [PIRATE.BIN](../models/PIRATE.BIN) | 18/18 | 17/18 |
| [097 Spaceship character](097/README.md) | [STARSHIP.BIN](../models/STARSHIP.BIN) | 18/18 | 15/18 |

## Evaluation

Automatic routing selected the intended expert on 136/136 reserved prompts and produced 121/136 exact answers (89.0%). Pinning the intended expert produced 121/136 exact answers. The original general model produced 1/136. These prompts ask about facts taught during training using different wording.

All 787 prior evaluation outcomes were reproduced. DOSBox-X ran the full AUTO set with an emulated FPU and a two-prompt smoke test in 386 mode with the FPU disabled. [Per-question host results](answers.jsonl) · [DOS replay](ALL.LOG) · [386 smoke test](NOFPU.LOG)

## Build and verify

From PasTinyMoE, run `python specialists/batch60/catalog.py --index` and compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC60 EXPERT.PAS`. Copy the executable to `bin/SPEC60.EXE`. Run `python specialists/batch60/catalog.py build/SPEC60` using a fresh output directory.

To reproduce host scoring, compile the same program with FPC and `-B -dSPEC60`, then run `python specialists/batch60/score.py HOST_EXE build/SPEC60 dist/FLOPPY3` with the expanded general-model fixture. Replay earlier published outcomes with `python specialists/batch60/regression.py HOST_EXE build/SPEC60`. Run `python specialists/batch60/verify.py` to verify the distributed weights, executable and DOS transcripts.

[Download SPEC60](../../dist/SPEC60.ZIP)

[Accuracy and example questions for all 60 experts](scorecard.md)
