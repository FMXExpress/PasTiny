program E2;
(* E2.PAS, written by PasTinyAsm EXPORT from E2.SRC.
   Compile with Turbo Pascal 7: TPC E2 *)
{$R-,Q-}
uses Crt;
var A, B, I, T1: Word;

(* Read a whole number, letter by letter through DOS, up to Enter, with
   the same DOS calls as the .COM file: what is typed is shown, and
   anything that is not a digit is passed over. *)
procedure Ask(var V: Word);
var C: Byte; N: Word;
begin
  Flush(Output); N := 0;
  repeat
    asm
      mov ah,1
      int 21h
      mov C,al
    end;
    if (C >= 48) and (C <= 57) then N := N * 10 + (C - 48)
  until (C = 13) or (C = 26);
  asm
    mov ah,2
    mov dl,10
    int 21h
  end;
  V := N
end;

begin
  (* write through DOS, so that text keeps the colours on the screen *)
  Assign(Output, ''); Rewrite(Output);
  (* INPUT A:INPUT B:OUT A+B:OUT A*B:OUT A-B:OUT A/B *)
  Ask(A);
  Ask(B);
  WriteLn(Word(A + B));
  WriteLn(Word(A * B));
  WriteLn(Word(A - B));
  WriteLn(Word(A div B));
  if Word(A * 2) > Word(B + 1) then begin
    WriteLn('first is big');
  end else begin
    WriteLn('first is small');
  end;
  (* TIMES B:PRINT x:END:NL *)
  for T1 := 1 to B do begin
    Write('x');
  end;
  WriteLn;
  (* FOR I=A DOWNTO B:NUMBER I:PRINT -:NEXT:NL *)
  for I := A downto B do begin
    Write(I);
    Write('-');
  end;
  WriteLn;
end.
