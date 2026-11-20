# PasTinyAsm

Say what a small DOS program should do, and get a `.COM` file that does it. It runs on a 386 in real mode and fits on one floppy: [dist/PASASM.ZIP](dist/PASASM.ZIP) unpacks to 1,188,069 bytes.

```
C:\ASM> MAKECOM
> make screen flash, play sound
1 make screen flash -> FLASH 3
2 play sound -> BEEP 440 300
wrote OUT.COM 123 bytes, OUT.ASM
> quit
C:\ASM> OUT
```

The models never write an instruction. A 380 KB network cannot be trusted to get machine code right, where one wrong character is a wrong program. So the work is shared:

| Step | Done by | What happens |
|---|---|---|
| Split | code | The request is cut into steps at commas, "and" and "then" |
| Route | code | Each step goes to one of three experts, by its words |
| Translate | model | The expert turns the step into one library call: `FLASH 3` |
| Check | code | Unknown call, number out of range, or numbers that do not match the request: refused, and nothing is written |
| Write | code | Load the arguments, call each routine, exit; then the routines that were used |

Three experts, each a 381,808-byte TINY 2.1 model trained from the general `TINY.BIN`:

| Expert | Calls |
|---|---|
| `SCREEN.BIN` | `CLS`, `FLASH n`, `COLOR n`, `INK n`, `BORDER n`, `GOTO row col`, `HIDE`, `SHOW` |
| `SOUND.BIN` | `BEEP hertz ms`, `SIREN n`, `SCALE`, `WAIT ms`, `KEY`, `REPEAT n` |
| `TEXT.BIN` | `PRINT text`, `NEWLINE`, `NUMBER n` |

The 16 routines are in [`LIB.ASM`](LIB.ASM), 401 bytes of 8086 code in all. `REPEAT n` is not a routine; it loops the whole program. A program holds only the routines it uses, so the example above is 123 bytes. Beside the `.COM` file the program writes a short `.ASM` listing of the main part.

Two kinds of step skip the model: a step that is already a call (`FLASH 3`), and a step with text in double quotes, which prints that text exactly (`print "Hello, World!"`).

## What was measured

**The writer is exact.** For requests written as calls, the `.COM` file is byte for byte what NASM makes from the program's own listing plus the routines in `LIB.ASM` (5 programs covering every call).

**The experts are exact on wordings they were trained on. On wordings they were not, the result depends on the wording, and adding wordings fixes only the ones added.** Each expert was scored in the 8-bit runtime on 300 fresh steps per set (new numbers, colours and texts every time):

| Expert | Trained wordings | First held-out set, after training on it | New held-out set: right | refused | wrong but accepted |
|---|---:|---:|---:|---:|---:|
| Screen | 300 of 300 | 300 of 300 | 291 | 0 | 9 |
| Sound | 300 of 300 | 300 of 300 | 207 | 20 | 73 |
| Text | 299 of 300 | 300 of 300 | 113 | 0 | 187 |
| All | 899 of 900 | 900 of 900 | 611 | 20 | 269 |

How this came about. The first version was trained on fixed phrases and scored 790 of 900 on a held-out set, with 108 valid calls for the wrong thing ("make the cursor invisible" gave `SHOW`). For this version those wordings went into training, the phrase lists became combinable patterns (about 4,800 distinct screen wordings where there were about 60), and a fresh held-out set was written. Every earlier failure is now right. The fresh set shows the same weakness again:

- **A wording is either always right or always wrong.** "take the cursor away" gives `SHOW` every time; "repeat the program 5 times" gives `SIREN 5` every time; "take a break for two seconds" gives a beep. Words the expert has never seen ("program", "break") are not understood from their meaning.
- **The text expert's low score has one cause.** It cannot tell wrapping words it has not met from the text itself: "display the phrase hello" prints "the phrase hello", "show me hello" prints "me hello". Quotes avoid this: `display the phrase "hello"`.
- **The numbers check helps where it applies.** The 20 refusals are wrong calls it caught.

