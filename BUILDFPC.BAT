@echo off
rem Install native Free Pascal 3.2.2 for DOS, put its BIN\GO32V2 on PATH.
rem Supply -dFLOATMATH as argument to select the float engine.
fpc -Tgo32v2 -Mtp -O3 -Cp80386 -XX -Xs -B %1 %2 TINY.PAS
