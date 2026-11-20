unit PILOTRT;
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
{$IFDEF SPEC5}{$DEFINE SPEC4}{$ENDIF}
{$IFDEF FPC}{$MODE TP}{$ENDIF}
interface
function PilotDomain(Q:String):Byte;
{$IFDEF SPEC8}function FixTypos(Q:String; var Fixed:String):Boolean;{$ENDIF}
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
{$IFDEF SPEC100}{$I TOPIC100.INC}{$ELSE}
{$IFDEF SPEC90}{$I TOPIC90.INC}{$ELSE}
{$IFDEF SPEC80}{$I TOPIC80.INC}{$ELSE}
{$IFDEF SPEC70}{$I TOPIC70.INC}{$ELSE}
{$IFDEF SPEC60}{$I TOPIC60.INC}{$ELSE}
{$IFDEF SPEC50}{$I TOPIC50.INC}{$ELSE}
{$IFDEF SPEC40}{$I TOPIC40.INC}{$ELSE}
{$IFDEF SPEC30}{$I TOPIC30.INC}{$ELSE}
{$IFDEF SPEC20}{$I TOPICS20.INC}{$ELSE}
{$IFDEF SPEC9}{$I TOPICS9.INC}{$ELSE}{$I TOPICS.INC}{$ENDIF}
{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF}
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
{$IFDEF SPEC8}
(* True when A and B differ by one typing slip: one letter changed, added,
   dropped, or two neighbours swapped. *)
function Near(A,B:String):Boolean;
var I,LA,LB:Integer;
begin
 Near:=False; LA:=Length(A); LB:=Length(B);
 if Abs(LA-LB)>1 then Exit;
 I:=1;
 while (I<=LA) and (I<=LB) and (A[I]=B[I]) do Inc(I);
 if LA=LB then begin
  if I>LA then Exit;
  Near:=(Copy(A,I+1,255)=Copy(B,I+1,255)) or
   ((I<LA) and (A[I]=B[I+1]) and (A[I+1]=B[I]) and (Copy(A,I+2,255)=Copy(B,I+2,255)))
 end
 else if LA>LB then Near:=Copy(A,I+1,255)=Copy(B,I,255)
 else Near:=Copy(A,I,255)=Copy(B,I+1,255)
end;
(* Typo fallback for a question no expert claimed.  Each word of six or
   more letters that is not a topic term is compared with the topic terms
   of seven or more letters that start with the same letter.  If it is one
   slip away from terms of exactly one expert, the term replaces it.
   Shorter terms are left alone: too many ordinary words sit one letter
   from them (state and slate, another and anther).  Returns True when
   Fixed differs from Q; the caller routes Fixed as usual. *)
