@echo off
TPC /B /DSPEC3 EXPERT.PAS > SPEC3.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC3.EXE
TPC /B /DNOASM EXPERT.PAS > NOASM.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE EXPNO.EXE
TPC /B /DFLOATMATH EXPERT.PAS > FLOAT.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE EXPFLT.EXE
TPC /B /DDEBUG EXPERT.PAS > DEBUG.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE EXPDBG.EXE
TPC /B EXPERT.PAS > INTEGER.LOG
if errorlevel 1 goto fail
goto end
:fail
echo Build failed. See compiler log.
:end
