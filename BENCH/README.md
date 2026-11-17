# Controlled DOS benchmark comparison

The FPU-enabled and FPU-disabled runs use different workloads and are plotted separately. All executions returned the expected answers. See [README.TXT](README.TXT) for the complete methodology and results.

- [FPU enabled](FPUON.SVG): five questions, 189 character tokens, three runs per version, median elapsed time divided by five. The CSV includes observed minimum and maximum times; these are not confidence intervals.
- [FPU disabled](FPUOFF.SVG): one question, 34 character tokens, one run per version.
- [BENCH.CSV](BENCH.CSV): summarized timings, run counts, token counts, and executable SHA-256 checksums.
- [META.JSN](META.JSN): raw elapsed milliseconds and compiler/build provenance.
- [FPUON](FPUON) and [FPUOFF](FPUOFF): exact inputs, DOS batch commands, external timer output, and answer transcripts.
- [BMRUN.PAS](BMRUN.PAS): Turbo Pascal external timer; [BMRUN.EXE](BMRUN.EXE) is the compiled helper. No compiler executable or compiler library is included.

The external timer uses BIOS ticks and the PIT. Whole-process times include model loading, startup, and output. This gives the original C executable and Pascal builds the same measurement method; it does not mix their different internal timing implementations. These are emulator measurements, not Pocket386 hardware predictions.

## Regenerate charts

With Python 3 and Matplotlib installed, run from the repository root:

```sh
python3 BENCH/PLOT.PY
```

The script reads the existing CSV and writes `FPUON.SVG`, `FPUON.PNG`, `FPUOFF.SVG`, and `FPUOFF.PNG`. It does not run the benchmarks again. Axes start at zero, lower values are faster, colors identify the same versions across both charts, and each plot records its own workload and run count.

## Replay measurements

Obtain the versioned executables identified by the hashes in the CSV, plus the unchanged `TINY.BIN` from commit `87bfde55b18f24e94a6f59eebdcce7e75d581c6d`. Each batch file expects the copied executables to be named `ORIG.EXE`, `FPCI.EXE`, `FPCF.EXE`, `TPI.EXE`, `TPNO.EXE`, and `TPF.EXE` as applicable. FPC also needs its DOS runtime files beside it. Put `BMRUN.EXE` and the model in each input directory.

Mount `FPUON` in DOSBox-X using `ON.CON`, or `FPUOFF` using `OFF.CON`, and execute `RUNALL.BAT`. Run only one emulator at a time. Keep the supplied DOS CRLF input files. The original executable is the upstream Turbo C reference; the Pascal binaries come from `BIN/DOS` and `BIN/TP7` in that source commit.

FPC no-FPU timings are omitted because stock Emu387 failed an independent minimal math test in the tested emulator configuration. No speed ranking is assigned to incorrect or unsuccessful runs. Physical no-FPU Pocket386 testing remains outstanding.
