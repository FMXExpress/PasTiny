TINY 2.1P - Pascal port of TINY 2.1
=================================

Upstream: https://github.com/WollyMonjac/Tiny-2.1
Reference commit: 1d5cf54677addf188a090ca1c91acb3d02989a1d
The original TINY.C and unchanged TINY.BIN are retained. The network has
4 layers, width 96, hidden width 256, 4 attention heads, 97 tokens and a
128-letter context. It knows its training facts; it can invent wrong answers.

Files
-----
TINY.PAS     options, plain mode, benchmark and DOS interface entry point
TNYUI.INC    full DOS interface included by TINY.PAS (keep it beside the source)
TNYNET.PAS   checked model loader, integer and float transformer engines
TNYSYS.PAS   screen shadow buffer, BIOS keyboard/video, PIT timer and speaker
BUILD.BAT    TP7 / BP7 real-mode and BP7 protected-mode build commands
BUILDFPC.BAT native Free Pascal DOS build
Makefile     host, float, debug, DOS and test targets
TINY.C       unchanged C reference implementation
TINY.EXE     original upstream Turbo C executable (NOT the Pascal build)
TINY.BIN     unchanged upstream model

In the delivered archive, BIN/DOS/TINY.EXE is the new Pascal integer build,
BIN/DOS/TNYFLT.EXE is the Pascal float comparison build, and BIN/LINUX/TINY
is the x86-64 Linux host integer build. Do not confuse the original root
TINY.EXE with BIN/DOS/TINY.EXE. Run either from a directory containing TINY.BIN.

Builds
------
HOST: Free Pascal 3.2.2 on Linux or Windows; native, plain mode only.
  make host
  make float
  make debug
  make test
  ./build/int/TINY 0 /P
  ./build/int/TINY /BENCH

FAST: Free Pascal 3.2.2, i386 go32v2, 386 instruction set, 32-bit DOS DPMI.
  BUILDFPC
  BUILDFPC -dFLOATMATH
or with an installed Linux cross compiler and go32v2 RTL:
  make go32v2 FPC=ppcross386
  make go32v2-float FPC=ppcross386
The verified CPU flag is -Cp80386. The plan's -Cp386 is rejected by FPC 3.2.2.
The tested cross build uses the internal linker; external DJGPP binutils
are not needed for this Pascal program. All compiler units are rebuilt (-B)
so FLOATMATH, DEBUG and NOASM cannot silently reuse incompatible unit files.

CLASSIC: Turbo Pascal 7 / Borland Pascal 7, commercial tools supplied by you.
  BUILD         Turbo Pascal real mode
  BUILD BP      Borland Pascal real mode
  BUILD DPMI    Borland Pascal 16-bit protected mode (/CP)
  BUILD FLOAT   Turbo Pascal float engine
  BUILD NOASM   Turbo Pascal pure Pascal integer kernel
Put TPC.EXE or BPC.EXE on PATH. BP7 protected mode also needs RTM.EXE and
DPMI16BI.OVL. No Crt unit is used, avoiding the TP7 runtime error 200 startup
problem. Source uses TP syntax, ShortString, small heap blocks and an 8086
BASM dot product for TP7; FPC uses Pascal integer loops. Commercial TP7/BP7
and 16-bit FPC builds have NOT been run, so their compatibility is provisional.

Runtime and memory
------------------
Keep the unchanged TINY.BIN beside the program (model path is the current
working directory). FAST needs a DPMI host: CWSDPMI.EXE is included in BIN/DOS.
CWSDPMI release 7 is unmodified. You are entitled to its source and binary
updates: https://sandmann.dotster.com/cwsdpmi/ . See CWSDPMI.TXT.

The FPC Emu387 unit is linked for machines without a coprocessor. Its runtime
file is WMEMU387.DXE, supplied by the FPC DOS distribution and included in
BIN/DOS. Source/distribution: https://www.freepascal.org/ and
https://downloads.freepascal.org/fpc/dist/3.2.2/i386-go32v2/dos322full.zip .
See COPYDJ.TXT and COPYFPC.TXT for runtime terms. Do not interpret inclusion
of this file as a completed no-FPU acceptance test; see the limitation below.

Real-mode memory is expected to be in the original's roughly 540 KB class;
the actual Pascal real-mode footprint has not been measured. Protected-mode
builds place the network in extended memory. The supplied binary has been
tested with 16 MB in DOSBox-X; the suggested 2 MB minimum is not verified.

