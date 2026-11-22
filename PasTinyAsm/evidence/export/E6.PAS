program E6;
(* E6.PAS, written by PasTinyAsm EXPORT from E6.SRC.
   Compile with Turbo Pascal 7: TPC E6 *)
{$R-,Q-}
uses Crt;
var A, B, K: Word;

(* Wait for a key and give its code, read through DOS. *)
function GetKey: Word; assembler;
asm
  mov ah,8
  int 21h
  xor ah,ah
end;

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
  ClrScr;
  Write('Calculator');
  WriteLn;
  repeat
    Write('first number: ');
    Ask(A);
    Write('second number: ');
    Ask(B);
    Write('a add, s subtract, m multiply, d divide, q quit: ');
    K := GetKey;
    WriteLn;
    if K = Ord('q') then begin
      Halt;
    end;
    if K = Ord('a') then begin
      WriteLn(Word(A + B));
    end;
    if K = Ord('m') then begin
      WriteLn(Word(A * B));
    end;
    if K = Ord('s') then begin
      if A < B then begin
        Write('-');
        WriteLn(Word(B - A));
      end else begin
        WriteLn(Word(A - B));
      end;
    end;
    if K = Ord('d') then begin
      if B = 0 then begin
        Write('cannot divide by zero');
        WriteLn;
      end else begin
        WriteLn(Word(A div B));
      end;
    end;
  until False;
end.
