' E1.BAS, written by PasTinyAsm EXPORT from E1.SRC.
' Run with QBasic: QBASIC /RUN E1
DEFLNG A-Z
FOR R0 = 1 TO 2
  ' FOR I=1 TO 5:OUT I*I:NEXT
  FOR I = 1 TO 5
    PRINT LTRIM$(STR$(I * I))
  NEXT I
  ' LET S=0:FOR I=1 TO 100:LET S=S+I:NEXT:OUT S
  S = 0
  FOR I = 1 TO 100
    S = S + I
  NEXT I
  PRINT LTRIM$(STR$(S))
  ' LET X=2+3*4:OUT X:LET Y=X*X/7-1:OUT Y
  X = 2 + 3 * 4
  PRINT LTRIM$(STR$(X))
  Y = X * X \ 7 - 1
  PRINT LTRIM$(STR$(Y))
  ' LET A=3:LET B=5:OUT A-B:IF A-B>60000:ECHO wrapped:END
  A = 3
  B = 5
  PRINT LTRIM$(STR$(A - B))
  IF A - B > 60000 THEN
    PRINT "wrapped"
  END IF
  FOR T1 = 1 TO 2
    FOR X = 3 TO 1 STEP -1
      ' NUMBER X:PRINT  and
      PRINT LTRIM$(STR$(X));
      PRINT "and";
    NEXT X
    PRINT
  NEXT T1
  IF X = 0 THEN
    PRINT "it's zero"
  ELSE
    PRINT "not zero"
  END IF
  PRINT "Bye, now: done";
NEXT R0
END
