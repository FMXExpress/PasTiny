@echo off
rem Turbo Pascal 7 real-mode builds.  Needs TPC.EXE and TURBO.TPL on the path.
TPC /B /DNOASM JEV.PAS > NOASM.LOG
if errorlevel 1 goto fail
copy JEV.EXE JEVNO.EXE
TPC /B /DFLOATMATH JEV.PAS > FLOAT.LOG
if errorlevel 1 goto fail
copy JEV.EXE JEVFLT.EXE
TPC /B JEV.PAS > INTEGER.LOG
if errorlevel 1 goto fail
goto end
:fail
echo Build failed. See compiler log.
:end
