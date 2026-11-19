# SPEC8 word desk

[Download SPEC8.ZIP](../../dist/SPEC8.ZIP), extract it into its own DOS directory on an SD card and run EXPERT. LIST shows eight trained models. USE 42, USE 43 and USE 44 pin the new specialists. AUTO can route from the word in the question. CHECK.BAT exercises all three. SPEC8 stores 3,054,464 bytes of weights and loads one complete model at a time.

| Catalog ID | Expert | Syllabus | Exact answers on 18 probes |
|---|---|---|---:|
| 042 | Spelling Helper | Correct recieve, seperate, definately, untill, freind and becuase | 10 |
| 043 | Confused Words | Common senses of affect/effect, stationary/stationery and complement/compliment | 17 |
| 044 | Grammar Terms | Define noun, verb, adjective, adverb, pronoun and conjunction | 9 |

Each score was identical under pinned and automatic selection. The original general model scored zero exact on each set. Each specialist had six target items, 12 probes using two withheld question patterns and six individually written probes. The data contains templated repetitions of the same items, so these results measure phrasing within the specified vocabulary. They do not establish general spelling correction or broad grammar knowledge. Examples of substantive errors include generating “frive” for “recieve” and giving the definition of “complement” for “compliment.” The exact outputs are available in [results.jsonl](results.jsonl).

## Router and verification

The three new entries use a generated, sorted headword-to-expert dictionary compiled into the SPEC8 build. It derives headwords from the labeled training rows; existing hardware-state commands and earlier topic rules remain active. A question matching multiple experts requests clarification. Unknown spellings outside the six named forms can require manual selection. The dictionary routes 54/54 of the new probes correctly. It saw all their headwords during training. This is a small dictionary benchmark; it does not evaluate a statistical intent classifier.

The host replay reproduced 117 prior routing and answer outcomes across the earlier experts. In the no-FPU DOSBox-X run the executable loaded all three new models in succession and answered “receive”, “Writing materials.” and “Expresses an action or state.” Free heap and largest block were 46,152 bytes before and after this sequence. The physical Pocket386 has not been measured. [No-FPU smoke](NOFPU.LOG)

## Reproduction

From PasTinyMoE, set WEBTINY to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056. Each export starts independently from TINY.BIN with the same trainer, seed 42 and CPU PyTorch 2.15. Each development set has 54 fitting rows and six internal validation rows. All training and evaluation questions are checked in.

```sh
python specialists/worddesk/data.py
for name in SPELL CONFUSE GRAMMAR; do
  python "$WEBTINY/training/train.py" --init TINY.BIN \
    --data "specialists/worddesk/$name-train.jsonl" --steps 600 \
    --batch-size 10 --threads 2 --lr .00035 --out "build/worddesk/$name.BIN"
done
python specialists/worddesk/index.py
python specialists/worddesk/build.py build/SPEC8
```

The packager checks the committed model files against their manifest hashes. BUILD.BAT uses Borland TP7 with /DSPEC8 for the target executable; TOPICS.INC must be alongside the Pascal sources. For host scoring compile EXPERT.PAS with FPC using -B -dSPEC8, then pass its executable, the expanded SPEC8 directory and the expanded FLOPPY3 general-model fixture to score.py.

The TP7 FPU-on replay matched all 54 host outputs and requested clarification for a mixed-domain query. Run verify.py to check the saved transcripts and archive. [DOS transcript](ALL.LOG)
