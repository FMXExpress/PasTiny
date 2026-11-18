program RouteTest;
{$N+}{$E+}
uses EXPCAT,TNYSYS;
var J,K:Integer; Start,Total:Longint;
begin
 if not ReadCatalog then Halt(1);
 if (Route('unknown')<>1) or (Route('times capital')<>1) or
    (Route('capital of peru')<>2) or (Route('7 times 8')<>3) then Halt(2);
 for K:=1 to 3 do begin
  Total:=0; Start:=NowMs;
  for J:=1 to 30000 do Inc(Total,Route('what is the capital of peru'));
  WriteLn('entries=',Count,' queries=30000 ms=',NowMs-Start,' sum=',Total)
 end
end.