function FixTypos(Q:String; var Fixed:String):Boolean;
var I,J,Start,Hit:Integer; W:String; Found:Byte; Clash:Boolean;
begin
 FixTypos:=False; Fixed:=''; I:=1;
 while I<=Length(Q) do begin
  if UpCase(Q[I]) in ['A'..'Z'] then begin
   Start:=I;
   while (I<=Length(Q)) and (UpCase(Q[I]) in ['A'..'Z']) do Inc(I);
   W:=Copy(Q,Start,I-Start);
   for J:=1 to Length(W) do if W[J] in ['A'..'Z'] then W[J]:=Chr(Ord(W[J])+32);
   Hit:=0; Found:=0; Clash:=False;
   if (Length(W)>=6) and (TopicId(W)=0) then
    for J:=1 to SizeOf(Topics) div SizeOf(TopicEntry) do
     if (Topics[J].Term[1]=W[1]) and (Length(Topics[J].Term)>=7) then
      if Near(W,Topics[J].Term) then begin
       if (Found<>0) and (Topics[J].Id<>Found) then Clash:=True;
       Found:=Topics[J].Id; Hit:=J
      end;
   if (Hit<>0) and not Clash then begin Fixed:=Fixed+Topics[Hit].Term; FixTypos:=True end
   else Fixed:=Fixed+W
  end else begin Fixed:=Fixed+Q[I]; Inc(I) end
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
{$IFDEF SPEC100}
function GlossaryDomain(C:String):Byte;
begin
 GlossaryDomain:=0;
 if (Pos(' type mismatch ',C)>0) or (Pos(' unknown identifier ',C)>0) or
  (Pos(' duplicate identifier ',C)>0) or (Pos(' semicolon expected ',C)>0) then GlossaryDomain:=27
 else if (Pos(' single step ',C)>0) or (Pos(' call stack ',C)>0) or
  ((Pos(' watch ',C)>0) and ((Pos(' debug',C)>0) or (Pos(' expression ',C)>0) or
  (Pos(' pascal ',C)>0) or (Pos(' variable ',C)>0))) then GlossaryDomain:=28
 else if (Pos(' number notation ',C)>0) or (Pos(' digits zero ',C)>0) or
  (Pos(' positional weight ',C)>0) or (Pos(' place value ',C)>0) or (Pos(' digit ',C)>0) and
  ((Pos(' weight ',C)>0) or (Pos(' numeral ',C)>0)) or
  ((Pos(' base ',C)>0) and ((Pos(' digits ',C)>0) or (Pos(' hex ',C)>0) or
  (Pos(' zero and one ',C)>0))) then GlossaryDomain:=29
 else if (Pos(' boolean operator ',C)>0) or (Pos(' logic gate ',C)>0) or
  (Pos(' logic circuit ',C)>0) or (Pos(' truth table ',C)>0) or (Pos(' boolean logic ',C)>0) or (Pos(' boolean and ',C)>0) or
  (Pos(' boolean or ',C)>0) or (Pos(' boolean not ',C)>0) or (Pos(' boolean xor ',C)>0)
  or (Pos(' and gate ',C)>0) or (Pos(' or gate ',C)>0) or (Pos(' not gate ',C)>0) or
  (Pos(' truth condition ',C)>0) then GlossaryDomain:=30
 else if (Pos(' sorting ',C)>0) then GlossaryDomain:=31
 else if (Pos(' structure ',C)>0) and ((Pos(' record ',C)>0) or (Pos(' node ',C)>0))
  then GlossaryDomain:=32
 else if (Pos(' zip ',C)>0) or (Pos(' arc ',C)>0) or (Pos(' lzh ',C)>0)
  then GlossaryDomain:=33
 else if ((Pos(' spreadsheet ',C)>0) or (Pos(' formula ',C)>0)) and
  ((Pos(' reference ',C)>0) or (Pos(' copied ',C)>0) or (Pos(' copy ',C)>0))
  then GlossaryDomain:=34
 else if (Pos(' database ',C)>0) then GlossaryDomain:=35
 else if (Pos(' editor ',C)>0) and ((Pos(' caret ',C)>0) or (Pos(' wrap',C)>0) or
  (Pos(' insert ',C)>0) or (Pos(' overtype ',C)>0) or (Pos(' block ',C)>0) or
  (Pos(' selection ',C)>0))
  then GlossaryDomain:=36
end;
{$ENDIF}
{$IFDEF SPEC90}
{ Recognize named PC facilities and Pascal syntax before interpreting general English terms. }
function PCAndPascalDomain(Q,C:String):Byte;
begin
 PCAndPascalDomain:=0;
 if (Pos(' pc speaker ',C)>0) or ((Pos(' simple tones ',C)>0) and (Pos(' pc ',C)>0))
  then PCAndPascalDomain:=18
 else if (Pos(' symbols per second ',C)>0) or (Pos(' symbols sent each second ',C)>0) or
  ((Pos(' stop bit ',C)>0) or (Pos(' stop bits ',C)>0)) or (Pos(' flow control ',C)>0) or (Pos(' flow regulation ',C)>0) or
  (Pos(' asynchronous serial ',C)>0) or (Pos(' serial sender ',C)>0) then PCAndPascalDomain:=19
 else if (Pos(' pc bus ',C)>0) or (Pos(' expansion bus ',C)>0) or (Pos(' local bus ',C)>0)
  or (Pos(' standard architecture ',C)>0) or (Pos(' micro channel ',C)>0)
  or (Pos(' peripheral component interconnect ',C)>0) or (Pos(' at expansion ',C)>0)
  or ((Pos(' bus ',C)>0) and (Pos(' 16 bits ',C)>0)) then PCAndPascalDomain:=20
 else if (Pos(' typed file ',C)>0) or ((Pos(' untyped ',C)>0) and (Pos(' file ',C)>0)) or
  (((Pos(' pascal ',C)>0) or (Pos(' tp7 ',C)>0)) and ((Pos(' text file ',C)>0)
  or (Pos(' text stream ',C)>0))) then PCAndPascalDomain:=25
 else if (Pos(' var ',C)>0) and (Pos(':',Q)>0) and
  (Pos(' function ',C)=0) and (Pos(' procedure ',C)=0) and ((Pos(' char ',C)>0) or
  (Pos(' byte ',C)>0) or (Pos(' integer ',C)>0) or (Pos(' boolean ',C)>0)
  or (Pos(' longint ',C)>0)) then PCAndPascalDomain:=21
 else if (Pos(';',Q)>0) and (((Pos(' if ',C)>0) and (Pos(' then ',C)>0)) or
  ((Pos(' case ',C)>0) and (Pos(' of ',C)>0)) or ((Pos(' while ',C)>0) and
  (Pos(' do ',C)>0)) or ((Pos(' for ',C)>0) and (Pos(' do ',C)>0)) or
  ((Pos(' repeat ',C)>0) and (Pos(' until ',C)>0))) then PCAndPascalDomain:=22
 else if (Pos(' uses clause ',C)>0) or (Pos(' uses list ',C)>0) or
  (Pos(' uses keyword ',C)>0) then PCAndPascalDomain:=26
