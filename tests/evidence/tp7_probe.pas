program Probe;
{$N+}{$E+}
function SafeExp(X:Single):Single;
begin if X< -60.0 then SafeExp:=0 else SafeExp:=Exp(X) end;
var I:Integer; V:Single; Status:Word;
begin
 V:=1;
 for I:=1 to 24 do begin
  V:=SafeExp(V-1.0);
  asm fstsw Status end;
  WriteLn(I,' ',V:0:2,' ',Status)
 end
end.
