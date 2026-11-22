program E4;
(* E4.PAS, written by PasTinyAsm EXPORT from E4.SRC.
   Compile with Turbo Pascal 7: TPC E4 *)
{$R-,Q-}
uses Crt;

(* Flash the screen N times, keeping what is on it. *)
procedure Flash(N: Word);
var I, J: Word;
begin
  for I := 1 to N * 2 do begin
    for J := 0 to 1999 do Mem[$B800:J * 2 + 1] := Mem[$B800:J * 2 + 1] xor $7F;
    Delay(120)
  end
end;

(* Paint the whole screen background in colour N, with bright white text. *)
procedure Paint(N: Word);
var J: Word;
begin
  for J := 0 to 1999 do Mem[$B800:J * 2 + 1] := (N shl 4) or 15
end;

(* Change the colour of all text on the screen to N. *)
procedure Ink(N: Word);
var J: Word;
begin
  for J := 0 to 1999 do Mem[$B800:J * 2 + 1] := (Mem[$B800:J * 2 + 1] and $F0) or N
end;

procedure Border(N: Word); assembler;
asm
  mov ah,0Bh
  mov bh,0
  mov bl,byte ptr N
  int 10h
end;

(* $2000 hides the cursor, $0607 shows it. *)
procedure Cursor(Shape: Word); assembler;
asm
  mov ah,1
  mov cx,Shape
  int 10h
end;

begin
  (* write through DOS, so that text keeps the colours on the screen *)
  Assign(Output, ''); Rewrite(Output);
  ClrScr;
  Paint(1);
  Ink(14);
  Border(2);
  GotoXY(5, 3);
  Write('hi there');
  Cursor($2000);
  Cursor($0607);
  Flash(1);
end.