end;
{$ENDIF}
{$IFDEF SPEC80}
{ Resolve explicit DOS file names and qualified hardware terms before generic words. }
function DOSGlossaryDomain(Q,Context:String):Byte;
begin
 DOSGlossaryDomain:=0;
 if (Pos(' config sys ',Context)>0) or (Pos(' autoexec bat ',Context)>0) or
    (Pos(' command com ',Context)>0) then DOSGlossaryDomain:=8
 else if (Pos(' mda ',Context)>0) or (Pos(' cga ',Context)>0) or
    (Pos(' ega ',Context)>0) or (Pos(' vga ',Context)>0) then DOSGlossaryDomain:=13
 else if (Pos(' root directory ',Context)>0) and
    ((Pos(' fat ',Context)>0) or (Pos(' fat12 ',Context)>0) or (Pos(' fat16 ',Context)>0))
    then DOSGlossaryDomain:=7
 else if (Pos(' lock key ',Context)>0) and (Pos(' keyboard ',Context)>0)
    then DOSGlossaryDomain:=11
 else if (Pos(' bios cursor ',Context)>0) then DOSGlossaryDomain:=14
 else if (Pos(' dos text ',Context)>0) and (Pos(' pages ',Context)=0) and
    (Pos(' mode ',Context)=0) then DOSGlossaryDomain:=10
 else if (Pos(' carriage return ',Context)>0) or (Pos(' line feed ',Context)>0) or
    (Pos(' horizontal tab ',Context)>0) or (Pos(' ctrl z ',Context)>0) or
    (Pos(' file length ',Context)>0) or (Pos(' disk file ',Context)>0) and
    (Pos(' ends ',Context)>0) then DOSGlossaryDomain:=10
 else if (Pos(' batch ',Context)>0) or (Pos(' echo hello ',Context)>0) or
    (Pos(':done',Q)>0) or (Pos('%1',Q)>0) or (Pos('%2',Q)>0) or
    (Pos(' percent two ',Context)>0) and (Pos(' argument ',Context)>0)
    then DOSGlossaryDomain:=9
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
 {$IFDEF SPEC40}Context:String; Acoustic:Boolean;{$ENDIF}
 {$IFDEF SPEC50}OnlyAncient,MapContext,DegreeContext:Boolean;{$ENDIF}
 {$IFDEF SPEC70}BBSContext,FrontierContext,WordStarContext,FileContext,MemoryContext:Boolean;{$ENDIF}
