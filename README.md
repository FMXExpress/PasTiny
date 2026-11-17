# PasTiny

A Pascal port of [TINY 2.1](https://github.com/WollyMonjac/Tiny-2.1), a small character-level question-answering transformer for DOS.

- Default integer inference engine; original float engine with `FLOATMATH`.
- DOS neon interface, neural monitor, PC-speaker voice, and plain text mode.
- Free Pascal native host and 32-bit DOS builds; TP7/BP7 build commands supplied.
- Unchanged upstream model and reference implementation retained for comparisons.

## Run on DOS

For a 386 without a coprocessor, use **[TP7TINY.ZIP](https://github.com/FMXExpress/PasTiny/raw/refs/heads/main/dist/TP7TINY.ZIP)**: the Turbo Pascal 7 real-mode build with built-in floating-point emulation. It has passed all 60 reference answers with the FPU enabled, plus the five-question benchmark with `fpu=false`. Physical Pocket386 hardware remains untested. No CWSDPMI or WMEMU387 file is needed for this build.

For the Free Pascal 32-bit DOS build, download [TINYPAS.ZIP](https://github.com/FMXExpress/PasTiny/raw/refs/heads/main/dist/TINYPAS.ZIP) and extract it into a DOS directory. The archive is flat and **every entry uses uppercase 8.3 filenames**. It includes the Pascal integer and float executables, unchanged model, runtime files, Pascal source, and build commands.

```dos
TINY 0
TINY 0 /P
TINY /BENCH > BENCH.TXT
```

Keep `TINY.BIN` in the working directory and `CWSDPMI.EXE` beside the DOS executable. `WMEMU387.DXE` is included for the linked Free Pascal emulator support. **FPC no-FPU operation and physical Pocket386 acceptance remain unverified**; see the test limitations below.

The repository root `TINY.EXE` is the original Turbo C reference executable. The new Pascal builds are [`BIN/DOS/TINY.EXE`](BIN/DOS/TINY.EXE) (integer) and [`BIN/DOS/TNYFLT.EXE`](BIN/DOS/TNYFLT.EXE) (float). `TINYPAS.ZIP` contains only the Pascal executables.

## Build and test on Linux

Install Free Pascal 3.2.2, GCC, Make, and Python 3:

```sh
make host
make test
./build/int/TINY 0 /P
./build/int/TINY /BENCH
```

A static x86-64 Linux build and model are also included in `BIN/LINUX`.

For native Free Pascal DOS builds, run `BUILDFPC.BAT`; for a configured go32v2 cross compiler, use `make go32v2` and `make go32v2-float`. The CPU flag is `-Cp80386`.

`BUILD.BAT` supplies Turbo Pascal 7 and Borland Pascal 7 real-mode and BP7 protected-mode commands. Keep `TNYUI.INC` with the Pascal units. Turbo Pascal 7 real mode is now verified; BP7 protected mode remains unverified. To reproduce the TP7 checks with your own compiler files:

```sh
TP7_DIR=/path/to/compiler/bin make test-tp7
```

## Validation and benchmarks

Both Pascal engines match **60/60 reference answers on Linux and DOSBox-X**. The actual Borland Turbo Pascal 7 real-mode integer and float builds also match 60/60; the classic integer ASM and NOASM variants are compared separately. Debug and NOASM host builds pass; malformed model errors match C. Screen dump comparisons pass outside the documented clock/speed/version cells, and 279 deterministic sound events match.

DOSBox-X 2025.02.01, normal core, emulated 386, 8,000 cycles, FPU enabled:

| Engine | Tokens/second | Average seconds/answer |
|---|---:|---:|
| Integer | 2.350 | 16.084 |
| Float | 1.297 | 29.142 |

Tokens are characters, including the question and separator. These are **FPU-enabled emulator results, not Pocket386 speed estimates**.

The TP7 real-mode integer build passes the five-question no-FPU benchmark (189 tokens, `FPU found: no`) using its built-in software floating point. This is an emulator test, not a physical Pocket386 timing prediction. No-FPU verification of the **FPC go32v2** build is still blocked: an independent program using stock FPC `Emu387` returned NaN with `fpu=false`. Physical Pocket386/Pentium, BP7 DPMI, 16-bit FPC, and Windows host builds remain unverified. See [REPORT.TXT](REPORT.TXT) for details, reproducible tests, and [test evidence](tests/evidence).

## Documentation and attribution

See [README.TXT](README.TXT) for options, keyboard controls, runtime requirements, and build details. The full source checkout also contains host tests and Git metadata with long filenames; the DOS distribution `TINYPAS.ZIP` uses 8.3 names throughout.

Based on TINY 2.1 revision `1d5cf54677addf188a090ca1c91acb3d02989a1d`. Upstream files retain their original attribution; [ORIGINAL.TXT](ORIGINAL.TXT) is its original documentation. This repository's MIT license covers its contributions and does not change the terms of upstream or third-party files. Upstream has no project license file; no additional rights over its model or C reference are asserted here. Runtime notices are in `BIN/DOS`.
