program E1;
(* E1.PAS, written by PasTinyAsm EXPORT from E1.SRC.
   Compile with Turbo Pascal 7: TPC E1 *)
{$R-,Q-}
uses Crt;
var A, B, I, S, X, Y, T1, R0: Word;

begin
  (* write through DOS, so that text keeps the colours on the screen *)
  Assign(Output, ''); Rewrite(Output);
  for R0 := 1 to 2 do begin
    (* FOR I=1 TO 5:OUT I*I:NEXT *)
    for I := 1 to 5 do begin
      WriteLn(Word(I * I));
    end;
    (* LET S=0:FOR I=1 TO 100:LET S=S+I:NEXT:OUT S *)
    S := 0;
    for I := 1 to 100 do begin
      S := S + I;
    end;
    WriteLn(S);
    (* LET X=2+3*4:OUT X:LET Y=X*X/7-1:OUT Y *)
    X := 2 + 3 * 4;
    WriteLn(X);
    Y := X * X div 7 - 1;
    WriteLn(Y);
    (* LET A=3:LET B=5:OUT A-B:IF A-B>60000:ECHO wrapped:END *)
    A := 3;
    B := 5;
    WriteLn(Word(A - B));
    if Word(A - B) > 60000 then begin
      WriteLn('wrapped');
    end;
    for T1 := 1 to 2 do begin
      for X := 3 downto 1 do begin
        (* NUMBER X:PRINT  and *)
        Write(X);
        Write('and');
      end;
      WriteLn;
    end;
    if X = 0 then begin
      WriteLn('it''s zero');
    end else begin
      WriteLn('not zero');
    end;
    Write('Bye, now: done');
  end;
end.
