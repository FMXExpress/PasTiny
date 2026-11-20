# SPEC70 expert batch

The DOS package contains 70 trained models. The ten added here cover DOS concepts, communications and productivity software, fictional characters and story prompts. Each link below gives the facts taught, sources and training command.

| Expert | DOS model | Correct route | Exact answer |
| --- | --- | ---: | ---: |
| [004 File and Path Terms](004/README.md) | [PATHS.BIN](../models/PATHS.BIN) | 12/12 | 12/12 |
| [005 DOS memory terms](005/README.md) | [DOSMEM.BIN](../models/DOSMEM.BIN) | 15/15 | 10/15 |
| [006 Floppy disk terms](006/README.md) | [FLOPPY.BIN](../models/FLOPPY.BIN) | 14/14 | 11/14 |
| [037 Modem Desk](037/README.md) | [MODEM.BIN](../models/MODEM.BIN) | 12/12 | 9/12 |
| [038 BBS and Terminal](038/README.md) | [TERMINAL.BIN](../models/TERMINAL.BIN) | 12/12 | 4/12 |
| [039 WordStar](039/README.md) | [WORDSTAR.BIN](../models/WORDSTAR.BIN) | 18/18 | 13/18 |
| [040 Lotus 1-2-3](040/README.md) | [LOTUS123.BIN](../models/LOTUS123.BIN) | 18/18 | 12/18 |
| [098 Frontier character](098/README.md) | [FRONTIER.BIN](../models/FRONTIER.BIN) | 18/18 | 18/18 |
| [099 Fairy-tale character](099/README.md) | [FAIRY.BIN](../models/FAIRY.BIN) | 18/18 | 16/18 |
| [100 Story sparks](100/README.md) | [STORY.BIN](../models/STORY.BIN) | 12/12 | 11/12 |

## Evaluation

Automatic routing selected the intended expert on 149/149 reserved prompts and produced 116/149 exact answers (77.9%). Pinning the intended expert produced 116/149 exact answers. The original general model produced 0/149. These prompts ask about facts taught during training using different wording.

All 923 prior evaluation outcomes were reproduced. DOSBox-X ran the full AUTO set with an emulated FPU and a two-prompt smoke test in 386 mode with the FPU disabled. [Per-question host results](answers.jsonl) · [DOS replay](ALL.LOG) · [386 smoke test](NOFPU.LOG)

## Build and verify

From PasTinyMoE, run `python specialists/batch70/catalog.py --index` and compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC70 EXPERT.PAS`. Copy the executable to `bin/SPEC70.EXE`. Run `python specialists/batch70/catalog.py build/SPEC70` using a fresh output directory.

To reproduce host scoring, compile the same program with FPC and `-B -dSPEC70`, then run `python specialists/batch70/score.py HOST_EXE build/SPEC70 dist/FLOPPY3` with the expanded general-model fixture. Replay earlier published outcomes with `python specialists/batch70/regression.py HOST_EXE build/SPEC70`. Run `python specialists/batch70/verify.py` to verify the distributed weights, executable and DOS transcripts.

[Download SPEC70](../../dist/SPEC70.ZIP)

[Accuracy and example questions for all 70 experts](scorecard.md)
