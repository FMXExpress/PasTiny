program RtProf;
{$N+}{$E+}
uses EXPCAT,TNYSYS;
const Q:array[1..4] of String[48]=('count the legs of an insect',
 'which operator gives the remainder','show files in this directory','unknown');
var I,J,K,Check:Integer; T:Longint;
begin
 if not ReadCatalog then Halt(1);
 for K:=1 to 3 do begin
  Check:=0; T:=NowMs;
  for I:=1 to 2000 do for J:=1 to 4 do Inc(Check,Route(Q[J]));
  WriteLn('calls=8000 ms=',NowMs-T,' checksum=',Check)
 end
end.
