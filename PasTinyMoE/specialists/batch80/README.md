# SPEC80 expert batch

The DOS package contains 80 trained models. The ten added here cover DOS files, batch commands, keyboard and BIOS terms, display hardware, graphics and printers. Each link below gives the facts taught, sources and training command.

| Expert | DOS model | Correct route | Exact answer |
| --- | --- | ---: | ---: |
| [007 FAT Volume Terms](007/README.md) | [FATVOL.BIN](../models/FATVOL.BIN) | 8/8 | 1/8 |
| [008 DOS Startup Files](008/README.md) | [STARTUP.BIN](../models/STARTUP.BIN) | 6/6 | 4/6 |
| [009 Batch file vocabulary](009/README.md) | [BATCH.BIN](../models/BATCH.BIN) | 18/18 | 12/18 |
| [010 Text file conventions](010/README.md) | [TEXTFILE.BIN](../models/TEXTFILE.BIN) | 18/18 | 12/18 |
| [011 Keyboard terminology](011/README.md) | [KEYBOARD.BIN](../models/KEYBOARD.BIN) | 12/12 | 12/12 |
| [012 BIOS setup glossary](012/README.md) | [BIOS.BIN](../models/BIOS.BIN) | 12/12 | 10/12 |
| [013 Display adapters](013/README.md) | [DISPADA.BIN](../models/DISPADA.BIN) | 18/18 | 17/18 |
| [014 Text screen layout](014/README.md) | [TEXTSCR.BIN](../models/TEXTSCR.BIN) | 18/18 | 14/18 |
| [015 Bitmap graphics](015/README.md) | [BITMAP.BIN](../models/BITMAP.BIN) | 8/8 | 6/8 |
| [016 Printer desk](016/README.md) | [PRINTER.BIN](../models/PRINTER.BIN) | 8/8 | 6/8 |

## Evaluation

Automatic routing selected the intended expert on 126/126 reserved prompts and produced 94/126 exact answers (74.6%). Pinning the intended expert produced 94/126 exact answers. The original general model produced 0/126. These prompts ask about facts taught during training using different wording.

All 1072 prior evaluation outcomes were reproduced. DOSBox-X ran the full AUTO set with an emulated FPU and a two-prompt smoke test in 386 mode with the FPU disabled. [Per-question host results](answers.jsonl) · [DOS replay](ALL.LOG) · [386 smoke test](NOFPU.LOG)

## Build and verify

From PasTinyMoE, run `python specialists/batch80/catalog.py --index` and compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC80 EXPERT.PAS`. Copy the executable to `bin/SPEC80.EXE`. Run `python specialists/batch80/catalog.py build/SPEC80` using a fresh output directory.

To reproduce host scoring, compile the same program with FPC and `-B -dSPEC80`, then run `python specialists/batch80/score.py HOST_EXE build/SPEC80 dist/FLOPPY3` with the expanded general-model fixture. Replay earlier published outcomes with `python specialists/batch80/regression.py HOST_EXE build/SPEC80`. Run `python specialists/batch80/verify.py` to verify the distributed weights, executable and DOS transcripts.

[Download SPEC80](../../dist/SPEC80.ZIP)

[Accuracy and example questions for all 80 experts](scorecard.md)
