# SPEC50 expert batch

The DOS package contains 50 trained models. The ten added here cover maps, navigation and history. Each link below gives the facts taught, sources and training command.

| Expert | DOS model | Correct route | Exact answer |
| --- | --- | ---: | ---: |
| [078 Landmarks](078/README.md) | [LANDMARK.BIN](../models/LANDMARK.BIN) | 12/12 | 12/12 |
| [079 Map Reader](079/README.md) | [MAPS.BIN](../models/MAPS.BIN) | 12/12 | 9/12 |
| [080 Navigation Terms](080/README.md) | [NAVIGATE.BIN](../models/NAVIGATE.BIN) | 18/18 | 18/18 |
| [081 Ancient Egypt](081/README.md) | [EGYPT.BIN](../models/EGYPT.BIN) | 18/18 | 18/18 |
| [082 Ancient Greece](082/README.md) | [GREECE.BIN](../models/GREECE.BIN) | 8/8 | 7/8 |
| [083 Ancient Rome](083/README.md) | [ROME.BIN](../models/ROME.BIN) | 8/8 | 8/8 |
| [084 Medieval life](084/README.md) | [MEDIEVAL.BIN](../models/MEDIEVAL.BIN) | 12/12 | 10/12 |
| [085 Exploration](085/README.md) | [EXPLORE.BIN](../models/EXPLORE.BIN) | 12/12 | 7/12 |
| [086 Inventions](086/README.md) | [INVENT.BIN](../models/INVENT.BIN) | 18/18 | 14/18 |
| [087 Computing history](087/README.md) | [COMPUTER.BIN](../models/COMPUTER.BIN) | 18/18 | 18/18 |

## Evaluation

Automatic routing selected the intended expert on 136/136 reserved prompts and produced 121/136 exact answers (89.0%). Pinning the intended expert produced 121/136 exact answers. The original general model produced 0/136. These prompts ask about facts taught during training using different wording.

All 651 prior evaluation outcomes were reproduced. DOSBox-X ran the full AUTO set with an emulated FPU and a two-prompt smoke test in 386 mode with the FPU disabled. [Per-question host results](answers.jsonl) · [DOS replay](ALL.LOG) · [386 smoke test](NOFPU.LOG)

## Build and verify

From PasTinyMoE, run `python specialists/batch50/catalog.py --index` and compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC50 EXPERT.PAS`. Copy the executable to `bin/SPEC50.EXE`. Run `python specialists/batch50/catalog.py build/SPEC50` using a fresh output directory.

To reproduce host scoring, compile the same program with FPC and `-B -dSPEC50`, then run `python specialists/batch50/score.py HOST_EXE build/SPEC50 dist/FLOPPY3` with the expanded general-model fixture. Replay earlier published outcomes with `python specialists/batch50/regression.py HOST_EXE build/SPEC50`. Run `python specialists/batch50/verify.py` to verify the distributed weights, executable and DOS transcripts.

[Download SPEC50](../../dist/SPEC50.ZIP)
