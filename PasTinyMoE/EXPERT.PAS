program Expert;
{$IFDEF SPEC100}{$DEFINE SPEC90}{$ENDIF}
{$IFDEF SPEC90}{$DEFINE SPEC80}{$ENDIF}
{$IFDEF SPEC80}{$DEFINE SPEC70}{$ENDIF}
{$IFDEF SPEC70}{$DEFINE SPEC60}{$ENDIF}
{$IFDEF SPEC60}{$DEFINE SPEC50}{$ENDIF}
{$IFDEF SPEC50}{$DEFINE SPEC40}{$ENDIF}
{$IFDEF SPEC40}{$DEFINE SPEC30}{$ENDIF}
{$IFDEF SPEC30}{$DEFINE SPEC20}{$ENDIF}
{$IFDEF SPEC20}{$DEFINE SPEC10}{$ENDIF}
{$IFDEF SPEC10}{$DEFINE SPEC9}{$ENDIF}
{$IFDEF SPEC9}{$DEFINE SPEC8}{$ENDIF}
{$IFDEF SPEC8}{$DEFINE SPEC5}{$ENDIF}
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}
{$IFDEF SPEC100}
{ Leave conventional memory for the model and DOS drivers. }
{$M 12288,0,655360}
{$ELSE}{$M 16384,0,655360}{$ENDIF}
{$ENDIF}
{$N+}{$E+}
uses TNYNET,TNYSYS,EXPCAT,TOOLS{$IFDEF SPEC5},PILOTRT{$ENDIF};
{$IFDEF SPEC100}const OriginalSlot=129;{$ENDIF}
var Active,J,K,Code:Integer; Pinned,Interactive,ToolsOn,ScreenUI:Boolean; Q,A:String;
 Tokens,T,First,Last,Elapsed,Start:Longint;
{$IFDEF SPEC100}{$I MOEUI.INC}{$ENDIF}
function Num(N:Longint):String;
var S:String;
begin Str(N,S); Num:=S end;
procedure Report(S:String);
begin
 {$IFDEF VER70}{$IFDEF SPEC100}
 if ScreenUI then begin Chat(S+#13#10,7); Exit end;
 {$ENDIF}{$ENDIF}
 WriteLn(S)
end;
procedure MemoryReport;
begin
 {$IFDEF VER70}Report('heap='+Num(MemAvail)+' largest='+Num(MaxAvail)+' stack='+Num(Sptr));{$ENDIF}
end;
procedure Switch(Target:Integer);
var Old:Integer; Start:Longint;
begin
 if Target=Active then Exit;
 Old:=Active; Active:=0; Start:=NowMs;
 if TryModel(Items[Target].Name,Items[Target].Check) then Active:=Target
 else begin
  Report('load failed '+Items[Target].Name+' '+LoadError);
  if Old<>0 then
   if TryModel(Items[Old].Name,Items[Old].Check) then Active:=Old
   else Report('recovery failed '+LoadError)
 end;
 if not ScreenUI then WriteLn('load/recovery ms=',NowMs-Start);
 if Active<>0 then begin
  if not ScreenUI then Report('active '+Num(Items[Active].Id)+' '+Items[Active].Title);
 end else Report('unloaded');
 {$IFDEF VER70}{$IFDEF SPEC100}if ScreenUI then ExpertStatus;{$ENDIF}{$ENDIF}
end;
procedure PollEscape(I,N:Integer);
begin
 if Interactive then if KeyPressed then if ReadKey=27 then Cancelled:=True
end;
procedure Letter(C:Integer);
begin
 Last:=NowMs; if First<0 then First:=Last;
 {$IFDEF VER70}{$IFDEF SPEC100}
 if ScreenUI then begin
  Inc(Letters);
  RecordConfidence;
  Chat(Chr(C),10); Monitor;
  if not VoiceOn then Tone(900+(C mod 16)*70,6);
  PollEscape(0,0); Exit
 end;
 {$ENDIF}{$ENDIF}
 Write(Chr(C)); if Interactive then System.Flush(Output);
 PollEscape(0,0)
end;
begin
 Start:=NowMs; Interactive:=ConsoleIO;
 (* Exact answers from TOOLS.PAS: on at the keyboard, off for redirected
    input so recorded transcripts stay the same.  TOOLS ON / TOOLS OFF. *)
 ToolsOn:=Interactive;
 if not ReadCatalog then begin WriteLn('Invalid EXPERTS.CAT'); Halt(1) end;
 {$IFDEF VER70}{$IFDEF SPEC100}
 ScreenUI:=Interactive and (VideoMode=3) and (ParamCount=0);
 if ScreenUI then BeginUI;
 {$ENDIF}{$ENDIF}
 if not ScreenUI then WriteLn('catalog/init ms=',NowMs-Start);
 Creativity:=0;
 if not ScreenUI then begin WriteLn('FPU ',FPUName); MemoryReport end;
 {$IFDEF SPEC100}
 Items[OriginalSlot].Id:=0;
 Items[OriginalSlot].Name:='TINY.BIN';
 Items[OriginalSlot].Title:='Original Tiny';
 Items[OriginalSlot].Check:=$15282977;
 {$ENDIF}
 Switch(1); AllocMemory; if not ScreenUI then MemoryReport;
 {$IFDEF VER70}{$IFDEF SPEC100}if ScreenUI then begin Monitor; ReadySound end;{$ENDIF}{$ENDIF}
 if Interactive and not ScreenUI then
  WriteLn('LIST, USE id, AUTO, TOOLS ON/OFF, MEM, QUIT. Escape cancels an answer.');
 while True do begin
  {$IFDEF VER70}{$IFDEF SPEC100}if ScreenUI then ReadUI(Q) else{$ENDIF}{$ENDIF}
  begin
   if Interactive then begin Write('> '); System.Flush(Output) end;
   if Eof(Input) then Break;
   ReadLn(Q)
  end;
  Q:=Clean(Q);
  if Q='quit' then Break
  else begin
  {$IFDEF VER70}{$IFDEF SPEC100}if ScreenUI and (Q<>'') then Chat('YOU '+Q+#13#10,14);{$ENDIF}{$ENDIF}
  if Q='list' then begin
   for J:=1 to Count do begin
    Report(Num(Items[J].Id)+' '+Items[J].Title);
    {$IFDEF VER70}{$IFDEF SPEC100}
    if ScreenUI and (J mod 14=0) and (J<Count) then begin
     Report('Press a key for more, or Esc to stop listing.');
     if TNYSYS.ReadKey=27 then Break
    end;
    {$ENDIF}{$ENDIF}
   end
  end
  else if Q='auto' then Pinned:=False
  else if Q='tools on' then ToolsOn:=True
  else if Q='tools off' then ToolsOn:=False
  {$IFDEF SPEC5}else if FPUQuestion(Q) then Report('FPU detected: '+FPUName)
  else if OtherPCStatus(Q) then Report('Use MEM for program heap or FPU for coprocessor detection.'){$ENDIF}
  else if Q='mem' then MemoryReport
  else if Copy(Q,1,4)='use ' then begin
   Val(Copy(Q,5,255),K,Code); J:=0; if Code=0 then J:=FindId(K);
   if J=0 then Report('unknown id') else begin Switch(J); Pinned:=Active=J end
  end else if (Q<>'') and ToolsOn and (not Pinned) and ToolAnswer(Q,A) then begin
   Report(A);
   {$IFDEF VER70}{$IFDEF SPEC100}if ScreenUI then SpeakAnswer(A,0);{$ENDIF}{$ENDIF}
   if not ScreenUI then WriteLn('answer ms=0 chars=',Length(A),' tool')
  end else if Q<>'' then begin
   if not Pinned then begin T:=NowMs; J:=Route(Q); if not ScreenUI then WriteLn('route ms=',NowMs-T);
    {$IFDEF SPEC100}
    if J=0 then J:=OriginalSlot;
    Switch(J);
    {$ELSE}
    if J=0 then Report('Choose an expert with LIST and USE, or rephrase the question.')
    else Switch(J);
    {$ENDIF}
    if Active<>J then J:=0
    {$IFDEF SPEC8}else if Corrected<>'' then begin Report('read as: '+Corrected); Q:=Corrected end{$ENDIF}
    end else J:=Active;
   if (J<>0) and Ready then begin
    {$IFDEF VER70}{$IFDEF SPEC100}
    if ScreenUI then begin Letters:=0; HeatCount:=0; Chat('TINY ',11) end;
    {$ENDIF}{$ENDIF}
    First:=-1; T:=NowMs; Think(Q,A,Tokens,PollEscape,Letter); Elapsed:=NowMs-T;
    if ScreenUI then Report('') else begin
    WriteLn;
    WriteLn('answer ms=',Elapsed,' chars=',Length(A));
    if First>=0 then WriteLn('first char ms=',First-T,' output span ms=',Last-First);
    end;
    if Cancelled then Report('cancelled')
    {$IFDEF VER70}{$IFDEF SPEC100}else if ScreenUI then SpeakAnswer(A,Items[J].Id){$ENDIF}{$ENDIF}
   end
  end
 end;
 {$IFDEF VER70}{$IFDEF SPEC100}if ScreenUI then ExpertStatus;{$ENDIF}{$ENDIF}
 end;
 {$IFDEF VER70}{$IFDEF SPEC100}if ScreenUI then begin NoSound; TextMode(3) end;{$ENDIF}{$ENDIF}
 ReleaseMemory
end.
