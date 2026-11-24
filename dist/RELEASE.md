Ready-to-run packages built from `main`. Each DOS package is self-contained: unzip into an empty directory and run.

| File | What it is | Needs |
|---|---|---|
| `TP7TINY.ZIP` | PasTiny, the original chat program, Turbo Pascal 7 real-mode build | DOS, a 386; no coprocessor needed |
| `TINYPAS.ZIP` | PasTiny, Free Pascal protected-mode build, with `CWSDPMI.EXE` | DOS, a 386 |
| `PASASM.ZIP` | PasTinyAsm, the default edition: say what a small DOS program should do and get a `.COM` | DOS, a 386, an XMS driver (HIMEM.SYS) |
| `PASRES.ZIP` | PasTinyAsm, the resident edition for machines without XMS | DOS, a 386, about 590 KB of free conventional memory, a colour card |
| `DELPHI1.ZIP` | PasTiny for Windows 3.1, **source only**, with `TINY.BIN` | Delphi 1 to compile it |

Notes

- `DELPHI1.ZIP` has no compiled program. Open `TINY.DPR` in Delphi 1 and choose Project / Build All, or run `DCC TINY.DPR`; `README.TXT` inside has the details. It has not yet been built with Delphi 1 or run on Windows 3.1; it compiles for Win16 with Free Pascal's i8086 compiler, and its network unit gives the reference answers.
- `PASASM.ZIP` and `PASRES.ZIP` include the six experts, the two-kilobyte router, the exporter and the world builder. Both were unpacked into empty directories and run under DOSBox-X.
- Everything was tested in an emulator. Nothing here was run on a physical 386.
