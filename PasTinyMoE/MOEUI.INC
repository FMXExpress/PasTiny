{$IFDEF VER70}
const
 PaletteIndex:array[0..15] of Byte=(0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);
 PaletteRGB:array[0..15,0..2] of Byte=(
 (1,1,7),(5,7,22),(0,26,18),(0,20,30),(40,4,12),(28,6,40),
 (42,26,4),(40,45,54),(13,16,28),(18,34,63),(18,63,42),(10,57,63),
 (63,22,34),(63,18,58),(63,54,14),(60,62,63));
const MonitorX=61; InputWidth=54;
{ The conversation panel, as in PasTiny: its window on the screen and the
  colours of the labels, the question, the answer and the word being said. }
const ChatL=3; ChatT=3; ChatR=56; ChatB=20; ChatW=54;
 ColYou=13; ColAsk=14; ColTiny=11; ColAnswer=10; ColGlow=15; ColSpeak=$2F; ColDim=8;
var ChatX,ChatY:Integer; Peak:array[0..5] of Single;
 Heat:array[0..17] of Byte; HeatCount,Letters:Integer; LastQuestion:String[MAXQ];
 SoundOn,VoiceOn:Boolean;
 { where the answer being written starts in the panel, how many of its
   letters are on the screen, the last one, and the sweep of the reading bar }
 AnsX0,AnsY0,AnsCol,Spin:Integer; AnsPrev:Char;
{ The start-up screen, as in PasTiny: the logo, where its next line of
  progress goes, and whether it is still showing. }
const Logo:array[0..4] of String[24]=(
 '#####  ###  #   #  #   #', '  #     #   ##  #   # # ',
 '  #     #   # # #    #  ', '  #     #   #  ##    #  ',
 '  #    ###  #   #    #  ');
 LogoCol:array[0..4] of Byte=(11,11,9,13,13); LogoX=16; LogoY=2;
var BootY:Integer; Booting:Boolean;

procedure At(X,Y,Color:Integer; S:String);
var I:Integer;
begin
 for I:=1 to Length(S) do Screen[(Y-1)*80+X+I-2]:=Ord(S[I])+Word(Color)*256
end;

