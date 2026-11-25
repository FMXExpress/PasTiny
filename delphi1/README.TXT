TINY 2.1 for Delphi 1 - a neural network that answers questions, for Windows 3.1
================================================================================

A port of TINY 2.1 for DOS (Turbo C 2.0) by WollyMonjac
(https://github.com/WollyMonjac/Tiny-2.1) to Delphi 1 / Windows 3.1.
Same network file (TINY.BIN), same answers, same neon interface, neural
monitor and PC-speaker robot voice - in a window instead of a DOS screen.

Files
  TINY.DPR     the program (options, /BENCH, /IN= file mode)
  TNYNET.PAS   the neural network: loading TINY.BIN, integer and float engines
  TNYWIN.PAS   Windows side: 80x25 text window, keys, timer, PC speaker
  TNYUI.PAS    the interface: boot screen, chat, monitor, voice, demo
  ..\TINY.BIN  the trained network: copy it from the repository root so it
               sits next to TINY.EXE
  TESTS\       QUESTION.TXT (60 test questions), TINYHOST.PAS (test driver
               for Free Pascal on a modern PC)

Building with Delphi 1
  IDE:          File / Open Project / TINY.DPR, then Project / Build All.
                The project has no forms; that is intended.
  Command line: DCC TINY.DPR
  The result is TINY.EXE. Copy TINY.EXE and ..\TINY.BIN into one directory.

  No VCL, no .DFM or .RES files: only System, WinTypes and WinProcs, plus
  MMSYSTEM.DLL (Windows 3.1) for the millisecond timer. The EXE is small.

  Command line, building every unit: DCC /B TINY.DPR

Running
  Windows 3.1 or 3.11 (also Windows 95/98). Double-click TINY.EXE, or
  File / Run in Program Manager with options:

  TINY 0        always the surest answer (best for quizzes and sums)
  TINY 5        the default: answers are worded differently each time
  TINY 9        the most varied (and makes more mistakes)
  TINY /DEMO    TINY asks itself sample questions - press a key to take over
  TINY /QUIET   no sound
  TINY /MONO    grey colours
  TINY /CLASSIC standard DOS colours instead of the neon palette
  TINY /FLOAT   the original floating point engine (for comparison)
  TINY /BENCH   speed test: 5 questions, prints letters per second;
                results are also saved in BENCH.TXT
  TINY 0 /IN=QUESTION.TXT /OUT=ANSWERS.TXT
                answer every line of a text file (Windows has no
                "TINY < file" redirection; this replaces it)
  TINY /DUMP    test mode, writes BOOT.DMP, SCREEN.DMP and SOUND.LOG
                (same format as the DOS version's /DUMP)

  Keys: F1 help, F2 sound on/off, F3 voice on/off, F4 creativity,
        Up arrow = last question, Esc = quit.  Words: HELP, CLS, QUIT.

  The window picks the biggest "Terminal" font that fits the screen. On a
  640 x 480 screen it opens maximised.

Speed
  The default integer engine works in whole numbers only: the heavy
  work (about 350,000 multiply-adds per letter) is 8-bit x 16-bit
  integer arithmetic in 8086 assembler, and everything between is 32-bit
  whole numbers, as in the DOS version. While it thinks, and while the
  monitor is drawn, no coprocessor and no emulator (WIN87EM.DLL) is used.
  /FLOAT still runs the original floating point engine. Run TINY /BENCH
  to see the speed of your machine; it also says whether a coprocessor
  was found.

  Windows 3.1 multitasks cooperatively: TINY lets other programs run after
  every letter, and closing the window stops it at once.

Sound
  The PC speaker is driven directly (ports 42h, 43h, 61h), like the DOS
  version. This works in Windows 3.1 and Windows 95/98. Windows NT, 2000
  and XP block it: use /QUIET there.

What was tested (on a modern Linux PC, as Delphi 1 was not available)
  - TNYNET.PAS compiled with Free Pascal in Turbo Pascal mode (16-bit
    Integer) with range and overflow checks: all 60 test questions give
    exactly the same answers as the original C program, for both the
    integer engine and the float engine (creativity 0).
  - (Before the integer engine was made whole-number only, and not
    repeated since:) the whole program compiled for 16-bit Windows (Win16, large model)
    with Free Pascal's i8086 compiler, including the 8086 assembler
    kernels; the generated code assembles without errors.
  - Built with Delphi 1: the command-line compiler (DCC, Delphi Compiler
    Version 8.0) compiles and links the whole program without errors
    under a DOS emulator; TINY.EXE comes to 57,088 bytes.
  - Not tested: running TINY.EXE under Windows 3.1.

  Floating point on a real 386/486 rounds slightly differently from a
  modern PC, so in rare cases a letter can differ from the DOS version.

Licence
  The original TINY repository has no licence file. TINY.BIN and the
  design belong to its author: ask before publishing this port.
