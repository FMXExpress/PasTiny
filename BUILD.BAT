@echo off
rem Put TPC.EXE or BPC.EXE on PATH. No Crt unit is used.
rem BUILD       : Turbo Pascal 7 real mode
rem BUILD BP    : Borland Pascal 7 real mode
rem BUILD DPMI  : Borland Pascal 7 protected mode (RTM required at runtime)
rem BUILD FLOAT : Turbo Pascal float engine
rem BUILD NOASM : Turbo Pascal pure Pascal integer engine
if "%1"=="BP" goto bp
if "%1"=="DPMI" goto dpmi
if "%1"=="FLOAT" goto flt
if "%1"=="NOASM" goto noasm
TPC /B TINY.PAS
goto end
:bp
BPC /B TINY.PAS
goto end
:dpmi
BPC /B /CP TINY.PAS
goto end
:flt
TPC /B /DFLOATMATH TINY.PAS
goto end
:noasm
TPC /B /DNOASM TINY.PAS
:end
