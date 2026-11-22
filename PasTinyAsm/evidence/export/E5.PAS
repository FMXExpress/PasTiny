program E5;
(* E5.PAS, written by PasTinyAsm EXPORT from E5.SRC.
   Compile with Turbo Pascal 7: TPC E5 *)
{$R-,Q-}
uses Crt;

procedure Beep(Hz, Ms: Word);
begin
  if Hz >= 19 then begin Sound(Hz); Delay(Ms); NoSound end
end;

procedure Siren(N: Word);
var I, F: Word;
begin
  for I := 1 to N do begin
    F := 400;
    while F < 1200 do begin Sound(F); Delay(8); Inc(F, 16) end;
    while F > 400 do begin Sound(F); Delay(8); Dec(F, 16) end
  end;
  NoSound
end;

procedure Scale;
const Notes: array[1..8] of Word = (262, 294, 330, 349, 392, 440, 494, 523);
var I: Word;
begin
  for I := 1 to 8 do begin Sound(Notes[I]); Delay(200) end;
  NoSound
end;

begin
  (* write through DOS, so that text keeps the colours on the screen *)
  Assign(Output, ''); Rewrite(Output);
  (* BEEP 880 100:WAIT 500 *)
  Beep(880, 100);
  Delay(500);
  Beep(440, 300);
  Siren(1);
  Scale;
  WriteLn('sounds done');
end.
