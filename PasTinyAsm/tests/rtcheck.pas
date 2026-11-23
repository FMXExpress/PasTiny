program RTCHECK;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
(* RTCHECK ROUTER.BIN ROUTER.TXT: every line of the text is a class and a
   request; the router must give that class. *)
uses ROUTER;
const Names:array[0..5] of String[8]=('screen','sound','text','tasks','recipes','several');
var T:Text; L,C:String; K,Bad,N:Integer;
begin
 if not LoadRouter(ParamStr(1)) then begin WriteLn('cannot read ',ParamStr(1)); Halt(1) end;
 Assign(T,ParamStr(2)); Reset(T); Bad:=0; N:=0;
 while not Eof(T) do begin
  ReadLn(T,L); K:=Pos(' ',L); C:=Copy(L,1,K-1); Delete(L,1,K); Inc(N);
  if Names[Route(L,6)]<>C then begin Inc(Bad); WriteLn('differs: ',L) end
 end;
 Close(T);
 WriteLn(N,' requests, ',Bad,' differ from the trainer');
 if Bad>0 then Halt(1)
end.
