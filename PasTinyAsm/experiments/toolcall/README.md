# Tool selection benchmark and plan

One Tiny model chooses a single code for nine sound and text commands. It was fine-tuned from original TINY.BIN for 400 steps using 8,000 generated requests. Both paths were scored on the same held-out generator prompts after excluding exact training matches and requests containing the editor's “and” separator.

| Native Pascal path | Sound operation | Text operation | Batch elapsed |
| --- | ---: | ---: | ---: |
| Current MAKECOM | 292/300 | 291/296 | 4.51 s |
| Tiny selector | 269/300 | 294/296 | 4.17 s |

The score checks the operation only. MAKECOM also generates and validates arguments and writes its output files. The selector emits only an ID, so batch timings measure different amounts of work. On eight hand-written out-of-scope requests it emitted a valid tool ID every time, including SCALE for “list files in this directory.” The prototype has no rejection class. There is no DOS timing or memory measurement for the prototype.

## What to borrow from ClawDOS

ClawDOS exposes 18 local tools to a remote Claude model. The closest fit here is read-only inspection, such as system info and project file listing, reading and searching. Keep PC speaker and text output in the existing Pascal calls. File writes and program execution can use the editor's existing explicit save and run controls. Notes, raw memory and I/O port access are outside the first milestone. [ClawDOS tool list](https://ricapar.net/ClawDOS/)

## Build order

1. Keep sound lookup as the baseline and train one selector with an explicit ASK class. Include ambiguous requests, unsupported queries and quoted text containing tool words. Compare against word rules on a split that holds out entire templates.
2. Add a preview path using existing argument slots and compiler checks. Score correct operation and arguments, wrong accepted calls and clarification separately. For text, verify the whole requested phrase. For inspection, use Pascal to fetch live data.
3. Test in DOS with a single resident model and measure heap, cold loads, swaps and end-to-end latency. Consider a family-specific selector only if its measured error reduction pays for its extra pass.

From PasTinyAsm, generate training JSONL with `python3 experiments/toolcall/bench.py`. Use WebTiny revision `a1a36720ed558d6998e5beed9d4dbdd792626056` and its trainer with `--init ../TINY.BIN --steps 400 --batch-size 16 --threads 1`. Compile `experiments/classic/check.pas` and `MAKECOM.PAS` with FPC TP mode and optimization. Run `python3 experiments/toolcall/bench.py --score /absolute/path/to/check experiments/toolcall/SELECT.BIN` or `--editor /absolute/path/to/MAKECOM`. Keep the packaged runtime assets beside the editor executable.

## Clarification and text argument follow-up

The ASK variant adds 1,020 examples from 170 templated negatives. Twenty hand-written clarification probes were excluded from training. ASK scored 5/20 on them. The original selector asked on 0/20. On the same in-scope prompts the ASK variant selected 257/300 sound operations and 282/296 text operations correctly.

The text preview extracts full strings and numbers using narrow phrase-boundary rules. These rules explicitly cover the held-out generator's phrasing families, so the full-call results measure the value of deterministic extraction and the incremental effect of neural selection on these forms. They do not measure generalization of the parser to new templates. Preview never dispatches. The ASK variant preview scored 271/296 with 25 clarifications and zero wrong calls. The original selector with the same preview scored 283/296 with 13 clarifications and zero wrong calls. MAKECOM produced 110 exact and 186 wrong full calls on these prompts. The experiment supports testing direct text parsing on independently authored requests before adding another model pass.

Reproduce the ASK model using the same trainer settings above and generate the corpus with `bench.py --ask`. Score with `bench.py --ask --score CHECK ASK.BIN`.