So more wordings make the experts right on more phrasings, but do not make them understand new ones. The plan is printed before anything runs, so a wrong call is visible. [`training/gen_asm.py`](training/gen_asm.py) holds all the wordings; `tests/test_asm.py --models --show` lists the wrong calls.

**Under DOS.** `bin/MAKECOM.EXE` is the Turbo Pascal 7 build (40,432 bytes). In DOSBox-X with an emulated FPU it ran [`evidence/DEMO.IN`](evidence/DEMO.IN) ([`FPU.LOG`](evidence/FPU.LOG)) and the programs it wrote were then run:

| Program | Check | Result |
|---|---|---|
| `HELLO.COM` | printed text, a number, a quoted text, repeated twice | as expected ([`HELLO.OUT`](evidence/HELLO.OUT)) |
| `BLUE.COM` | colour of the top left cell afterwards | `1F`, white on blue |
| `WAIT2.COM` (`WAIT 2000`) | BIOS clock ticks before and after | 35 ticks, 1.92 seconds |
| `NOISE.COM` (`BEEP 880 500`, `SIREN 2`) | ticks | 41 ticks, 2.25 seconds for 2.1 seconds of sound |
| `ALL.COM` (12 steps, every screen call) | ends, prints its last line, cell colour | "all done", `4E`, yellow on red |
| `DEMO.COM` (flash and beep) | runs and returns to DOS | yes |
| `FIXED.COM` | four wordings the first version got wrong | planned correctly, as in `FPU.LOG` |

On an emulated 386 without an FPU, "make screen flash, play sound" gave the same 123-byte file ([`NOFPU.LOG`](evidence/NOFPU.LOG)) and it ran.

## Limits

- The flash and the sounds were not seen or heard: DOSBox-X ran without a display or sound device. What was checked is that the programs finish, take the right time and leave the right colours in screen memory. Nothing was run on real hardware.
- The screen routines write to colour text memory at `B800:0000` and assume 80 by 25. Delays use BIOS interrupt 15h function 86h (AT-class machines).
- Text without quotes is small letters and digits only, and a text with "and" or "then" in it is split into two steps. Use quotes.
- A step holds 72 characters and a program 40 steps.
- The numbers check only looks at numbers typed as digits. "beep for five seconds" is not checked against the 5.
- 16 routines is a toy library. There are no variables, tests or branches, so this writes sequences, not programs with logic.
- The router is a word list in `MAKECOM.PAS`, not a model.
- `bin/MAKECOM.EXE` was built with a Turbo Pascal 7 copy whose runtime differs slightly from the one used for the other executables in this repository.
- One training run per expert and version; the scores above are from those runs.
- The new held-out set was written by the same author as the training wordings, so it is easier than what a stranger would type.

## Build, test, train

```
python3 tools/buildlib.py                     LIB.ASM -> LIB.INC (needs NASM)
fpc -Mtp -B MAKECOM.PAS                       host build for testing
python3 tests/test_asm.py ./MAKECOM           writer against NASM
python3 tests/test_asm.py ./MAKECOM --models  plans, refusals and expert scores
TPC /B MAKECOM.PAS                            the DOS program (BUILD.BAT)
```

To retrain an expert (PyTorch, 35 to 55 minutes on one CPU core), then rewrite the catalog:

```
python3 training/train_asm.py screen ../PasTinyMoE/TINY.BIN SCREEN.BIN 6000
python3 tools/package.py
```

To add a routine: write it in `LIB.ASM` with its `;;` header line, run `tools/buildlib.py`, add wordings for it to `training/gen_asm.py` and words for it to the router in `MAKECOM.PAS`, and retrain that expert.

`TNYNET.PAS`, `TNYSYS.PAS` and `EXPCAT.PAS` are copies of the PasTinyMoE engine units. `tests/attr.asm` and `tests/ticks.asm` are the two helper programs used for the DOS checks.
