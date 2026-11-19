unit PILOTRT;
{$IFDEF SPEC5}{$DEFINE SPEC4}{$ENDIF}
{$IFDEF FPC}{$MODE TP}{$ENDIF}
interface
function PilotDomain(Q:String):Byte;
{$IFDEF SPEC5}
function FPUQuestion(Q:String):Boolean;
function OtherPCStatus(Q:String):Boolean;
{$ENDIF}
implementation
{$IFDEF SPEC5}
function WordLine(Q:String):String;
var I:Integer; C:Char;
begin
 for I:=1 to Length(Q) do begin
  C:=UpCase(Q[I]);
  if C in ['A'..'Z'] then Q[I]:=Chr(Ord(C)+32)
  else if not (C in ['0'..'9']) then Q[I]:=' '
 end;
 WordLine:=' '+Q+' '
end;
function FPUQuestion(Q:String):Boolean;
begin
 Q:=WordLine(Q);
 FPUQuestion:=(Q=' fpu ') or
  (((Pos(' fpu ',Q)>0) or (Pos(' 387 ',Q)>0) or (Pos(' coprocessor ',Q)>0)) and
   ((Pos(' do i have ',Q)>0) or (Pos(' have i got ',Q)>0) or
    (((Pos(' does my ',Q)>0) or (Pos(' does this ',Q)>0)) and (Pos(' have ',Q)>0)) or
    (Pos(' has my ',Q)>0) or (Pos(' installed ',Q)>0) or
    (Pos(' detected ',Q)>0) or (Pos(' present ',Q)>0) or (Pos(' is there ',Q)>0)))
end;
function OtherPCStatus(Q:String):Boolean;
begin
 OtherPCStatus:=False;
 if PilotDomain(Q)<>3 then Exit;
 Q:=WordLine(Q);
 OtherPCStatus:=(Pos(' how much ',Q)>0) or (Pos(' installed ',Q)>0) or
  (Pos(' do i have ',Q)>0) or (Pos(' does my ',Q)>0) or (Pos(' does this ',Q)>0) or
  (Pos(' free space ',Q)>0) or (Pos(' on my ',Q)>0) or (Pos(' detected ',Q)>0)
end;
{$ENDIF}
{ Return zero when the terms do not identify one supported domain. }
function PilotDomain(Q:String):Byte;
const DOSWords='|dos|dir|cd|cls|type|file|files|directory|directories|folder|folders|screen|display|';
 PascalWords='|pascal|div|mod|integer|quotient|remainder|divide|division|operator|compound|statement|block|';
 NatureWords='|animal|insect|insects|spider|spiders|';
 {$IFDEF SPEC4}
 WordList='|brief|fragile|silent|rapid|vacant|damp|narrow|ancient|';
 {$ENDIF}
 {$IFDEF SPEC5}
 PCWords='|ram|rom|cpu|processor|fpu|387|coprocessor|storage|disk|serial|parallel|workbench|';
 {$ENDIF}
var I,Start:Integer; WordKey:String; Hits:Byte;
begin
 Hits:=0; I:=1;
 {$IFDEF SPEC5}if Pos(' read only memory ',WordLine(Q))>0 then Hits:=16;{$ENDIF}
 while I<=Length(Q) do begin
  Start:=I;
  while (I<=Length(Q)) and (UpCase(Q[I]) in ['A'..'Z'{$IFDEF SPEC5},'0'..'9'{$ENDIF}]) do begin
   if UpCase(Q[I]) in ['A'..'Z'] then Q[I]:=Chr(Ord(UpCase(Q[I]))+32);
   Inc(I)
  end;
  if I>Start then begin
   WordKey:='|'+Copy(Q,Start,I-Start)+'|';
   if Pos(WordKey,DOSWords)>0 then Hits:=Hits or 1;
   if Pos(WordKey,PascalWords)>0 then Hits:=Hits or 2;
   if Pos(WordKey,NatureWords)>0 then Hits:=Hits or 4;
   {$IFDEF SPEC4}if Pos(WordKey,WordList)>0 then Hits:=Hits or 8;{$ENDIF}
   {$IFDEF SPEC5}if Pos(WordKey,PCWords)>0 then Hits:=Hits or 16;{$ENDIF}
  end else Inc(I)
 end;
 case Hits of
  1:PilotDomain:=1;
  2:PilotDomain:=2;
  4:PilotDomain:=51;
  {$IFDEF SPEC4}8:PilotDomain:=41;{$ENDIF}
  {$IFDEF SPEC5}16:PilotDomain:=3;{$ENDIF}
  else PilotDomain:=0
 end
end;
end.
