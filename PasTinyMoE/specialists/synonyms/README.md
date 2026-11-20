# Synonyms · expert 046

[Download SPEC10.ZIP](../../dist/SPEC10.ZIP) and extract it to its own DOS directory on an SD card. Run EXPERT and enter `give a synonym for rapid`, or pin the specialist with `USE 46`. The package contains all ten trained pilot models. One complete model is loaded for inference at a time.

Synonyms shares Word Bench's eight adjectives. It gives a single substitute for a specified sense, such as *swift* for *rapid* in “a rapid current” or *slim* for *narrow* in “a narrow margin.” The full list is in [syllabus.tsv](syllabus.tsv). Other synonyms may be valid in other contexts.

## Quality and routing

| Exact target word | 24 withheld wording probes | 8 individually written prompts |
|---|---:|---:|
| Original general model | 0 | 0 |
| Expert 046 pinned | 20 | 5 |
| SPEC10 AUTO | 20 | 5 |

The individually written probes were added after training. Every probe names one of the eight trained adjectives. All 32 AUTO calls selected expert 046. The score measures reproduction of the single reference word. Errors included returning “short” for “silent” and “most” for “damp.” [Full answers](results.jsonl)

The router first identifies the headword and competing topics, then checks for request phrases including “synonym,” “another word,” and “alternative to.” The shared headword plus a substitution request selects expert 046. A plain definition question selects Word Bench (041). An unsupported headword or explicit competing domain on a synonym request asks for clarification. A native replay reproduced all 201 earlier regression outcomes.

## Reproduction

From PasTinyMoE, use Python 3.12, CPU PyTorch 2.15 and WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056. The training set has 120 original examples, with 108 used for fitting and 12 for internal validation. The default seed is 42. The model was fine-tuned independently from TINY.BIN.

```sh
python specialists/synonyms/data.py
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/synonyms/train.jsonl \
  --steps 650 --threads 2 --batch-size 12 --lr .00035 --out build/synonyms/SYNONYM.BIN
python specialists/synonyms/build.py build/SPEC10
```

BUILD.BAT creates bin/SPEC10.EXE's corresponding target with TPC /B /DSPEC10 EXPERT.PAS. The packager verifies the pinned model hashes. To rerun host scoring, build EXPERT.PAS with FPC -B -dSPEC10 and pass score.py the native executable, the expanded SPEC10 directory and a general-model FLOPPY3 fixture. Run verify.py to check the target transcripts and archive.

The TP7 no-FPU smoke switched from Word Bench to Synonyms for the same adjective. It answered “Very fast.” then “swift” and finished with 45,528 bytes of free heap. The complete DOSBox-X FPU-on replay covers all 32 evaluation prompts, eight paired definition/substitution requests and two clarification cases. Physical Pocket386 testing remains pending. [DOS replay](ALL.LOG) · [No-FPU smoke](NOFPU.LOG)
