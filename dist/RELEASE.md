Ready-to-run packages built from `main`. Each DOS package is self-contained: unzip into an empty directory and run.

| File | What it is | Needs |
|---|---|---|
| `TP7TINY.ZIP` | PasTiny, the original chat program, Turbo Pascal 7 real-mode build | DOS, a 386; no coprocessor needed |
| `TINYPAS.ZIP` | PasTiny, Free Pascal protected-mode build, with `CWSDPMI.EXE` | DOS, a 386 |
| `PASASM.ZIP` | PasTinyAsm, the default edition: say what a small DOS program should do and get a `.COM` | DOS, a 386, an XMS driver (HIMEM.SYS) |
| `PASRES.ZIP` | PasTinyAsm, the resident edition for machines without XMS | DOS, a 386, about 590 KB of free conventional memory, a colour card |
| `SPEC100.ZIP` | PasTinyMoE: 100 specialist models and a router; run `EXPERT` and ask in `AUTO` | DOS, a 386, an XMS driver, about 39 MB of disk |
| `DELPHI1.ZIP` | PasTiny for Windows 3.1: `TINY.EXE` built with Delphi 1, its source and `TINY.BIN` | Windows 3.1 or 3.11; **not yet run there** |

Notes

- `DELPHI1.ZIP` now holds a compiled `TINY.EXE` (50,432 bytes), built with the Delphi 1 command-line compiler (`DCC /B TINY.DPR`, Delphi Compiler Version 8.0) after five source fixes. It compiles and links without errors, but it has not been run under Windows 3.1, so treat it as untested.
- `PASASM.ZIP` and `PASRES.ZIP` include the six experts, the two-kilobyte router, the exporter and the world builder. Both were unpacked into empty directories and run under DOSBox-X.
- `SPEC100.ZIP` was unpacked into an empty directory and its own check file (`CHECK.BAT`) run under DOSBox-X.
- Everything was tested in an emulator. Nothing here was run on a physical 386.
