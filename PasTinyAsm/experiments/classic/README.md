# Four small PasTinyAsm experiments

These are isolated prototypes tested against main at `6d72019`. The editor and distributed DOS package are unchanged.

| Experiment | Test | Result |
| --- | --- | --- |
| Contextual edits | Use the last instruction as the referent. Starting at COLOR 1, ask for the same but red, then do that twice. | Produced COLOR 1, COLOR 4, COLOR 4. MAKECOM loaded the resulting source and wrote EDIT.COM. Three unsupported or missing-reference cases were refused. “Make it louder” has no target in the current BEEP instruction. This tests one-line references only. |
| Table-driven adventure | Assemble the fixed DOS interpreter with 50 room records, two directed exits per room and one movable lamp. | DOSBox-X ran the 1,046-byte WORLD.COM. Taking the lamp in the first room failed, taking it in room 2 succeeded, inventory still contained it in room 50, and walking west returned to room 49. This bypasses the editor line budget. The interviewer does not yet generate the table. |
| Programming by example | Search by length over zero, one or two arithmetic operations on an unsigned word, with constants 1–9. Fit three input/output pairs per task. | Recovered doubling, adding seven and multiplying by three then adding two. All matched on inputs 0–50. MAKECOM compiled each source and DOS returned 22, 18 and 35 for input 11. A single example mapping 1 to 2 also fits adding one. There was no learned search ordering in this test. |
| Example-based translation | Draw 4,000 SOUND training examples with seed 11. Normalize quantities, retrieve by word-set Jaccard similarity, and transfer matched argument positions. Compare against SOUND.BIN on the same 300 held-out-template draws with seed 935. | Lookup 276/300, shipped Pascal integer expert 208/300. Both correct 208, lookup only 68, expert only 0, both missed 24. This is exact command equality on generated sound requests; the lookup gets the sound domain in advance, as does the expert. |

From PasTinyAsm, run the host checks with a fresh output directory:

```sh
mkdir -p build/classic
python3 experiments/classic/probes.py build/classic
fpc -Mtp -B -O2 -Fu. -FUbuild/classic -FEbuild/classic experiments/classic/check.pas
python3 experiments/classic/retrieval.py build/classic/check
as --32 -I build/classic experiments/classic/world.s -o build/classic/world.o
ld -m elf_i386 -Ttext 0x100 --oformat binary build/classic/world.o -o build/classic/WORLD.COM
```

In DOS, start WORLD.COM and enter lowercase commands: east, west, look, take lamp, inventory, quit. For the arithmetic programs, load P0.SRC, P1.SRC and P2.SRC in MAKECOM, then run the generated programs.

## Separate slots branch smoke test

Built the in-progress branch at `46cb305` with FPC, using the weights checked into that revision. For each of the branch's far-number and quoted-text generators, drew the first 30 prompts with seed 7 and replayed identical prompts with GUIDE OFF and GUIDE ON. Slots stayed enabled in both modes.

| Corpus | Guide | Exact | Refused | Wrong accepted |
| --- | --- | ---: | ---: | ---: |
| Far numbers | Off | 0 | 30 | 0 |
| Far numbers | On | 0 | 30 | 0 |
| Quoted text | Off | 0 | 28 | 2 |
| Quoted text | On | 0 | 26 | 4 |

The branch adds trainer and runtime changes but the diff contains no new task weights. These results describe that checkout, not a finished slot-trained expert. A useful next comparison holds slot-trained weights fixed and separately counts malformed programs, changed literal values, and valid programs with the wrong operation.
