unit PILOTRT;
{$IFDEF SPEC30}{$DEFINE SPEC20}{$ENDIF}
{$IFDEF SPEC20}{$DEFINE SPEC10}{$ENDIF}
{$IFDEF SPEC10}{$DEFINE SPEC9}{$ENDIF}
{$IFDEF SPEC9}{$DEFINE SPEC8}{$ENDIF}
{$IFDEF SPEC8}{$DEFINE SPEC5}{$ENDIF}
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
{$IFDEF SPEC8}
type TopicEntry=record Term:String[20]; Id:Byte end;
{$IFDEF SPEC30}{$I TOPIC30.INC}{$ELSE}
{$IFDEF SPEC20}{$I TOPICS20.INC}{$ELSE}
{$IFDEF SPEC9}{$I TOPICS9.INC}{$ELSE}{$I TOPICS.INC}{$ENDIF}
{$ENDIF}{$ENDIF}
function TopicId(Token:String):Byte;
var Low,High,Mid:Integer;
begin
 Low:=1; High:=SizeOf(Topics) div SizeOf(TopicEntry); TopicId:=0;
 while Low<=High do begin
  Mid:=(Low+High) div 2;
  if Token=Topics[Mid].Term then begin TopicId:=Topics[Mid].Id; Exit end;
  if Token<Topics[Mid].Term then High:=Mid-1 else Low:=Mid+1
 end
end;
{$ENDIF}
{$IFDEF SPEC10}
function WantsSynonym(Q:String):Boolean;
begin
 Q:=WordLine(Q);
 WantsSynonym:=(Pos(' synonym ',Q)>0) or (Pos(' synonyms ',Q)>0) or
  (Pos(' another word ',Q)>0) or (Pos(' alternative to ',Q)>0) or
  (Pos(' similar word ',Q)>0) or (Pos(' similar to ',Q)>0) or
  (Pos(' can replace ',Q)>0)
end;
{$ENDIF}
{$IFDEF SPEC20}
function WantsAntonym(Q:String):Boolean;
begin
 Q:=WordLine(Q);
 WantsAntonym:=(Pos(' opposite ',Q)>0) or (Pos(' opposites ',Q)>0) or
  (Pos(' antonym ',Q)>0) or (Pos(' antonyms ',Q)>0) or (Pos(' reverse meaning ',Q)>0)
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
 {$IFDEF SPEC8}Extra,Matched:Byte;{$ENDIF}
 {$IFDEF SPEC9}SpecificPascal:Boolean;{$ENDIF}
 {$IFDEF SPEC30}HasDOSWord,VerbAffect:Boolean;{$ENDIF}
begin
 Hits:=0; I:=1;
 {$IFDEF SPEC30}HasDOSWord:=False; VerbAffect:=Pos(' how does ',WordLine(Q))>0;{$ENDIF}
 {$IFDEF SPEC8}Extra:=0;{$ENDIF}
 {$IFDEF SPEC9}SpecificPascal:=False;{$ENDIF}
 {$IFDEF SPEC5}if Pos(' read only memory ',WordLine(Q))>0 then Hits:=16;{$ENDIF}
 while I<=Length(Q) do begin
  Start:=I;
  while (I<=Length(Q)) and (UpCase(Q[I]) in ['A'..'Z'{$IFDEF SPEC5},'0'..'9'{$ENDIF}]) do begin
   if UpCase(Q[I]) in ['A'..'Z'] then Q[I]:=Chr(Ord(UpCase(Q[I]))+32);
   Inc(I)
  end;
  if I>Start then begin
   {$IFDEF SPEC8}
   Matched:=TopicId(Copy(Q,Start,I-Start));
   {$IFDEF SPEC30}
   { In a causal question, affect is a verb rather than a vocabulary headword. }
   if VerbAffect and (Copy(Q,Start,I-Start)='affect') then Matched:=0;
   {$ENDIF}
   if Matched<>0 then begin
    if (Extra<>0) and (Extra<>Matched) then begin PilotDomain:=0; Exit end;
    Extra:=Matched
   end;
   {$ENDIF}
   WordKey:='|'+Copy(Q,Start,I-Start)+'|';
   if Pos(WordKey,DOSWords)>0 then begin
    Hits:=Hits or 1;
    {$IFDEF SPEC30}if WordKey<>'|type|' then HasDOSWord:=True;{$ENDIF}
   end;
   if Pos(WordKey,PascalWords)>0 then begin
    Hits:=Hits or 2;
    {$IFDEF SPEC9}
    if (WordKey<>'|statement|') and (WordKey<>'|compound|') then SpecificPascal:=True;
    {$ENDIF}
   end;
   if Pos(WordKey,NatureWords)>0 then Hits:=Hits or 4;
   {$IFDEF SPEC4}if Pos(WordKey,WordList)>0 then Hits:=Hits or 8;{$ENDIF}
   {$IFDEF SPEC5}if Pos(WordKey,PCWords)>0 then Hits:=Hits or 16;{$ENDIF}
  end else Inc(I)
 end;
 {$IFDEF SPEC20}
 Q:=WordLine(Q);
 if WantsAntonym(Q) then begin
  if (Hits=8) and (Extra=0) and not WantsSynonym(Q) then PilotDomain:=47 else PilotDomain:=0;
  Exit
 end;
 { State abbreviations are ambiguous outside postal or geographic questions. }
 if Extra=48 then
  if (Pos(' state ',Q)=0) and (Pos(' postal ',Q)=0) and (Pos(' address ',Q)=0)
   and (Pos(' abbreviation ',Q)=0) then begin PilotDomain:=0; Exit end;
 { These introductory animal models have no numerical reference tables. }
 if (Extra>=52) and (Extra<=57) then begin
  if (Pos(' how tall ',Q)>0) or (Pos(' how heavy ',Q)>0) then begin PilotDomain:=0; Exit end;
  if (Hits=1) and (Pos(' type of ',Q)>0) and (Pos(' dos ',Q)=0) then Hits:=0
 end;
 if (Extra=50) and (Hits=4) and (Pos(' language ',Q)>0) then Hits:=0;
 {$IFDEF SPEC30}
 { In geology, type usually asks for the classification of the rock. }
 if (Extra=64) and (Hits=1) and not HasDOSWord then Hits:=0;
 { Specific spider anatomy belongs to Spiders; general counts remain in Naturalist. }
 if (Extra=58) and (Hits=4) then Hits:=0;
 {$ENDIF}
 { A species clue specializes a generic animal question. }
 if (Extra>=52) and (Extra<=57) and (Hits=4) then Hits:=0;
 {$ENDIF}
 {$IFDEF SPEC10}
 if WantsSynonym(Q) then begin
  if (Hits=8) and (Extra=0) then PilotDomain:=46 else PilotDomain:=0;
  Exit
 end;
 {$ENDIF}
 {$IFDEF SPEC8}
 {$IFDEF SPEC9}if (Extra=45) and (Hits=2) and not SpecificPascal then Hits:=0;{$ENDIF}
 if Extra<>0 then begin
  if Hits=0 then PilotDomain:=Extra else PilotDomain:=0;
  Exit
 end;
 {$ENDIF}
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
