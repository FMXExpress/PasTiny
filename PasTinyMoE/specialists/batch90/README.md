# SPEC90 expert batch

The DOS package contains 90 trained models. The ten added here cover joysticks, audio devices, serial ports, expansion slots and six Turbo Pascal language topics. Each link below gives the facts taught, sources and training command.

| Expert | DOS model | Correct route | Exact answer |
| --- | --- | ---: | ---: |
| [017 Joystick Desk](017/README.md) | [JOYSTICK.BIN](../models/JOYSTICK.BIN) | 10/10 | 6/10 |
| [018 PC Audio Devices](018/README.md) | [PCAUDIO.BIN](../models/PCAUDIO.BIN) | 8/8 | 5/8 |
| [019 Serial port glossary](019/README.md) | [SERIAL.BIN](../models/SERIAL.BIN) | 12/12 | 9/12 |
| [020 PC expansion slots](020/README.md) | [EXPBUS.BIN](../models/EXPBUS.BIN) | 12/12 | 10/12 |
| [021 Pascal scalar types](021/README.md) | [SCALAR.BIN](../models/SCALAR.BIN) | 10/10 | 6/10 |
| [022 Pascal control flow](022/README.md) | [FLOW.BIN](../models/FLOW.BIN) | 10/10 | 10/10 |
| [023 Pascal records and arrays](023/README.md) | [RECORDS.BIN](../models/RECORDS.BIN) | 18/18 | 16/18 |
| [024 Pascal routines](024/README.md) | [ROUTINES.BIN](../models/ROUTINES.BIN) | 18/18 | 16/18 |
| [025 Pascal file types](025/README.md) | [PASFILES.BIN](../models/PASFILES.BIN) | 8/8 | 6/8 |
| [026 Pascal units](026/README.md) | [UNITS.BIN](../models/UNITS.BIN) | 8/8 | 8/8 |

## Evaluation

Automatic routing selected the intended expert on 114/114 reserved prompts and produced 92/114 exact answers (80.7%). Pinning the intended expert produced 92/114 exact answers. The original general model produced 0/114. These prompts ask about facts taught during training using different wording.

All 1198 prior evaluation outcomes were reproduced. DOSBox-X ran the full AUTO set with an emulated FPU and a two-prompt smoke test in 386 mode with the FPU disabled. [Per-question host results](answers.jsonl) · [DOS replay](ALL.LOG) · [386 smoke test](NOFPU.LOG)

## Build and verify

From PasTinyMoE, run `python specialists/batch90/catalog.py --index` and compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC90 EXPERT.PAS`. Copy the executable to `bin/SPEC90.EXE`. Run `python specialists/batch90/catalog.py build/SPEC90` using a fresh output directory.

To reproduce host scoring, compile the same program with FPC and `-B -dSPEC90`, then run `python specialists/batch90/score.py HOST_EXE build/SPEC90 dist/FLOPPY3` with the expanded general-model fixture. Replay earlier published outcomes with `python specialists/batch90/regression.py HOST_EXE build/SPEC90`. Run `python specialists/batch90/verify.py` to verify the distributed weights, executable and DOS transcripts.

[Download SPEC90](../../dist/SPEC90.ZIP)

[Accuracy and example questions for all 90 experts](scorecard.md)