begin
 Hits:=0; I:=1;
 {$IFDEF SPEC40}
 Context:=WordLine(Q);
 {$IFDEF SPEC100}
 Extra:=GlossaryDomain(Context);
 if Extra<>0 then begin PilotDomain:=Extra; Exit end;
 {$ENDIF}
 {$IFDEF SPEC90}
 Extra:=PCAndPascalDomain(Q,Context);
 if Extra<>0 then begin PilotDomain:=Extra; Exit end;
 {$ENDIF}
 {$IFDEF SPEC80}
 Extra:=DOSGlossaryDomain(Q,Context);
 if Extra<>0 then begin PilotDomain:=Extra; Exit end;
 {$ENDIF}
 {$IFDEF SPEC70}
 BBSContext:=(Pos(' bbs ',Context)>0) or (Pos(' bulletin board ',Context)>0);
 FrontierContext:=(Pos(' frontier ',Context)>0) or (Pos(' frontiersman ',Context)>0) or
  (Pos(' cowpoke ',Context)>0);
 WordStarContext:=Pos(' wordstar ',Context)>0;
 FileContext:=(Pos(' dos ',Context)>0) or (Pos(' file ',Context)>0) or
  (Pos(' filename ',Context)>0) or (Pos(' directory ',Context)>0) or (Pos(' folder ',Context)>0);
 MemoryContext:=(Pos(' conventional memory ',Context)>0) or (Pos(' base memory ',Context)>0) or
  (Pos(' upper memory ',Context)>0) or (Pos(' extended memory ',Context)>0) or
  (Pos(' expanded memory ',Context)>0) or (Pos(' high memory area ',Context)>0);
 {$ENDIF}
 {$IFDEF SPEC50}
 OnlyAncient:=True;
 MapContext:=(Pos(' map ',Context)>0) or (Pos(' maps ',Context)>0);
 DegreeContext:=(Pos(' degree ',Context)>0) or (Pos(' degrees ',Context)>0);
 {$ENDIF}
 Acoustic:=(Pos(' acoustics ',Context)>0) or (Pos(' sound ',Context)>0) or
  (Pos(' tone ',Context)>0) or (Pos(' pitch ',Context)>0) or
  (Pos(' infrasound ',Context)>0) or (Pos(' ultrasound ',Context)>0);
 {$ENDIF}
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
   {$IFDEF SPEC40}
   WordKey:=Copy(Q,Start,I-Start);
   {$IFDEF SPEC100}
   if (WordKey='editor') or (WordKey='editors') then Matched:=0;
   if (WordKey='decimal') and ((Pos(' code ',Context)>0) or (Pos(' ascii ',Context)>0))
    then Matched:=0;
   if (Matched=34) and (Pos(' spreadsheet ',Context)=0) and (Pos(' formula ',Context)=0)
    then Matched:=0;
   {$ENDIF}
   {$IFDEF SPEC90}
   if (WordKey='until') and (Pos(' repeat ',Context)=0) then Matched:=0;
   if ((WordKey='field') or (WordKey='fields') or (WordKey='bounds')) and
    (Pos(' record',Context)=0) and (Pos(' array',Context)=0) and
    (Pos(' pascal ',Context)=0) then Matched:=0;
   if (WordKey='typed') or (WordKey='clause') then Matched:=0;
   if (WordKey='interface') and (Pos(' interface section ',Context)=0) and
    (Pos(' unit ',Context)=0) then Matched:=0;
   if (WordKey='function') and (Pos(' function count ',Context)=0) and
    (Pos(' result ',Context)=0) and (Pos(' tp7 ',Context)=0) and
    (Pos(' pascal ',Context)=0) then Matched:=0;
   {$ENDIF}
   {$IFDEF SPEC80}
   if (Matched=14) and ((WordKey='cell') or (WordKey='cells')) and
      (Pos(' text ',Context)=0) then Matched:=0;
   if (WordKey='tab') and (Pos(' protect tab ',Context)>0) then Matched:=0;
   if (WordKey='cr') or (WordKey='lf') then Matched:=10;
   {$ENDIF}
   {$IFDEF SPEC50}
   { Scale and legend have several common meanings outside cartography. }
   if ((WordKey='scale') or (WordKey='legend')) and not MapContext then Matched:=0;
   if DegreeContext and ((WordKey='east') or (WordKey='west')) then Matched:=80;
   if (WordKey='river') and (Pos(' rome ',Context)>0) then Matched:=0;
   { Ocean names describe the route of a historical expedition. }
   if (Matched=76) and (Extra=85) then Matched:=Extra;
   if (Extra=76) and (Matched=85) then Extra:=Matched;
   {$ENDIF}
   {$IFDEF SPEC60}
   { Named missions and flights can mention their destination or crossing. }
   if (WordKey='moon') and (Pos(' apollo ',Context)>0) then Matched:=0;
   if (WordKey='atlantic') and (Pos(' lindbergh ',Context)>0) then Matched:=0;
   if (WordKey='forge') and (Pos(' blacksmith ',Context)>0) then Matched:=0;
   if (WordKey='verb') and ((Pos(' parser ',Context)>0) or
    (Pos(' adventure ',Context)>0)) then Matched:=0;
   {$ENDIF}
   {$IFDEF SPEC70}
   if ((WordKey='parent') or (WordKey='root') or (WordKey='extension'))
    and not FileContext then Matched:=0;
   if (WordKey='memory') and not MemoryContext then Matched:=0;
   if ((WordKey='door') or (WordKey='handle')) and not BBSContext then Matched:=0;
   if (WordKey='echo') and ((Pos(' ate0 ',Context)>0) or (Pos(' ate1 ',Context)>0))
    then Matched:=0;
   if FrontierContext and ((WordKey='weather') or (WordKey='traveler')) then Matched:=0;
   {$ENDIF}
   if Acoustic and ((WordKey='hertz') or (WordKey='frequency')) then Matched:=68;
   { The capitals model answers country/capital pairs, not general country questions. }
   if (Matched=71) and (Pos(' capital ',Context)=0) then Matched:=0;
   { A river can wind north or south; wind then names no weather phenomenon. }
   if (WordKey='wind') and (Pos(' does ',Context)>0) and
    ((Pos(' wind north ',Context)>0) or (Pos(' wind south ',Context)>0) or
     (Pos(' wind east ',Context)>0) or (Pos(' wind west ',Context)>0)) then Matched:=0;
   if (Matched=76) and (WordKey='atlantic') and (Pos(' atlantic salmon ',Context)>0)
    then Matched:=0;
   { A named geographic feature selects its shelf in a continent question. }
   if (Matched=73) and (Extra in [74..76]) then Matched:=Extra;
   if (Extra=73) and (Matched in [74..76]) then Extra:=Matched;
   {$ENDIF}
   if Matched<>0 then begin
    if (Extra<>0) and (Extra<>Matched) then begin PilotDomain:=0; Exit end;
    Extra:=Matched
   end;
   {$ENDIF}
   WordKey:='|'+Copy(Q,Start,I-Start)+'|';
   {$IFDEF SPEC70}
   { In the editor, file and block describe the objects of WordStar commands. }
   if (WordKey='|file|') and WordStarContext then WordKey:='||';
   if (WordKey='|block|') and (WordStarContext or (Pos(' marked block ',Context)>0)
    or (Pos(' mark block ',Context)>0)) then WordKey:='||';
   {$ENDIF}
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
   {$IFDEF SPEC4}
   if (Pos(WordKey,WordList)>0)
    {$IFDEF SPEC60}and not ((WordKey='|brief|') and (Start=4) and (Pos(' in brief ',Context)=1)){$ENDIF}
    then begin
    Hits:=Hits or 8;
    {$IFDEF SPEC50}if WordKey<>'|ancient|' then OnlyAncient:=False;{$ENDIF}
   end;
   {$ENDIF}
   {$IFDEF SPEC5}if Pos(WordKey,PCWords)>0 then Hits:=Hits or 16;{$ENDIF}
  end else Inc(I)
 end;
 {$IFDEF SPEC20}
 Q:=WordLine(Q);
 if WantsAntonym(Q) then begin
  if (Hits=8) and (Extra=0) and not WantsSynonym(Q) then PilotDomain:=47 else PilotDomain:=0;
  Exit
 end;
 {$IFDEF SPEC50}
 { In a named history or landmark question, ancient describes the subject. }
 if (Extra in [78,81..85]) and (Hits=8) and OnlyAncient then Hits:=0;
 {$ENDIF}
 {$IFDEF SPEC70}
 { A narrower DOS term specializes its parent domain. }
 {$IFDEF SPEC80}
 {$IFDEF SPEC90}
 {$IFDEF SPEC100}
 if (Extra in [27,28,30,33..36]) and (Hits in [1,2,3]) then Hits:=0;
 {$ENDIF}
 if (Extra in [17..20]) and (Hits in [1,16,17]) then Hits:=0;
 if (Extra in [21..26]) and (Hits in [1,2,3]) then Hits:=0;
 {$ENDIF}
 if (Extra in [7..16]) and (Hits in [1,16,17]) then Hits:=0;
 {$ENDIF}
 if (Extra=4) and (Hits=1) then Hits:=0;
 if Extra=5 then begin
  if (Pos(' do i have ',Q)>0) or (Pos(' is installed ',Q)>0) then begin PilotDomain:=0; Exit end;
  if (Hits=1) and (Pos(' dos ',Q)>0) then Hits:=0
 end;
 if (Extra=6) and (Hits=16) and (Pos(' disk ',Q)>0) then Hits:=0;
 {$ENDIF}
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
 {$IFDEF SPEC40}
 if (Extra=72) and (Hits=1) and not HasDOSWord then Hits:=0;
 {$IFDEF SPEC60}
 { In a text adventure, type introduces a game command. }
 if (Extra=94) and (Hits=1) and not HasDOSWord then Hits:=0;
 {$ENDIF}
 {$ENDIF}
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
