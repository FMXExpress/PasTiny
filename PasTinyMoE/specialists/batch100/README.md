# SPEC100 expert batch

The DOS package contains 100 trained models. The ten added here cover compiler and debugger terms, number notation, Boolean logic, sorting, data structures, archives, spreadsheets, databases and editor navigation. Each link below gives the facts taught, sources and training command.

| Expert | DOS model | Correct route | Exact answer |
| --- | --- | ---: | ---: |
| [027 Compiler Messages](027/README.md) | [COMPILE.BIN](../models/COMPILE.BIN) | 8/8 | 6/8 |
| [028 Debugger Vocabulary](028/README.md) | [DEBUGGER.BIN](../models/DEBUGGER.BIN) | 8/8 | 5/8 |
| [029 Number notation](029/README.md) | [NUMBASE.BIN](../models/NUMBASE.BIN) | 12/12 | 9/12 |
| [030 Boolean logic](030/README.md) | [BOOLLOG.BIN](../models/BOOLLOG.BIN) | 12/12 | 4/12 |
| [031 Sorting vocabulary](031/README.md) | [SORTING.BIN](../models/SORTING.BIN) | 8/8 | 6/8 |
| [032 Data structures](032/README.md) | [DATASTR.BIN](../models/DATASTR.BIN) | 6/6 | 5/6 |
| [033 Archive formats](033/README.md) | [ARCHIVES.BIN](../models/ARCHIVES.BIN) | 18/18 | 17/18 |
| [034 Spreadsheet formulas](034/README.md) | [FORMULAS.BIN](../models/FORMULAS.BIN) | 18/18 | 17/18 |
| [035 Database vocabulary](035/README.md) | [DATABASE.BIN](../models/DATABASE.BIN) | 8/8 | 5/8 |
| [036 Text editor navigation](036/README.md) | [EDITNAV.BIN](../models/EDITNAV.BIN) | 10/10 | 8/10 |

## Evaluation

Automatic routing selected the intended expert on 108/108 reserved prompts and produced 82/108 exact answers (75.9%). Pinning the intended expert produced 82/108 exact answers. The original general model produced 0/108. These prompts ask about facts taught during training using different wording.

All 1312 prior evaluation outcomes were reproduced. DOSBox-X ran the full AUTO set with an emulated FPU and a two-prompt smoke test in 386 mode with the FPU disabled. [Per-question host results](answers.jsonl) · [DOS replay](ALL.LOG) · [386 smoke test](NOFPU.LOG)

Boolean Logic answered 4 of 12 held-out prompts exactly with either routing mode. For “when is a two input and gate true”, the model generated “It reverses the true.” The expected answer is “True when both inputs are true.” The independent DOS catalog check listed all 100 IDs and free heap returned to 24,824 bytes after switching between experts 100 and 1 with the emulated FPU disabled. [Catalog and memory transcript](CATALOG.LOG)

## Build and verify

From PasTinyMoE, run `python specialists/batch100/catalog.py --index` and compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC100 EXPERT.PAS`. Copy the executable to `bin/SPEC100.EXE`. Run `python specialists/batch100/catalog.py build/SPEC100` using a fresh output directory.

To reproduce host scoring, compile the same program with FPC and `-B -dSPEC100`, then run `python specialists/batch100/score.py HOST_EXE build/SPEC100 dist/FLOPPY3` with the expanded general-model fixture. Replay earlier published outcomes with `python specialists/batch100/regression.py HOST_EXE build/SPEC100`. Run `python specialists/batch100/verify.py` to verify the distributed weights, executable and DOS transcripts.

[Download SPEC100](../../dist/SPEC100.ZIP)

[Accuracy and example questions for all 100 experts](scorecard.md)
