program Expert;
{$IFDEF SPEC9}{$DEFINE SPEC8}{$ENDIF}
{$IFDEF SPEC8}{$DEFINE SPEC5}{$ENDIF}
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$M 16384,0,655360}{$ENDIF}
{$N+}{$E+}
uses TNYNET,TNYSYS,EXPCAT{$IFDEF SPEC5},PILOTRT{$ENDIF};
var Active,J,K,Code:Integer; Pinned,Interactive:Boolean; Q,A:String; Tokens,T,First,Last,Elapsed,Start:Longint;
procedure MemoryReport;
begin
 {$IFDEF VER70}WriteLn('heap=',MemAvail,' largest=',MaxAvail,' stack=',Sptr);{$ENDIF}
end;
procedure Switch(Target:Integer);
var Old:Integer; Start:Longint;
begin
 if Target=Active then Exit;
 Old:=Active; Active:=0; Start:=NowMs;
 if TryModel(Items[Target].Name,Items[Target].Check) then Active:=Target
 else begin
  WriteLn('load failed ',Items[Target].Name,' ',LoadError);
  if Old<>0 then
   if TryModel(Items[Old].Name,Items[Old].Check) then Active:=Old
   else WriteLn('recovery failed ',LoadError)
 end;
 WriteLn('load/recovery ms=',NowMs-Start);
 if Active<>0 then WriteLn('active ',Items[Active].Id,' ',Items[Active].Title)
 else WriteLn('unloaded')
end;
procedure PollEscape(I,N:Integer);
begin
 if Interactive then if KeyPressed then if ReadKey=27 then Cancelled:=True
end;
procedure Letter(C:Integer);
begin
 Last:=NowMs; if First<0 then First:=Last;
 Write(Chr(C)); if Interactive then System.Flush(Output);
 PollEscape(0,0)
end;
begin
 Start:=NowMs; Interactive:=ConsoleIO;
 if not ReadCatalog then begin WriteLn('Invalid EXPERTS.CAT'); Halt(1) end;
 WriteLn('catalog/init ms=',NowMs-Start);
 Creativity:=0; WriteLn('FPU ',FPUName); MemoryReport;
 Switch(1); AllocMemory; MemoryReport;
 if Interactive then WriteLn('LIST, USE id, AUTO, MEM, QUIT. Escape cancels an answer.');
 while True do begin
  if Interactive then begin Write('> '); System.Flush(Output) end;
  if Eof(Input) then Break;
  ReadLn(Q); Q:=Clean(Q);
  if Q='quit' then Break
  else if Q='list' then begin for J:=1 to Count do WriteLn(Items[J].Id,' ',Items[J].Title) end
  else if Q='auto' then Pinned:=False
  {$IFDEF SPEC5}else if FPUQuestion(Q) then WriteLn('FPU detected: ',FPUName)
  else if OtherPCStatus(Q) then WriteLn('Use MEM for program heap or FPU for coprocessor detection.'){$ENDIF}
  else if Q='mem' then MemoryReport
  else if Copy(Q,1,4)='use ' then begin
   Val(Copy(Q,5,255),K,Code); J:=0; if Code=0 then J:=FindId(K);
   if J=0 then WriteLn('unknown id') else begin Switch(J); Pinned:=Active=J end
  end else if Q<>'' then begin
   if not Pinned then begin T:=NowMs; J:=Route(Q); WriteLn('route ms=',NowMs-T);
    if J=0 then WriteLn('Choose an expert with LIST and USE, or rephrase the question.')
    else Switch(J);
    if Active<>J then J:=0 end else J:=Active;
   if (J<>0) and Ready then begin
    First:=-1; T:=NowMs; Think(Q,A,Tokens,PollEscape,Letter); Elapsed:=NowMs-T; WriteLn;
    WriteLn('answer ms=',Elapsed,' chars=',Length(A));
    if First>=0 then WriteLn('first char ms=',First-T,' output span ms=',Last-First);
    if Cancelled then WriteLn('cancelled')
   end
  end
 end;
 ReleaseMemory
end.
