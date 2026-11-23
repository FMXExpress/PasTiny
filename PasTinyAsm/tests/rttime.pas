program RTTIME;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
(* RTTIME ROUTER.BIN ROUTER.TXT [rounds]: how long the router takes.  Every
   request of the text is routed, rounds times over, and the BIOS clock
   (18.2 ticks a second) is read before and after. *)
uses ROUTER;
const MAXREQ=300;
type PStr=^String;
var T:Text; L:String; Req:array[1..MAXREQ] of PStr; N,I,R,Rounds,Code:Integer; Letters,T0,T1:Longint; Ms:Real;
 Ticks:Longint absolute $40:$6C;
begin
 if not LoadRouter(ParamStr(1)) then begin WriteLn('cannot read ',ParamStr(1)); Halt(1) end;
 Rounds:=1; if ParamCount>2 then Val(ParamStr(3),Rounds,Code);
 Assign(T,ParamStr(2)); Reset(T); N:=0; Letters:=0;
 while not Eof(T) and (N<MAXREQ) do begin
  ReadLn(T,L); Delete(L,1,Pos(' ',L));
  Inc(N); GetMem(Req[N],Length(L)+1); Req[N]^:=L; Inc(Letters,Length(L))
 end;
 Close(T);
 T0:=Ticks; repeat until Ticks<>T0; T0:=Ticks;          (* start on a tick *)
 for R:=1 to Rounds do for I:=1 to N do Code:=Route(Req[I]^,7);
 T1:=Ticks;
 Ms:=(T1-T0)*54.925;
 WriteLn(N,' requests x ',Rounds,', ',Letters,' letters a round, ',T1-T0,' ticks');
 Write(Ms/(N*1.0*Rounds):0:1,' ms a request (',Letters/N:0:0,' letters on average), ');
 WriteLn(Ms/(Letters*1.0*Rounds):0:2,' ms a letter')
end.
