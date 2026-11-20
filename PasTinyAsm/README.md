# PasTinyAsm

Say what a small DOS program should do, and get a `.COM` file that does it. It runs on a 386 in real mode and fits on one floppy: [dist/PASASM.ZIP](dist/PASASM.ZIP) unpacks to 1,187,845 bytes.

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

**The experts are exact on wordings they were trained on, and wrong about one time in eight on wordings they were not.** Each was scored in the 8-bit runtime on 300 fresh steps in trained wordings (new numbers, colours and texts) and 300 in wordings held out of training:

| Expert | Trained wordings | New wordings: right | refused | wrong but accepted |
|---|---:|---:|---:|---:|
| Screen | 300 of 300 | 289 | 0 | 11 |
| Sound | 300 of 300 | 243 | 1 | 56 |
| Text | 300 of 300 | 258 | 1 | 41 |
| All | 900 of 900 | 790 | 2 | 108 |

The 108 are the real weakness: a valid call for the wrong thing, which the checker cannot catch. Examples: "make the cursor invisible" gave `SHOW`, "make an alarm sound" gave `BEEP 440 300`, "hold on for half a second" gave `BEEP 440 500`, and "display the text win file" printed "the text win file". The misses come from a few wordings each expert gets wrong every time, not from scattered slips. The plan is printed before anything runs, so the wrong call is visible; the cure is more wordings in [`training/gen_asm.py`](training/gen_asm.py).

**Under DOS.** `bin/MAKECOM.EXE` is the Turbo Pascal 7 build (40,208 bytes). In DOSBox-X with an emulated FPU it ran [`evidence/DEMO.IN`](evidence/DEMO.IN) ([`FPU.LOG`](evidence/FPU.LOG)) and the programs it wrote were then run:

| Program | Check | Result |
|---|---|---|
| `HELLO.COM` | printed text, a number, a quoted text, repeated twice | as expected ([`HELLO.OUT`](evidence/HELLO.OUT)) |
| `BLUE.COM` | colour of the top left cell afterwards | `1F`, white on blue |
| `WAIT2.COM` (`WAIT 2000`) | BIOS clock ticks before and after | 36 ticks, 1.98 seconds |
| `NOISE.COM` (`BEEP 880 500`, `SIREN 2`) | ticks | 41 ticks, 2.25 seconds for 2.1 seconds of sound |
| `ALL.COM` (12 steps, every screen call) | ends, prints its last line, cell colour | "all done", `4E`, yellow on red |
| `DEMO.COM` (flash and beep) | runs and returns to DOS | yes |

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
- One training run per expert; the scores above are from that run.

## Build, test, train

```
python3 tools/buildlib.py                     LIB.ASM -> LIB.INC (needs NASM)
fpc -Mtp -B MAKECOM.PAS                       host build for testing
python3 tests/test_asm.py ./MAKECOM           writer against NASM
python3 tests/test_asm.py ./MAKECOM --models  plans, refusals and expert scores
TPC /B MAKECOM.PAS                            the DOS program (BUILD.BAT)
```

To retrain an expert (PyTorch, about half an hour on one CPU core), then rewrite the catalog:

```
python3 training/train_asm.py screen ../PasTinyMoE/TINY.BIN SCREEN.BIN
python3 tools/package.py
```

To add a routine: write it in `LIB.ASM` with its `;;` header line, run `tools/buildlib.py`, add wordings for it to `training/gen_asm.py` and words for it to the router in `MAKECOM.PAS`, and retrain that expert.

`TNYNET.PAS`, `TNYSYS.PAS` and `EXPCAT.PAS` are copies of the PasTinyMoE engine units. `tests/attr.asm` and `tests/ticks.asm` are the two helper programs used for the DOS checks.
