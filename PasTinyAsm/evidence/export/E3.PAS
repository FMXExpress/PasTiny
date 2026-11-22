program E3;
(* E3.PAS, written by PasTinyAsm EXPORT from E3.SRC.
   Compile with Turbo Pascal 7: TPC E3 *)
{$R-,Q-}
uses Crt;
var K: Word;

(* Wait for a key and give its code, read through DOS. *)
function GetKey: Word; assembler;
asm
  mov ah,8
  int 21h
  xor ah,ah
end;

begin
  (* write through DOS, so that text keeps the colours on the screen *)
  Assign(Output, ''); Rewrite(Output);
  repeat
    K := GetKey;
    if K = Ord('q') then begin
      WriteLn('bye');
      Halt;
    end;
    (* OUT K:ECHO again *)
    WriteLn(K);
    WriteLn('again');
  until False;
end.
