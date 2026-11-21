program E2;
(* E2.PAS, written by PasTinyAsm EXPORT from E2.SRC.
   Compile with Turbo Pascal 7: TPC E2 *)
{$R-,Q-}
uses Crt;
var A, B, I, T1: Word;

(* Read a whole number; anything else counts as 0. *)
procedure Ask(var V: Word);
var S: String; L: Longint; Code: Integer;
begin
  ReadLn(S); Val(S, L, Code);
  if Code <> 0 then L := 0;
  V := L
end;

begin
  (* write and read through DOS, so that text keeps the colours on the screen *)
  Assign(Output, ''); Rewrite(Output); Assign(Input, ''); Reset(Input);
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
