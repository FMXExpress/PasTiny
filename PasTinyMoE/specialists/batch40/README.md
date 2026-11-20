# SPEC40 expert batch

The DOS package contains 40 trained models. The ten added here cover elementary science and world geography. Each link below gives the facts taught, sources and training command.

| Expert | DOS model | Correct route | Exact answer |
| --- | --- | ---: | ---: |
| [068 Sound](068/README.md) | [SOUND.BIN](../models/SOUND.BIN) | 12/12 | 11/12 |
| [069 Elements and Matter](069/README.md) | [MATTER.BIN](../models/MATTER.BIN) | 12/12 | 11/12 |
| [070 Human Body](070/README.md) | [ANATOMY.BIN](../models/ANATOMY.BIN) | 18/18 | 18/18 |
| [071 Countries and Capitals](071/README.md) | [CAPITALS.BIN](../models/CAPITALS.BIN) | 18/18 | 18/18 |
| [072 Flags](072/README.md) | [FLAGS.BIN](../models/FLAGS.BIN) | 8/8 | 7/8 |
| [073 Continents](073/README.md) | [CONTINNT.BIN](../models/CONTINNT.BIN) | 8/8 | 7/8 |
| [074 Rivers](074/README.md) | [RIVERS.BIN](../models/RIVERS.BIN) | 12/12 | 12/12 |
| [075 Mountains](075/README.md) | [MOUNTAIN.BIN](../models/MOUNTAIN.BIN) | 12/12 | 12/12 |
| [076 Oceans and seas](076/README.md) | [OCEANS.BIN](../models/OCEANS.BIN) | 18/18 | 17/18 |
| [077 Cities](077/README.md) | [CITIES.BIN](../models/CITIES.BIN) | 18/18 | 18/18 |

## Evaluation

Automatic routing selected the intended expert on 136/136 reserved prompts and produced 131/136 exact answers (96.3%). Pinning the intended expert produced 131/136 exact answers. The original general model produced 6/136. These prompts ask about facts taught during training using different wording.

All 515 prior evaluation outcomes were reproduced. DOSBox-X ran the full AUTO set with an emulated FPU and a two-prompt smoke test in 386 mode with the FPU disabled. [Per-question host results](answers.jsonl) · [DOS replay](ALL.LOG) · [386 smoke test](NOFPU.LOG)

## Build and verify

From PasTinyMoE, run `python specialists/batch40/catalog.py --index` and compile `EXPERT.PAS` with Turbo Pascal 7 using `TPC /B /DSPEC40 EXPERT.PAS`. Copy the executable to `bin/SPEC40.EXE`. Run `python specialists/batch40/catalog.py build/SPEC40` using a fresh output directory.

To reproduce host scoring, compile the same program with FPC and `-B -dSPEC40`, then run `python specialists/batch40/score.py HOST_EXE build/SPEC40 dist/FLOPPY3` with the expanded general-model fixture. Run `python specialists/batch40/verify.py` to verify the distributed weights, executable and DOS transcripts.

[Download SPEC40](../../dist/SPEC40.ZIP)
