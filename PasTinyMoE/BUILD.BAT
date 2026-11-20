@echo off
TPC /B /DSPEC40 EXPERT.PAS > SPEC40.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC40.EXE
TPC /B /DSPEC30 EXPERT.PAS > SPEC30.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC30.EXE
TPC /B /DSPEC20 EXPERT.PAS > SPEC20.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC20.EXE
TPC /B /DSPEC10 EXPERT.PAS > SPEC10.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC10.EXE
TPC /B /DSPEC9 EXPERT.PAS > SPEC9.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC9.EXE
TPC /B /DSPEC8 EXPERT.PAS > SPEC8.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC8.EXE
TPC /B /DSPEC5 EXPERT.PAS > SPEC5.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC5.EXE
TPC /B /DSPEC4 EXPERT.PAS > SPEC4.LOG
if errorlevel 1 goto fail
copy EXPERT.EXE SPEC4.EXE
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
