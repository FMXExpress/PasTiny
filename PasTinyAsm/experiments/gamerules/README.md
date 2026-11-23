# English game-rule fragments

Compare the shipped TASKS expert with the same weights fine-tuned on 24 English prompts for eight chess and Go fragments. The existing variable convention is part of the question or shared context. Eight alternate wordings were reserved for inference. This tests paraphrases of known fragments.

| Model | Exact PasTinyAsm source |
| --- | ---: |
| Shipped TASKS.BIN | 0/8 |
| Fine-tuned TASKS weights | 2/8 |

The fine-tuned model got the bishop's equal-gap test and the two-pass stop condition right. It omitted a closing END for the king test and produced unrelated or incorrect code for the remaining five. The benchmark invokes the native Pascal integer inference harness directly.

Training used WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056`, initialized from TASKS.BIN, with 250 steps, batch size 8 and one CPU thread. Convert corpus.tsv to JSONL by mapping the second and third tab-separated fields to question and answer. Train with `--init TASKS.BIN --steps 250 --batch-size 8 --threads 1 --out RULES.BIN`. Build experiments/classic/check.pas with FPC in TP mode and run `python3 experiments/gamerules/score.py /path/to/check TASKS.BIN RULES.BIN`.

## Typed rule selection in the Tab editor

[Download PASRULE.ZIP](../../dist/PASRULE.ZIP) for the experimental XMS editor with a seventh model, RULES.BIN. Press Enter on a request beginning with RULE, followed by one chess or Go rule. Tiny outputs a one-character ID. MAKECOM checks that the request names the corresponding subject and expands the ID to a compiler-checked statement before inserting it. It binds an explicit pass count from the request. The board variables follow fixed conventions: I and J are absolute move gaps, K is the chess legality flag, F is the Go pass count, P is the player, A is the board index, and E is the liberty flag. These checks cover the prototype's known shapes. They do not prove that a rule means the same thing as unrestricted English.

On eight held-out prompts entered via BIOS keyboard replay in the actual screen editor, four expanded exactly and four were refused. The accepted rules were straight rook movement, stop on two passes, clear a stone with no liberties, and place a stone. A separate replay compiled the two-pass rule into a DOS program. In DOSBox-X, the program continued at F=1 and halted at F=2.

The typed training corpus uses corpus.tsv with answer codes A–H in order: knight, king, bishop, rook, passes, turn, capture, place. Fine-tuning used the same settings above. Compile the editor with `TPC /B /DXMSSTREAM;GAMEARRAY;GAMERULES MAKECOM.PAS` and use the catalog from the archive, which assigns RULES.BIN expert ID 7.
