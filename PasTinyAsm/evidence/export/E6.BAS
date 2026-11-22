' E6.BAS, written by PasTinyAsm EXPORT from E6.SRC.
' Run with QBasic: QBASIC /RUN E6
DEFLNG A-Z
CLS
PRINT "Calculator";
PRINT
DO
  PRINT "first number: ";
  INPUT "", A
  PRINT "second number: ";
  INPUT "", B
  PRINT "a add, s subtract, m multiply, d divide, q quit: ";
  K = ASC(INPUT$(1))
  PRINT
  IF K = ASC("q") THEN
    END
  END IF
  IF K = ASC("a") THEN
    PRINT LTRIM$(STR$(A + B))
  END IF
  IF K = ASC("m") THEN
    PRINT LTRIM$(STR$(A * B))
  END IF
  IF K = ASC("s") THEN
    IF A < B THEN
      PRINT "-";
      PRINT LTRIM$(STR$(B - A))
    ELSE
      PRINT LTRIM$(STR$(A - B))
    END IF
  END IF
  IF K = ASC("d") THEN
    IF B = 0 THEN
      PRINT "cannot divide by zero";
      PRINT
    ELSE
      PRINT LTRIM$(STR$(A \ B))
    END IF
  END IF
LOOP
END
