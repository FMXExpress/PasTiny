' E3.BAS, written by PasTinyAsm EXPORT from E3.SRC.
' Run with QBasic: QBASIC /RUN E3
DEFLNG A-Z
DO
  K = ASC(INPUT$(1))
  IF K = ASC("q") THEN
    PRINT "bye"
    END
  END IF
  ' OUT K:ECHO again
  PRINT LTRIM$(STR$(K))
  PRINT "again"
LOOP
END
