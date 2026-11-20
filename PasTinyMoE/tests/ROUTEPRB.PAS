program RoutePrb;
(* Prints two expert ids per input line: the route by topic rules alone,
   then the route EXPERT uses (rules, then the typo fallback).  0 means
   "choose an expert".  Run in a directory holding EXPERTS.CAT. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$N+}{$E+}
uses TNYNET,EXPCAT,PILOTRT;
var Q:String; J:Integer;
begin
 if not ReadCatalog then Halt(1);
 while not Eof(Input) do begin
  ReadLn(Q); Q:=Clean(Q); J:=Route(Q);
  if J<>0 then J:=Items[J].Id;
  WriteLn(PilotDomain(Q),' ',J)
 end
end.
