unit PILOTRT;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
interface
function PilotDomain(Q:String):Byte;
implementation
{ Return zero when the terms do not identify one supported domain. }
function PilotDomain(Q:String):Byte;
const DOSWords='|dos|dir|cd|cls|type|file|files|directory|directories|folder|folders|screen|display|';
 PascalWords='|pascal|div|mod|integer|quotient|remainder|divide|division|operator|compound|statement|block|';
 NatureWords='|animal|insect|insects|spider|spiders|';
 {$IFDEF SPEC4}
 WordList='|brief|fragile|silent|rapid|vacant|damp|narrow|ancient|';
 {$ENDIF}
var I,Start:Integer; WordKey:String; Hits:Byte;
begin
 Hits:=0; I:=1;
 while I<=Length(Q) do begin
  Start:=I;
  while (I<=Length(Q)) and (UpCase(Q[I]) in ['A'..'Z']) do begin
   Q[I]:=Chr(Ord(UpCase(Q[I]))+32); Inc(I)
  end;
  if I>Start then begin
   WordKey:='|'+Copy(Q,Start,I-Start)+'|';
   if Pos(WordKey,DOSWords)>0 then Hits:=Hits or 1;
   if Pos(WordKey,PascalWords)>0 then Hits:=Hits or 2;
   if Pos(WordKey,NatureWords)>0 then Hits:=Hits or 4;
   {$IFDEF SPEC4}if Pos(WordKey,WordList)>0 then Hits:=Hits or 8;{$ENDIF}
  end else Inc(I)
 end;
 case Hits of
  1:PilotDomain:=1;
  2:PilotDomain:=2;
  4:PilotDomain:=51;
  {$IFDEF SPEC4}8:PilotDomain:=41;{$ENDIF}
  else PilotDomain:=0
 end
end;
end.
