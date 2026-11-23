# English game-rule fragments

Compare the shipped TASKS expert with the same weights fine-tuned on 24 English prompts for eight chess and Go fragments. The existing variable convention is part of the question or shared context. Eight alternate wordings were reserved for inference. This tests paraphrases of known fragments.

| Model | Exact PasTinyAsm source |
| --- | ---: |
| Shipped TASKS.BIN | 0/8 |
| Fine-tuned TASKS weights | 2/8 |

The fine-tuned model got the bishop's equal-gap test and the two-pass stop condition right. It omitted a closing END for the king test and produced unrelated or incorrect code for the remaining five. The benchmark invokes the native Pascal integer inference harness directly.

Training used WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056`, initialized from TASKS.BIN, with 250 steps, batch size 8 and one CPU thread. Convert corpus.tsv to JSONL by mapping the second and third tab-separated fields to question and answer. Train with `--init TASKS.BIN --steps 250 --batch-size 8 --threads 1 --out RULES.BIN`. Build experiments/classic/check.pas with FPC in TP mode and run `python3 experiments/gamerules/score.py /path/to/check TASKS.BIN RULES.BIN`.