procedure Box(X1,Y1,X2,Y2,Color:Integer; Title:String);
var X,Y:Integer;
begin
 for X:=X1+1 to X2-1 do begin At(X,Y1,Color,#205); At(X,Y2,Color,#205) end;
 for Y:=Y1+1 to Y2-1 do begin At(X1,Y,Color,#186); At(X2,Y,Color,#186) end;
 At(X1,Y1,Color,#201); At(X2,Y1,Color,#187);
 At(X1,Y2,Color,#200); At(X2,Y2,Color,#188);
 At(X1+2,Y1,Color,#181);
 At(X1+3,Y1,$3F,' '+Title+' ');
 At(X1+5+Length(Title),Y1,Color,#198)
end;

procedure Tone(Hz,Ms:Word);
begin
 if SoundOn then begin Sound(Hz); DelayMs(Ms); NoSound end
end;

procedure ReadySound;
begin Tone(1319,40); Tone(1760,70) end;

procedure Buzz(F1,F2,Ms,Shift:Word);
var T:Word;
begin
 F1:=Longint(F1)*Shift div 100; F2:=Longint(F2)*Shift div 100;
 T:=0;
 while T<Ms do begin
  Sound(F1); DelayMs(2); Sound(F2); DelayMs(2); Inc(T,4)
 end;
 NoSound
end;

procedure Hiss(Ms:Word);
var T:Word;
begin
 for T:=1 to Ms do begin Sound(2500+Random(4500)); DelayMs(1) end;
 NoSound
end;

{ Same PC-speaker letter patterns as PasTiny. }
procedure SayLetter(C:Char; Shift,Pace:Word);
 function Duration(Ms:Word):Word;
 begin Duration:=(Ms*Pace+50) div 100 end;
begin
 case UpCase(C) of
 'A':Buzz(730,1090,Duration(64),Shift); 'E':Buzz(530,1840,Duration(56),Shift);
 'I','Y':Buzz(300,2290,Duration(52),Shift); 'O':Buzz(570,840,Duration(64),Shift);
 'U':Buzz(320,870,Duration(56),Shift); 'S','Z','C','X':Hiss(Duration(46));
 'F','H','V','J':Hiss(Duration(30));
 'P','T','K','Q':begin Tone(3200,2); DelayMs(Duration(18)) end;
 'B','D','G':begin Buzz(180,260,Duration(12),Shift); DelayMs(Duration(10)) end;
 'M','N':Buzz(210,300,Duration(40),Shift); 'L','R','W':Buzz(400,1100,Duration(36),Shift);
 ' ':DelayMs(Duration(45)); ',','-':DelayMs(Duration(110)); '.','!','?',':':DelayMs(Duration(200));
 '0'..'9':Buzz(420+(Ord(C)-48)*60,900+(Ord(C)-48)*90,Duration(70),Shift);
 else DelayMs(Duration(20))
 end
end;

procedure SoundStatus;
begin
 if SoundOn then At(21,25,$3E,'ON ') else At(21,25,$3E,'OFF');
 if VoiceOn and SoundOn then At(35,25,$3E,'ON ') else At(35,25,$3E,'OFF')
end;

{ Colour text mode with the neon palette, and an empty screen. }
procedure NeonMode;
var I:Integer;
begin
 TextMode(3);
 if HasVGA then begin
  for I:=0 to 15 do SetDAC(PaletteIndex[I],PaletteRGB[I,0],PaletteRGB[I,1],PaletteRGB[I,2]);
  DisableBlink
 end;
 Window(1,1,80,25); TextAttr:=7; ClrScr
end;

{ Signs falling down the screen; a key cuts it short. }
procedure Rain;
var Col,Spd:array[0..39] of ShortInt; F,X,Y,I:Integer; Color:Byte;
begin
 for I:=0 to 39 do begin Col[I]:=-Random(25); Spd[I]:=1+Random(2) end;
 for F:=0 to 45 do begin
  for I:=0 to 39 do begin
   X:=2*I+1; Y:=Col[I];
   if F<40 then Color:=ColAnswer else Color:=ColDim;
   if (Y>=1) and (Y<=25) then At(X,Y,Color,Chr(33+Random(90)));
   if (Y+1>=1) and (Y+1<=25) then At(X,Y+1,15,Chr(33+Random(90)));
   if (Y-7>=1) and (Y-7<=25) then At(X,Y-7,7,' ');
   Inc(Col[I],Spd[I]); if Col[I]>32 then Col[I]:=-Random(10)
  end;
  if F mod 4=0 then Tone(3000+Random(3000),2);
  Flush; DelayMs(28);
  if KeyPressed then begin TNYSYS.ReadKey; F:=45 end
 end;
 TextAttr:=7; ClrScr
end;

function LogoCell(Y,X:Integer):Boolean;
begin
 LogoCell:=(Y>=0) and (Y<5) and (X>=0) and (X<24) and (Logo[Y][X+1]='#')
end;

{ The logo gathers out of random signs, then a light sweeps over it. }
procedure LogoIn;
var Done:array[0..4,0..23] of Boolean; J,K,Y,X,N,Total:Integer;
 procedure Cell(Color:Byte);
 begin At(LogoX+2*X,LogoY+Y,Color,#219#219) end;
begin
 FillChar(Done,SizeOf(Done),0); N:=0; Total:=0;
 for Y:=0 to 4 do for X:=0 to 23 do if LogoCell(Y,X) then Inc(Total);
 K:=0;
 while (N<Total) and (K<400) do begin
  for J:=0 to 4 do begin
   Y:=Random(5); X:=Random(24);
   if LogoCell(Y,X) and not Done[Y,X] then begin
    Done[Y,X]:=True; Inc(N);
    if not ((Y<4) and (X<23) and LogoCell(Y+1,X+1)) then At(LogoX+2*X+2,LogoY+Y+1,1,#177#177);
    Cell(LogoCol[Y])
   end
  end;
  for J:=0 to 5 do begin
   Y:=Random(5); X:=Random(24);
   if LogoCell(Y,X) and not Done[Y,X] then
    At(LogoX+2*X,LogoY+Y,ColDim,Chr(176+Random(3))+Chr(176+Random(3)))
  end;
  if K mod 3=0 then Tone(200+N*12,3);
  Flush; DelayMs(12); Inc(K)
 end;
 for Y:=0 to 4 do for X:=0 to 23 do if LogoCell(Y,X) then Cell(LogoCol[Y]);
 for K:=0 to 25 do begin
  for Y:=0 to 4 do begin
   X:=K; if LogoCell(Y,X) then Cell(15);
   X:=K-2; if LogoCell(Y,X) then Cell(LogoCol[Y])
  end;
  Flush; DelayMs(14)
 end
end;

{ Called as each table of the first expert is read: a bar, a percentage,
  and a line for the letters and for each layer as it comes on. }
procedure BootBar(Done,Total:Integer); far;
var J,N:Integer; S:String; Color:Byte;
begin
 N:=36*Longint(Done) div Total; At(22,15,11,#222);
 for J:=0 to 35 do begin
  if J*3<N then Color:=11 else Color:=ColAnswer;
  if J<N then At(23+J,15,Color,#219) else At(23+J,15,ColDim,#250)
 end;
 Str(100*Longint(Done) div Total:3,S); At(59,15,11,#221); At(60,15,15,' '+S+'%');
 if (Done=2) or ((Done>2) and ((Done-2) mod 6=0)) then begin
  if Done=2 then S:='letters + places'
  else begin Str((Done-2) div 6,S); S:='layer '+S+' of '+Chr(48+L) end;
  At(26,BootY,ColYou,#16); At(28,BootY,7,S);
  for J:=29+Length(S) to 49 do At(J,BootY,ColDim,#250);
  At(51,BootY,ColAnswer,'ONLINE'); Inc(BootY); Tone(880+110*(BootY mod 6),12)
 end;
 Flush
end;

{ The start-up screen up to the point where the first expert is read. }
procedure BootScreen;
begin
 SoundOn:=True; VoiceOn:=True; Booting:=True; BootY:=17;
 NeonMode; Cursor(False); Rain; LogoIn;
 At(22,8,15,'M I X T U R E   O F   E X P E R T S');
 At(27,9,ColDim,'SPEC100  '#250'  Turbo Pascal 7');
 for BootY:=10 to 69 do At(BootY,11,3,#196);
 BootY:=17;
 At(22,13,11,'LOADING NEURAL WEIGHTS FROM '+Items[1].Name);
 Flush
end;

{ The first expert is in: a rising tune and SYSTEM READY. }
procedure BootDone;
const Notes:array[0..5] of Word=(392,523,659,784,1047,1319);
var J:Integer; Color:Byte;
begin
 for J:=0 to 5 do Tone(Notes[J],55); Tone(1568,140);
 for J:=0 to 5 do begin
  if Odd(J) then Color:=15 else Color:=ColAnswer;
  At(30,BootY+1,Color,#16' SYSTEM  READY '#17); Flush; DelayMs(120)
 end;
 Booting:=False; Cursor(True)
end;

procedure BeginUI;
begin
 NeonMode;
 At(1,1,$1B,'                                                                                ');
 At(2,1,$1B,#17#16); At(5,1,$1F,'P A S T I N Y M O E');
 At(26,1,$1B,#250+'  NEURAL INTERFACE  '+#250+'  SPEC100');
 At(68,1,$1A,#254); At(70,1,$1B,'ONLINE');
 Box(1,2,58,21,11,'CONVERSATION');
 Box(59,2,80,21,3,'NEURAL MONITOR');
 Box(1,22,80,24,3,'ASK TINY');
 At(3,23,13,#16);
 At(59,22,3,#209); At(59,23,3,#179); At(59,24,3,#207);
 At(62,23,8,#24+' last  F1 help');
 At(1,25,$30,'                                                                                ');
 At(2,25,$3F,'F1'); At(4,25,$30,' Help');
 At(12,25,$3F,'F2'); At(14,25,$30,' Sound ');
 At(26,25,$3F,'F3'); At(28,25,$30,' Voice ');
 At(40,25,$3F,'F9'); At(42,25,$30,' Capture');
 At(52,25,$3F,'Esc'); At(55,25,$30,' Quit');
 SoundOn:=True; VoiceOn:=True; SoundStatus;
 At(MonitorX,16,8,'EXPERT');
 ChatX:=1; ChatY:=1; Spin:=0; AnsCol:=0; AnsX0:=8; AnsY0:=1;
 FillChar(Peak,SizeOf(Peak),0);
 HeatCount:=0; Letters:=0; LastQuestion:=''
end;

procedure Chat(S:String; Color:Byte);
begin
 Window(ChatL,ChatT,ChatR,ChatB); GotoXY(ChatX,ChatY);
 TextAttr:=Color; PutS(S); ChatX:=WhereX; ChatY:=WhereY; Flush
end;

procedure Greet;
begin
 Chat('Hello! I am TINY, with a hundred specialists.'#13#10,ColDim);
 Chat('Ask a question, or type LIST to see them.'#13#10,ColDim)
end;

{ Scroll the panel until Lines lines are free below the cursor, so that an
  answer does not scroll while it is being written. }
procedure ChatRoom(Lines:Integer);
var Height,X,Y:Integer;
begin
 Height:=ChatB-ChatT+1; X:=WhereX; Y:=WhereY;
 while (Y>Height-Lines+1) and (Y>1) do begin
  GotoXY(1,Height); PutS(#10); Dec(Y)
 end;
 GotoXY(X,Y)
end;

{ Text that wraps under its own first letter, not under the label. }
procedure ChatText(Color:Byte; S:String; Indent:Integer);
var J:Integer;
begin
 TextAttr:=Color;
 for J:=1 to Length(S) do begin
  if WhereX>=ChatW then begin PutS(#13#10); GotoXY(Indent,WhereY) end;
  PutCh(S[J])
 end
end;

{ A question: a blank line after what came before, then  YOU > question. }
procedure ChatYou(Q:String);
begin
 Window(ChatL,ChatT,ChatR,ChatB); GotoXY(ChatX,ChatY);
 if WhereX>1 then PutS(#13#10);
 if WhereY>1 then PutS(#13#10);
 ChatRoom(6);
 TextAttr:=ColYou; PutS(' YOU '#175' '); ChatText(ColAsk,Q,8); PutS(#13#10);
 ChatX:=WhereX; ChatY:=WhereY; Flush
end;

{ The label of an answer; what follows is written by AnsLetter. }
procedure ChatTiny;
begin
 Window(ChatL,ChatT,ChatR,ChatB); GotoXY(ChatX,ChatY);
 if WhereX>1 then PutS(#13#10);
 ChatRoom(4);
 TextAttr:=ColTiny; PutS('TINY '#175' ');
 AnsX0:=WhereX; AnsY0:=WhereY; AnsCol:=0;
 ChatX:=WhereX; ChatY:=WhereY; Flush
end;

{ The place on the screen of letter J of the answer. }
procedure AnsPos(J:Integer; var Sx,Sy:Integer);
var Per:Integer;
begin
 Per:=ChatW-AnsX0; Sx:=ChatL+AnsX0-1+J mod Per; Sy:=ChatT+AnsY0-1+J div Per
end;

procedure Meter(X,Y,N:Integer; Value:Single; Color:Byte);
var I,Filled:Integer;
begin
 Filled:=Trunc(Value*N*2);
 for I:=0 to N-1 do
  if 2*I+2<=Filled then At(X+I,Y,Color,#219)
  else if 2*I+1=Filled then At(X+I,Y,Color,#221)
  else At(X+I,Y,8,#250)
end;

function ConfidenceColor(Value:Byte):Byte;
begin
 if Value>80 then ConfidenceColor:=10
 else if Value>50 then ConfidenceColor:=14
 else ConfidenceColor:=12
end;

procedure RecordConfidence;
begin
 if HeatCount=18 then Move(Heat[1],Heat[0],17)
 else Inc(HeatCount);
 Heat[HeatCount-1]:=Trunc(100*LastConf)
end;

procedure ExpertStatus;
var S:String; Split:Integer;
begin
 if Booting then Exit;
 At(MonitorX,17,7,'                  ');
 At(MonitorX,18,7,'                  ');
 if Active=0 then S:='Unloaded' else S:=Items[Active].Title;
 Split:=Length(S);
 if Split>18 then begin
  Split:=18;
  while (Split>0) and (S[Split]<>' ') do Dec(Split);
  if Split=0 then Split:=18;
  At(MonitorX,18,15,Copy(S,Split+1,18))
 end;
 At(MonitorX,17,15,Copy(S,1,Split));
 At(MonitorX,19,8,'MODE');
 if Pinned then S:='PINNED' else S:='AUTO  ';
 if ToolsOn then S:=S+'  TOOLS ON ' else S:=S+'  TOOLS OFF';
 At(MonitorX,20,7,S); Flush
end;

procedure Monitor;
var I:Integer; V:Single; S:String; Color, Confidence:Byte; Glyph:Char;
begin
 At(MonitorX,3,8,'LAYER ACTIVITY');
 for I:=0 to L-1 do if I<6 then begin
  At(MonitorX,4+I,11,'L'+Chr(49+I));
  if LayerAct[I]>Peak[I] then Peak[I]:=LayerAct[I];
  V:=0; if Peak[I]>0 then V:=LayerAct[I]/Peak[I];
  if Odd(I) then Color:=11 else Color:=10;
  Meter(MonitorX+3,4+I,15,V,Color); Peak[I]:=Peak[I]*0.995
 end;
 Confidence:=0;
 if HeatCount>0 then Confidence:=Heat[HeatCount-1];
 At(MonitorX,10,8,'CONFIDENCE');
 Meter(MonitorX,11,13,Confidence/100,ConfidenceColor(Confidence));
 Str(Confidence:3,S); At(MonitorX+13,11,15,' '+S+'%');
 At(MonitorX,12,8,'LAST LETTERS');
 for I:=0 to 17 do begin
  if I>=HeatCount then At(MonitorX+I,13,8,#250)
  else begin
   Confidence:=Heat[I];
   if Confidence>90 then Glyph:=#219
   else if Confidence>70 then Glyph:=#178
   else if Confidence>45 then Glyph:=#177 else Glyph:=#176;
   At(MonitorX+I,13,ConfidenceColor(Confidence),Glyph)
  end
 end;
 At(MonitorX,14,8,'SPEED');
 S:=' --.-';
 if (Letters>0) and (Last>T) then Str((1000.0*Letters)/(Last-T):5:1,S);
 At(MonitorX,15,7,S+' letters/s  '); Flush
end;

{ While the question is taken in, a letter at a time: a light sweeping to
  and fro where the answer will be, and how much has been read. }
procedure ReadStep(J,N:Integer);
var K,Head,Sx,Sy,Dist:Integer; S:String;
begin
 Head:=Spin mod 18; if Head>=9 then Head:=17-Head;
 AnsPos(0,Sx,Sy);
 for K:=0 to 9 do begin
  Dist:=Abs(Head-K);
  case Dist of
   0:At(Sx+K,Sy,15,#219);
   1:At(Sx+K,Sy,ColYou,#178);
   2:At(Sx+K,Sy,5,#177);
   else At(Sx+K,Sy,ColDim,#250)
  end
 end;
 Str(100*Longint(J+1) div N,S);
 At(Sx+10,Sy,ColDim,' reading '+S+'%');
 Inc(Spin); Monitor;
 if J mod 3=0 then Tone(2400+Random(8)*150,3)
end;

{ A letter of the answer: a flicker of some other sign, then the letter
  bright, and the one before it settles into the answer's colour. }
procedure AnsLetter(C:Integer);
var X,Y:Integer;
begin
 if AnsCol=0 then begin AnsPos(0,X,Y); At(X,Y,7,'                       ') end
 else begin AnsPos(AnsCol-1,X,Y); At(X,Y,ColAnswer,AnsPrev) end;
 AnsPos(AnsCol,X,Y);
 if C<>32 then begin At(X,Y,11,Chr(33+Random(90))); Flush; DelayMs(10) end;
 At(X,Y,ColGlow,Chr(C)); AnsPrev:=Chr(C); Inc(AnsCol);
 Monitor;
 if not VoiceOn then Tone(900+(C mod 16)*70,6)
end;

{ The answer is whole: settle its last letter, show its size and time at
  the foot of the screen, and leave the panel ready for the next line. }
procedure AnsDone(Ms:Longint);
var X,Y:Integer; S,T:String;
begin
 if AnsCol=0 then begin AnsPos(0,X,Y); At(X,Y,7,'                       ') end
 else begin AnsPos(AnsCol-1,X,Y); At(X,Y,ColAnswer,AnsPrev) end;
 Str(AnsCol,S); Str(Ms div 1000,T); S:=S+' ltr '+T+'.'; Str((Ms mod 1000) div 100,T); S:=S+T+'s';
 At(62,25,$30,'                  '); At(79-Length(S),25,$3F,S);
 ChatX:=1; ChatY:=Y-ChatT+2; Flush
end;

{ Say the answer on the PC speaker, a word at a time, with the word being
  said lit up in the panel.  Every expert has its own pitch and pace. }
procedure SpeakAnswer(A:String; ExpertId:Integer);
var I,K,First,N,Profile,Sx,Sy:Integer; Pitch,Pace:Word; Stop:Boolean;
 procedure Paint(Color:Byte);
 begin
  K:=First;
  while (K<I) and (A[K]<>' ') do begin AnsPos(K-1,Sx,Sy); At(Sx,Sy,Color,A[K]); Inc(K) end;
  Flush
 end;
begin
 if not SoundOn then Exit;
 if not VoiceOn then begin ReadySound; Exit end;
 Pitch:=115; Pace:=100;
 if (ExpertId>=1) and (ExpertId<=100) then begin
  { 37 is coprime to 100, so every expert gets its own pitch and pace pair. }
  Profile:=(ExpertId-1)*37 mod 100;
  Pitch:=101+3*(Profile mod 10);
  Pace:=82+4*(Profile div 10)
 end;
 N:=Length(A); First:=1; Stop:=False;
 while (First<=N) and not Stop do begin
  I:=First; while (I<=N) and (A[I]<>' ') do Inc(I);
  while (I<=N) and (A[I]=' ') do Inc(I);
  if AnsCol=N then Paint(ColSpeak);
  for K:=First to I-1 do if not Stop then begin
   if KeyPressed then begin TNYSYS.ReadKey; Stop:=True end
   else SayLetter(A[K],Pitch-30*Longint(K-1) div (N+1),Pace)
  end;
  if AnsCol=N then Paint(ColAnswer);
  First:=I
 end
end;

procedure ShowHelp;
begin
 Chat('PasTinyMoE keyboard and commands'+#13#10,11);
 Chat('Up recalls the last question. F9 saves SCREEN.DMP.'+#13#10,7);
 Chat('F2 toggles sound. F3 toggles robot voice.'+#13#10,7);
 Chat('Any key stops speech. Esc quits at the prompt.'+#13#10,7);
 Chat('LIST shows expert IDs. USE id pins an expert.'+#13#10,7);
 Chat('AUTO restores routing. TOOLS ON/OFF toggles tools.'+#13#10,7);
 Chat('MEM shows free conventional memory.'+#13#10,7)
end;

procedure ReadUI(var S:String);
var C:Integer; F:File; Blank,Visible:String;
begin
 S:=''; Blank:=''; repeat Blank:=Blank+' ' until Length(Blank)=InputWidth;
 repeat
  Visible:=S;
  if Length(S)>InputWidth then Visible:=Copy(S,Length(S)-InputWidth+1,InputWidth);
  At(5,23,7,Blank); At(5,23,15,Visible);
  Window(1,1,80,25); GotoXY(5+Length(Visible),23);
  C:=TNYSYS.ReadKey;
  case C of
   13: begin
    if S<>'' then LastQuestion:=S;
    At(5,23,7,Blank); Exit
   end;
   27: begin S:='quit'; Exit end;
   8: if Length(S)>0 then Delete(S,Length(S),1);
   315: ShowHelp;
   316: begin SoundOn:=not SoundOn; SoundStatus; Tone(1800,2) end;
   317: begin VoiceOn:=not VoiceOn; SoundStatus; Tone(1800,2) end;
   328: S:=LastQuestion;
   256+67: begin
    Assign(F,'SCREEN.DMP'); {$I-}Rewrite(F,1);
    if IOResult=0 then begin BlockWrite(F,Screen,SizeOf(Screen)); Close(F) end;
    if IOResult<>0 then ;{$I+}
   end;
   32..126: if Length(S)<MAXQ then begin S:=S+Chr(C); Tone(1800,2) end
  end
 until False
end;
{$ENDIF}
