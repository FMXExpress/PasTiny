PasTiny controlled DOS comparison - 2026-11-17
==============================================

Environment: DOSBox-X 2025.02.01, normal CPU core, cputype=386,
cycles=50000 (fixed), memsize=16 MB. One emulator process at a time.
All programs run as EXE 0 /P, redirected from the same DOS CRLF input.
BMRUN.EXE uses BIOS ticks + PIT to time the entire child execution at
millisecond resolution. Model load, process startup and answer output
are INCLUDED. Each output is checked for exact expected answers and
successful exit before its timing is included. The original C EXE has
no /BENCH mode, so this shared external timing avoids mixing different
benchmark implementations or relying on rounded per-question timing.

These are controlled emulator comparisons, not physical Pocket386
measurements. DOSBox cycles are not a calibrated CPU MHz setting.
Do not directly compare these values with earlier 8000-cycle or
cycles=max results. Compiler and runtime differences are included.

FPU ENABLED: five questions, 189 processed character tokens, three runs.
Median whole-program seconds, median seconds per answer, tokens/second:
FPC integer                 13.094     2.619    14.434  range 13.043-13.095
TP7 integer ASM             15.283     3.057    12.367  range 15.274-15.329
FPC float                   23.491     4.698     8.046  range 23.488-23.547
Original C                  45.319     9.064     4.170  range 45.316-45.319
TP7 integer Pascal          48.139     9.628     3.926  range 48.137-48.193
TP7 float                   53.640    10.728     3.523  range 53.585-53.644

FPU DISABLED: one question (what is 7 times 8), 34 processed character
tokens, one run per version. Each must answer: 7 times 8 is 56.
This shorter workload keeps the software-float comparisons practical.
Whole-program seconds and tokens/second:
TP7 integer ASM             17.469     1.946
TP7 integer Pascal          23.436     1.451
Original C                 245.990     0.138
TP7 float                  274.446     0.124

FPC go32v2 no-FPU results are omitted: its stock Emu387 support failed
an independent minimal math test in this emulator configuration. Wrong
or missing answers cannot be ranked as fast benchmark results.

Turbo Pascal uses its built-in N+/E+ software floating point with the
FPU disabled. Its integer ASM variant still has float normalization,
quantization, scale and residual operations. Software floating point
provides compatibility; replacing most arithmetic with integer work
and using the BASM dot product are separate performance changes.
Physical no-FPU Pocket386 and Pentium testing is still outstanding.

FPU-enabled questions:
what is the capital of peru
is a whale a fish
what is 7 times 8
which countries border estonia
spell elephant

Version provenance: https://github.com/FMXExpress/PasTiny at
87bfde55b18f24e94a6f59eebdcce7e75d581c6d; original C EXE from upstream
WollyMonjac/Tiny-2.1 revision 1d5cf54677addf188a090ca1c91acb3d02989a1d.
The CSV and META.JSN record individual executable checksums and raw
elapsed milliseconds. No compiler executables or libraries are included.