Integer math
------------
Default: int8 weights times int16 activations with Longint accumulators,
integer attention reductions and a 1536-entry exponential lookup table.
Quantisation uses half-away-from-zero rounding. Norm, residuals, vector
scales and attention score scaling remain Single. FLOATMATH selects the
original all-float engine. Important C float rounding points are stored
explicitly to Single, including intermediate products on x87 targets.

NOASM disables the CLASSIC BASM dot product. FAST/HOST always use Pascal
loops; no unmeasured assembly optimization is enabled there. No fixed-point
residual 'stage D' was implemented: no valid no-FPU profile is available to
justify and validate that further algorithm change.

Options and interaction
-----------------------
0..9      creativity (default 5; 0 is deterministic argmax)
/P        plain text; also automatic if stdin or stdout is redirected
/BENCH    plain, silent, creativity 0; fixed five questions; reports load
          time, question+separator+answer tokens, seconds, tokens/second,
          seconds/answer, engine, kernel, build and FPU status
/DEMO     DOS demonstration
/QUIET    speaker off
/MONO     monochrome attributes
/CLASSIC  original text palette (no neon DAC palette)
/DUMP     four demo turns, BOOT.DMP, SCREEN.DMP and SOUND.LOG, then exit
/DUMPALL  all twelve demo turns and the same dumps
Slash and dash forms are accepted. Optional /PROFILE is not implemented.

DOS keys: F1 help, F2 sound, F3 robot voice, F4 creativity, Up last question,
Backspace edit, Esc quit. HELP and CLS work in the DOS chat. QUIT and EXIT
stop either interface. The PC speaker voice uses the original letter sounds.
HOST intentionally has no full-screen interface or speaker.

/BENCH times are wall clock. HOST uses the system millisecond timer; DOS
combines BIOS ticks and the PIT with tick-change retry. NowUs is a signed
modular 32-bit microsecond count; benchmark intervals use NowMs. FPC FPU
status is reported as 'unknown'; TP7 uses Test8087. Throughput on an emulator
with cycles=max is not a Pocket386 speed prediction.

Validation (2026-11-16)
-----------------------
See REPORT.TXT and tests/evidence files for measured results and limitations.
The unmodified C reference and the Appendix A integer C prototype give
identical transcripts on all 60 questions. Both Pascal engines match 60/60
on HOST. Debug range/overflow, NOASM and creativity 5/9 checks pass.
Empty, bad-magic, short-header, truncated, extra-byte and bad-dimension files
produce the same status 1 and messages as the C original.
The original Turbo C DOS EXE also matches all 60 C host answers.

Free Pascal go32v2 runs in DOSBox-X 2025.02.01. Both Pascal engines match
all 60 C host answers. Four-turn UI regression matches all non-time/version
cells in BOOT.DMP and SCREEN.DMP; deterministic sound events match after
excluding random boot settling/rain and normalizing scanner pitches.
Monochrome/quiet and all-demo/classic dump smoke checks also completed.
A scripted F1-F4, edit, HELP, CLS, Up and Esc session exited successfully.
See REPORT.TXT for the limits of these smoke checks.
See tests/verify_dos.py and tests/compare_dumps.py. To reproduce both DOS
engines and the original (after building both Pascal DOS engines):
  DOS_RUNTIME=/path/to/fpc/bin/go32v2 make test-dos

Known validation limits
-----------------------
No commercial TP7/BP7 compiler, 16-bit build, Pocket386, Pentium hardware,
Windows host build or manual visual session was tested here.

DOSBox-X 2025.02.01 with fpu=false is NOT a successful no-FPU test environment:
a minimal independent program using only the stock FPC Emu387 unit computes
2*3 as NaN, and the network then fails. Forcing SET 387=N did not fix it.
Inspection of this emulator version's core_normal/prefix_none.h shows that
its fpu=false ESC handlers skip the floating-point instructions. A working
coprocessor-exception/emulation environment or physical no-FPU machine is
still required. No no-FPU throughput or stage-D speedup is claimed.

Debian DOSBox 0.74-3 was also unsuitable here: long string output from even
a minimal independent 32-bit Pascal program was corrupted, and the DOS
compiler failed at startup. The same programs run correctly in DOSBox-X.
Use DOSBox-X for the documented regression results.

Upstream does not supply a project license. The Pascal port targets the FMXExpress/PasTiny repository. The repository MIT
license applies to its contributions, not to third-party upstream files.
Upstream files retain their provenance; no new license is asserted over them.
