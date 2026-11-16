(* DOS UI, included in TINY.PAS. Coordinates and sound patterns follow TINY.C. *)
const
 C_FRAME=11; C_FRAME2=3; C_TITLE=$1B; C_TITLE2=$1F; C_PANEL=$3F;
 C_YOU=13; C_QTEXT=14; C_TINY=11; C_ANSWER=10; C_GLOW=15;
 C_SPEAK=$2F; C_DIM=8; C_TEXT=7; C_BRIGHT=15; C_BAR=$30;
 C_BARKEY=$3F; C_BARON=$3E; C_HOT=12; C_ON=10;
 CHAT_L=3; CHAT_T=3; CHAT_R=56; CHAT_B=20; CHATW=54; MON_X=61; IN_Y=23;
 K_ESC=27; K_ENTER=13; K_BS=8; K_F1=315; K_F2=316; K_F3=317;
 K_F4=318; K_UP=328;
 DemoQ:array[0..11] of String[50]=(
 'what is the capital of estonia','is a whale a fish','what is 7 times 8',
 'which countries border estonia','spell computer','what is the symbol for gold',
 'how do you say thank you in spanish','what is a group of lions called',
 'what comes after 199','what time is it','tell me a joke','name the continents');
 Logo:array[0..4] of String[24]=(
 '#####  ###  #   #  #   #', '  #     #   ##  #   # # ',
 '  #     #   # # #    #  ', '  #     #   #  ##    #  ',
 '  #    ###  #   #    #  ');
 LogoCol:array[0..4] of Integer=(11,11,9,13,13);
 LOGO_X=16; LOGO_Y=2;
var
 Vga,Logging:Boolean; ChatX,ChatY:Integer; LastQ,StatusRight:String;
 SndLog:Text; ActMax:array[0..MAXL-1] of Single;
 Heat:array[0..17] of Integer; HeatN:Integer; Speed10:Longint;
 BootY,AnsX0,AnsY0,AnsCol,Spin,ScrPrev:Integer;
function Num(N:Longint):String;
var S:String;
begin Str(N,S); Num:=S end;
function Padded(S:String; N:Integer):String;
begin while Length(S)<N do S:=S+' '; Padded:=Copy(S,1,N) end;
function Field(N:Longint; Width:Integer):String;
var S:String;
begin Str(N:Width,S); Field:=S end;
procedure Color(A:Integer);
var Fg,Bg:Integer;
begin
 if Mono then begin
  Fg:=A and 15; Bg:=(A shr 4) and 7;
  if Bg<>0 then A:=$70 else if Fg=8 then A:=7
  else if Fg>=9 then A:=15 else A:=7
 end;
 TextAttr:=A
end;
procedure NeonPalette;
const
 Reg:array[0..15] of Byte=(0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);
 Rgb:array[0..15,0..2] of Byte=(
 (1,1,7),(5,7,22),(0,26,18),(0,20,30),(40,4,12),(28,6,40),
 (42,26,4),(40,45,54),(13,16,28),(18,34,63),(18,63,42),(10,57,63),
 (63,22,34),(63,18,58),(63,54,14),(60,62,63));
var J:Integer;
begin
 for J:=0 to 15 do SetDAC(Reg[J],Rgb[J,0],Rgb[J,1],Rgb[J,2]); DisableBlink
end;
procedure Tone(Hz,Ms:Word);
begin
 if Logging then WriteLn(SndLog,Hz,' ',Ms);
 if not SoundOn then Exit;
 if Hz<>0 then Sound(Hz); DelayMs(Ms); NoSound
end;
procedure Quiet(Ms:Word);
begin if Logging then WriteLn(SndLog,'0 ',Ms); DelayMs(Ms) end;
procedure Sweep(FromHz,ToHz,Ms:Word);
var T:Word;
begin T:=0; while T<Ms do begin
 Tone(FromHz+(Longint(ToHz)-FromHz)*T div Ms,3); Inc(T,3) end
end;
procedure SndBoot;
const Notes:array[0..5] of Word=(392,523,659,784,1047,1319);
var J:Integer;
begin for J:=0 to 5 do Tone(Notes[J],55); Tone(1568,140) end;
procedure SndReady; begin Tone(1319,40); Tone(1760,70) end;
procedure SndClick; begin Tone(1800,2) end;
procedure SndError; begin Tone(140,120) end;
procedure SndBye; begin Sweep(1600,200,360) end;
procedure Buzz(F1,F2,Ms,Shift:Word);
var T:Word;
begin
 F1:=Longint(F1)*Shift div 100; F2:=Longint(F2)*Shift div 100;
 if Logging then WriteLn(SndLog,'B',F1,' ',F2,' ',Ms);
 if not SoundOn then begin DelayMs(Ms); Exit end;
 T:=0; while T<Ms do begin
  Sound(F1); DelayMs(2); Sound(F2); DelayMs(2); Inc(T,4)
 end; NoSound
end;
procedure Hiss(Ms:Word);
var T:Word;
begin
 if Logging then WriteLn(SndLog,'H ',Ms);
 if not SoundOn then begin DelayMs(Ms); Exit end;
 for T:=0 to Ms-1 do begin Sound(2500+Random(4500)); DelayMs(1) end; NoSound
end;
procedure SayLetter(C:Integer; Shift:Word);
begin
 if (C>=65) and (C<=90) then Inc(C,32);
 case Chr(C) of
 'a':Buzz(730,1090,64,Shift); 'e':Buzz(530,1840,56,Shift);
 'i','y':Buzz(300,2290,52,Shift); 'o':Buzz(570,840,64,Shift);
 'u':Buzz(320,870,56,Shift); 's','z','c','x':Hiss(46);
 'f','h','v','j':Hiss(30);
 'p','t','k','q':begin Tone(3200,2); Quiet(18) end;
 'b','d','g':begin Buzz(180,260,12,Shift); Quiet(10) end;
 'm','n':Buzz(210,300,40,Shift); 'l','r','w':Buzz(400,1100,36,Shift);
 ' ':Quiet(45); ',','-':Quiet(110); '.','!','?',':':Quiet(200);
 '0'..'9':Buzz(420+(C-48)*60,900+(C-48)*90,70,Shift);
 else Quiet(20)
 end
end;
procedure Full; begin Window(1,1,80,25) end;
procedure HLine(X,Y,N,Ch:Integer);
var J:Integer;
begin GotoXY(X,Y); for J:=1 to N do PutCh(Chr(Ch)) end;
procedure PutAt(X,Y,Attr:Integer; S:String);
begin GotoXY(X,Y); Color(Attr); PutS(S) end;
procedure Box(X1,Y1,X2,Y2,Attr:Integer; Title:String);
var Y:Integer;
begin
 Color(Attr); GotoXY(X1,Y1); PutCh(#201); HLine(X1+1,Y1,X2-X1-1,205); PutCh(#187);
 for Y:=Y1+1 to Y2-1 do begin
  GotoXY(X1,Y); PutCh(#186); GotoXY(X2,Y); PutCh(#186)
 end;
 GotoXY(X1,Y2); PutCh(#200); HLine(X1+1,Y2,X2-X1-1,205);
 GotoXY(X2,Y2); PutCh(#188);
 if Title<>'' then begin
  PutAt(X1+2,Y1,Attr,#181); PutAt(X1+3,Y1,C_PANEL,Title); Color(Attr); PutCh(#198)
 end
end;
procedure Meter(X,Y,W,V,Attr:Integer);
var J,N:Integer;
begin
 N:=Longint(V)*W*2 div 1000; GotoXY(X,Y);
 for J:=0 to W-1 do begin
  if N>=2*J+2 then begin Color(Attr); PutCh(#219) end
  else if N=2*J+1 then begin Color(Attr); PutCh(#221) end
  else begin Color(C_DIM); PutCh(#250) end
 end
end;
procedure StatusBar(Right:String);
begin
 Full; Color(C_BAR); GotoXY(1,25); PutS(' ');
 Color(C_BARKEY); PutS('F1'); Color(C_BAR); PutS(' Help  ');
 Color(C_BARKEY); PutS('F2'); Color(C_BAR); PutS(' Sound ');
 Color(C_BARON); if SoundOn then PutS('ON ') else PutS('OFF');
 Color(C_BAR); PutS('  '); Color(C_BARKEY); PutS('F3'); Color(C_BAR); PutS(' Voice ');
 Color(C_BARON); if VoiceOn then PutS('ON ') else PutS('OFF');
 Color(C_BAR); PutS('  '); Color(C_BARKEY); PutS('F4'); Color(C_BAR); PutS(' Creativity ');
 Color(C_BARON); PutCh(Chr(48+Creativity)); Color(C_BAR); PutS('  ');
 Color(C_BARKEY); PutS('Esc'); Color(C_BAR); PutS(' Quit ');
 if Right<>'' then StatusRight:=Copy(Right,1,15);
 PutS(Padded(StatusRight,15)); Flush
end;
procedure TitleBar;
begin
 Full; Color(C_TITLE); HLine(1,1,80,32);
 PutAt(2,1,C_TITLE,#17#16); PutAt(5,1,C_TITLE2,'T I N Y');
 PutAt(13,1,C_TITLE,#250'  NEURAL INTERFACE 2.1  '#250'  367,000 WEIGHTS');
 PutAt(62,1,$1A,#254); PutAt(64,1,C_TITLE,'ONLINE'); PutAt(73,1,C_TITLE2,ClockText)
end;
procedure MonitorStatic;
var J:Integer;
begin
 PutAt(MON_X,3,C_DIM,'LAYER ACTIVITY');
 for J:=0 to L-1 do if J<6 then begin
  PutAt(MON_X,4+J,C_FRAME,'L'+Num(J+1)); Meter(MON_X+3,4+J,15,0,C_ANSWER)
 end;
 PutAt(MON_X,10,C_DIM,'CONFIDENCE'); Meter(MON_X,11,13,0,C_ANSWER);
 PutAt(MON_X,12,C_DIM,'LAST LETTERS'); PutAt(MON_X,14,C_DIM,'SPEED');
 PutAt(MON_X,16,C_DIM,'NETWORK');
 PutAt(MON_X,17,C_TEXT,Num(L)); PutS(' layers '#250' '+Num(D)+' wide');
 PutAt(MON_X,19,C_DIM,'MODE')
end;
procedure MonitorLive;
var J,V,Attr,Ch:Integer;
begin
 Full;
 for J:=0 to L-1 do if J<6 then begin
  if LayerAct[J]>ActMax[J] then ActMax[J]:=LayerAct[J];
  if ActMax[J]>0 then V:=Trunc(1000.0*LayerAct[J]/ActMax[J]) else V:=0;
  if J mod 2<>0 then Attr:=C_FRAME else Attr:=C_ANSWER;
  Meter(MON_X+3,4+J,15,V,Attr); ActMax[J]:=ActMax[J]*0.995
 end;
 V:=Trunc(LastConf*1000.0);
 if V>800 then Attr:=C_ANSWER else if V>500 then Attr:=C_QTEXT else Attr:=C_HOT;
 Meter(MON_X,11,13,V,Attr); PutAt(MON_X+13,11,C_BRIGHT,' '+Field(V div 10,3)+'%');
 GotoXY(MON_X,13);
 for J:=0 to 17 do begin
  if J>=HeatN then begin Color(C_DIM); PutCh(#250) end else begin
   V:=Heat[J];
   if V>800 then Color(C_ANSWER) else if V>500 then Color(C_QTEXT) else Color(C_HOT);
   if V>900 then Ch:=219 else if V>700 then Ch:=178 else if V>450 then Ch:=177 else Ch:=176;
   PutCh(Chr(Ch))
  end
 end;
 PutAt(MON_X,15,C_TEXT,Num(Speed10 div 10)+'.'+Num(Speed10 mod 10)+' letters/s  ');
 PutAt(MON_X,20,C_TEXT,'creativity '+Num(Creativity)+'     '); Flush
end;
procedure Frame;
begin
 Full; Color(C_TEXT); ClrScr; TitleBar;
 Box(1,2,58,21,C_FRAME,' CONVERSATION ');
 Box(59,2,80,21,C_FRAME2,' NEURAL MONITOR ');
 Box(1,22,80,24,C_FRAME2,' ASK TINY ');
 PutAt(3,IN_Y,C_YOU,#16); PutAt(59,22,C_FRAME2,#209);
 PutAt(59,24,C_FRAME2,#207); PutAt(59,IN_Y,C_FRAME2,#179);
 PutAt(62,IN_Y,C_DIM,#24' last  F1 help');
 MonitorStatic; MonitorLive; StatusBar('')
end;
procedure ChatWin;
begin Window(CHAT_L,CHAT_T,CHAT_R,CHAT_B); GotoXY(ChatX,ChatY) end;
procedure ChatSave;
begin ChatX:=WhereX; ChatY:=WhereY; Full end;
procedure ChatNL; begin PutS(#13#10) end;
procedure ChatRoom(Lines:Integer);
var Height,X,Y:Integer;
begin
 Height:=CHAT_B-CHAT_T+1; X:=WhereX; Y:=WhereY;
 while (Y>Height-Lines+1) and (Y>1) do begin
  GotoXY(1,Height); PutS(#10); Dec(Y)
 end;
 GotoXY(X,Y)
end;
procedure ChatText(Attr:Integer; S:String; Indent:Integer);
var J:Integer;
begin
 Color(Attr); for J:=1 to Length(S) do begin
  if WhereX>=CHATW then begin ChatNL; GotoXY(Indent,WhereY) end;
  PutCh(S[J])
 end
end;
procedure DumpScreen(Name:String);
var F:File;
begin Assign(F,Name); Rewrite(F,1); BlockWrite(F,Screen,4000); Close(F) end;
function WaitOrKey(Ms:Word):Boolean;
var K:Integer;
begin
 WaitOrKey:=False; if Dump then Exit;
 DelayMs(Ms); if KeyPressed then begin K:=ReadKey; WaitOrKey:=True end
end;
procedure Rain;
var Col,Spd:array[0..79] of Integer; F,X,Y:Integer;
begin
 for X:=0 to 79 do begin Col[X]:=-Random(25); Spd[X]:=1+Random(2) end;
 for F:=0 to 45 do begin
  X:=0; while X<79 do begin
   Y:=Col[X];
   if (Y>=1) and (Y<=25) then begin
    GotoXY(X+1,Y); if F<40 then Color(C_ANSWER) else Color(C_DIM);
    PutCh(Chr(33+Random(90)))
   end;
   if (Y+1>=1) and (Y+1<=25) then begin
    GotoXY(X+1,Y+1); Color(C_BRIGHT); PutCh(Chr(33+Random(90)))
   end;
   if (Y-7>=1) and (Y-7<=25) then begin GotoXY(X+1,Y-7); PutCh(' ') end;
   Inc(Col[X],Spd[X]); if Col[X]>32 then Col[X]:=-Random(10); Inc(X,2)
  end;
  if F mod 4=0 then Tone(3000+Random(3000),2);
  if WaitOrKey(28) then Break
 end;
 Color(C_TEXT); ClrScr
end;
function LogoCell(Y,X:Integer):Boolean;
begin
 LogoCell:=False;
 if (Y>=0) and (Y<5) and (X>=0) and (X<Length(Logo[Y])) then
  LogoCell:=Logo[Y][X+1]='#'
end;
procedure LogoIn;
var Done:array[0..4,0..23] of Boolean;
 J,K,Y,X,N,Total:Integer;
begin
 FillChar(Done,SizeOf(Done),0); N:=0; Total:=0;
 for Y:=0 to 4 do for X:=0 to 23 do if LogoCell(Y,X) then Inc(Total);
 K:=0;
 while (N<Total) and (K<400) do begin
  for J:=0 to 4 do begin
   Y:=Random(5); X:=Random(24);
   if LogoCell(Y,X) and (not Done[Y,X]) then begin
    Done[Y,X]:=True; Inc(N);
    if not ((Y<4) and (X<23) and LogoCell(Y+1,X+1)) then begin
     GotoXY(LOGO_X+2*X+2,LOGO_Y+Y+1); Color(1); PutCh(#177); PutCh(#177)
    end;
    GotoXY(LOGO_X+2*X,LOGO_Y+Y); Color(LogoCol[Y]); PutCh(#219); PutCh(#219)
   end
  end;
  for J:=0 to 5 do begin
   Y:=Random(5); X:=Random(24);
   if LogoCell(Y,X) and (not Done[Y,X]) then begin
    GotoXY(LOGO_X+2*X,LOGO_Y+Y); Color(C_DIM);
    PutCh(Chr(176+Random(3))); PutCh(Chr(176+Random(3)))
   end
  end;
  if K mod 3=0 then Tone(200+N*12,3);
  if not Dump then DelayMs(12); Inc(K)
 end;
 for Y:=0 to 4 do for X:=0 to 23 do if LogoCell(Y,X) then begin
  GotoXY(LOGO_X+2*X,LOGO_Y+Y); Color(LogoCol[Y]); PutCh(#219); PutCh(#219)
 end;
 if not Dump then for X:=0 to 25 do begin
  for Y:=0 to 4 do begin
   if (X<24) and LogoCell(Y,X) then begin
    GotoXY(LOGO_X+2*X,LOGO_Y+Y); Color(C_BRIGHT); PutCh(#219); PutCh(#219)
   end;
   if (X>=2) and LogoCell(Y,X-2) then begin
    GotoXY(LOGO_X+2*(X-2),LOGO_Y+Y); Color(LogoCol[Y]); PutCh(#219); PutCh(#219)
   end
  end;
  DelayMs(14)
 end
end;
procedure BootBar(Done,Total:Integer);
var J,N:Integer; Buf:String;
begin
 N:=36*Longint(Done) div Total; Full; GotoXY(22,15); Color(C_FRAME); PutCh(#222);
 for J:=0 to 35 do begin
  if J<N then begin if J*3<N then Color(C_FRAME) else Color(C_ANSWER) end
  else Color(C_DIM);
  if J<N then PutCh(#219) else PutCh(#250)
 end;
 Color(C_FRAME); PutCh(#221); Color(C_BRIGHT); PutS(' '+Field(100*Longint(Done) div Total,3)+'%');
 if (Done=2) or ((Done>2) and ((Done-2) mod 6=0)) then begin
  if Done=2 then Buf:='letters + places' else Buf:='layer '+Num((Done-2) div 6)+' of '+Num(L);
  GotoXY(26,BootY); Color(C_YOU); PutS(#16' '); Color(C_TEXT); PutS(Buf+' ');
  J:=WhereX; Color(C_DIM); HLine(J,BootY,50-J,250);
  Color(C_ANSWER); PutS(' ONLINE'); Inc(BootY); Tone(880+110*(BootY mod 6),12)
 end; Flush
end;
procedure Boot;
var X:Integer;
begin
 Color(C_TEXT); ClrScr; Cursor(False); Rain; LogoIn;
 PutAt(24,8,C_BRIGHT,'N E U R A L    I N T E R F A C E');
 {$IFDEF FPC}PutAt(29,9,C_DIM,'version 2.1P  '#250'  Free Pascal');
 {$ELSE}PutAt(29,9,C_DIM,'version 2.1P  '#250'  Turbo Pascal 7');{$ENDIF}
 Color(C_FRAME2); HLine(10,11,60,196);
 PutAt(22,13,C_FRAME,'LOADING NEURAL WEIGHTS FROM TINY.BIN');
 BootY:=17; OnLoad:=BootBar; LoadModel('TINY.BIN'); AllocMemory; OnLoad:=nil;
 SndBoot;
 for X:=0 to 5 do begin
  if X mod 2<>0 then PutAt(30,BootY+1,C_BRIGHT,#16' SYSTEM  READY '#17)
  else PutAt(30,BootY+1,C_ANSWER,#16' SYSTEM  READY '#17);
  if not Dump then DelayMs(120)
 end;
 if Dump then DumpScreen('BOOT.DMP')
end;
procedure ShowHelp;
const Lines:array[0..6] of String[60]=(
 'Ask a question and press Enter.',
 'Try: capital of peru '#250' is a whale a fish',
 '     what is 7 times 8 '#250' spell elephant',
 '     which countries border estonia',
 '     how do you say thank you in spanish',
 'F2 sound '#250' F3 robot voice '#250' F4 creativity',
 #24' last question '#250' Esc quit '#250' CLS clears');
var J:Integer;
begin
 ChatWin; if WhereX>1 then ChatNL; ChatRoom(9);
 Color(C_PANEL); PutS(' HELP '); ChatNL;
 for J:=0 to 6 do begin Color(C_TEXT); PutS(' '+Lines[J]); ChatNL end;
 ChatSave; Flush
end;
procedure AnsPos(J:Integer; var Sx,Sy:Integer);
var Per:Integer;
begin
 Per:=CHATW-AnsX0; Sx:=CHAT_L+AnsX0-1+J mod Per;
 Sy:=CHAT_T+AnsY0-1+J div Per
end;
procedure UiStep(J,N:Integer);
var K,Head,Sx,Sy,Dist:Integer;
begin
 Full; Head:=Spin mod 18; if Head>=9 then Head:=17-Head;
 AnsPos(0,Sx,Sy); GotoXY(Sx,Sy);
 for K:=0 to 9 do begin
  Dist:=Abs(Head-K);
  case Dist of
   0:begin Color(C_BRIGHT); PutCh(#219) end;
   1:begin Color(C_YOU); PutCh(#178) end;
   2:begin Color(5); PutCh(#177) end;
   else begin Color(C_DIM); PutCh(#250) end
  end
 end;
 Color(C_DIM); PutS(' reading '+Num(100*Longint(J+1) div N)+'%');
 Inc(Spin); MonitorLive;
 if J mod 3=0 then Tone(2400+Random(8)*150,3); Flush
end;
procedure UiLetter(C:Integer);
var X,Y,K:Integer;
begin
 Full;
 if AnsCol=0 then begin
  AnsPos(0,X,Y); GotoXY(X,Y); Color(C_TEXT); PutS('                       ')
 end else begin
  AnsPos(AnsCol-1,X,Y); GotoXY(X,Y); Color(C_ANSWER); PutCh(Chr(ScrPrev))
 end;
 AnsPos(AnsCol,X,Y);
 if C<>32 then begin
  GotoXY(X,Y); Color(C_FRAME); PutCh(Chr(33+Random(90)));
  if not Dump then DelayMs(10)
 end;
 GotoXY(X,Y); Color(C_GLOW); PutCh(Chr(C)); ScrPrev:=C; Inc(AnsCol);
 if HeatN<18 then begin Heat[HeatN]:=Trunc(LastConf*1000.0); Inc(HeatN) end
 else begin
  for K:=0 to 16 do Heat[K]:=Heat[K+1]; Heat[17]:=Trunc(LastConf*1000.0)
 end;
 MonitorLive; if not VoiceOn then Tone(900+(C mod 16)*70,6); Flush
end;
procedure Speak(A:String);
var J,K,First,N,Sx,Sy:Integer; Shift:Word;
begin
 Full; First:=1; N:=Length(A);
 while First<=N do begin
  J:=First; while (J<=N) and (A[J]<>' ') do Inc(J);
  while (J<=N) and (A[J]=' ') do Inc(J);
  Color(C_SPEAK); K:=First;
  while (K<J) and (A[K]<>' ') do begin
   AnsPos(K-1,Sx,Sy); GotoXY(Sx,Sy); PutCh(A[K]); Inc(K)
  end;
  Shift:=115-30*Longint(First-1) div (N+1);
  for K:=First to J-1 do begin
   if KeyPressed then begin Shift:=0; Break end;
   SayLetter(Ord(A[K]),Shift)
  end;
  Color(C_ANSWER); K:=First;
  while (K<J) and (A[K]<>' ') do begin
   AnsPos(K-1,Sx,Sy); GotoXY(Sx,Sy); PutCh(A[K]); Inc(K)
  end;
  if Shift=0 then Break; First:=J
 end
end;
procedure Ask(Q:String);
var Answer,Info:String; T0,Tenths,Tokens:Longint; Letters,Sx,Sy:Integer;
begin
 ChatWin; if WhereX>1 then ChatNL; if WhereY>1 then ChatNL;
 ChatRoom(6); Color(C_YOU); PutS(' YOU '#175' '); ChatText(C_QTEXT,Q,8);
 ChatNL; Color(C_TINY); PutS('TINY '#175' ');
 AnsX0:=WhereX; AnsY0:=WhereY; AnsCol:=0; HeatN:=0; ChatSave;
 Cursor(False); StatusBar('thinking...');
 T0:=NowMs; Think(Q,Answer,Tokens,UiStep,UiLetter); Tenths:=(NowMs-T0) div 100;
 Letters:=Length(Answer);
 if Letters=0 then begin UiLetter(46); Answer:='.'; Letters:=1 end;
 AnsPos(AnsCol-1,Sx,Sy); GotoXY(Sx,Sy); Color(C_ANSWER); PutCh(Chr(ScrPrev));
 if Tenths>0 then Speed10:=100*Longint(Letters) div Tenths else Speed10:=0;
 Info:=Num(Letters)+' ltr '+Num(Tenths div 10)+'.'+Num(Tenths mod 10)+'s';
 StatusBar(Info); MonitorLive;
 if SoundOn and VoiceOn then begin Tone(1200,8); Speak(Answer) end else SndReady;
 ChatX:=1; ChatY:=Sy-CHAT_T+2; ChatWin; ChatSave; TitleBar; Cursor(True); Flush
end;
procedure DrawInput(Buf:String; N:Integer);
var Visible:Integer;
begin
 Full; GotoXY(5,IN_Y); Color(C_BRIGHT);
 if N>54 then begin PutS(Copy(Buf,N-53,54)); Visible:=54 end
 else begin PutS(Buf); Visible:=N end;
 Color(C_TEXT); HLine(5+Visible,IN_Y,55-Visible,32); GotoXY(5+Visible,IN_Y); Flush
end;
function ReadLine(var Buf:String):Integer;
var N,C:Integer;
begin
 Buf:=''; N:=0; DrawInput(Buf,N);
 repeat
  C:=ReadKey;
  case C of
   K_ENTER:begin ReadLine:=N; Exit end;
   K_ESC:begin ReadLine:=-1; Exit end;
   K_BS:if N>0 then begin Delete(Buf,N,1); Dec(N); SndClick end;
   K_UP:begin Buf:=LastQ; N:=Length(Buf) end;
   K_F1:ShowHelp;
   K_F2:begin SoundOn:=not SoundOn; SndClick end;
   K_F3:begin VoiceOn:=not VoiceOn; SndClick end;
   K_F4:begin Creativity:=(Creativity+1) mod 10; SndClick; MonitorLive end;
   32..126:if N<MAXQ then begin Buf:=Buf+Chr(C); Inc(N); SndClick end else SndError
  end;
  StatusBar(''); DrawInput(Buf,N)
 until False
end;
procedure DemoType(Q:String);
var Buf:String; N:Integer;
begin
 Buf:=''; for N:=1 to Length(Q) do begin
  Buf:=Buf+Q[N]; DrawInput(Buf,N); SndClick;
  if not Dump then DelayMs(45+Random(50))
 end;
 if not Dump then DelayMs(250); DrawInput('',0)
end;
procedure RestoreScreen;
begin
 NoSound; Full; if Vga and Neon then TextMode(3);
 TextAttr:=7; ClrScr; Cursor(True); Flush
end;
procedure UiMain;
var Line,Q:String; J,N,K:Integer; Mode:Byte;
begin
 ChatX:=1; ChatY:=1; StatusRight:=''; Logging:=False;
 Mode:=VideoMode;
 if (Mode=7) or (Mode=2) or (Mode=0) then Mono:=True;
 if (Mode<>7) and (Mode<>3) and (Mode<>2) then begin
  if Mono then TextMode(2) else TextMode(3)
 end;
 Vga:=(not Mono) and HasVGA; if Vga and Neon then NeonPalette;
 OnFail:=RestoreScreen;
 SkipDelays:=Dump;
 if Dump then begin Assign(SndLog,'SOUND.LOG'); Rewrite(SndLog); Logging:=True end;
 Boot;
 if (not Demo) and (not Dump) then begin
  PutAt(29,BootY+3,C_DIM,'press any key to begin');
  while not KeyPressed do begin end;
  if ReadKey=K_ESC then begin RestoreScreen; ReleaseMemory; Exit end
 end;
 Sweep(300,1400,120); Frame; Cursor(True);
 ChatWin; Color(C_DIM);
 PutS('Hello! I am TINY, a neural network in your computer.'); ChatNL;
 PutS('Ask about countries, animals, space, words or sums.'); ChatNL; ChatSave; SndReady;
 if Demo or Dump then begin
  for J:=0 to 11 do begin
   if KeyPressed then begin K:=ReadKey; Break end;
   DemoType(DemoQ[J]); Ask(DemoQ[J]);
   if Dump and (not DumpAll) and (J=3) then Break;
   if not Dump then DelayMs(1500)
  end;
  if Dump then begin
   DumpScreen('SCREEN.DMP'); if Logging then Close(SndLog);
   Logging:=False; RestoreScreen; ReleaseMemory; Exit
  end
 end;
 repeat
  N:=ReadLine(Line); if N<0 then Break;
  DrawInput('',0); Q:=Clean(Line);
  if Q<>'' then begin
   if IsWord(Q,'quit') or IsWord(Q,'exit') then Break;
   if IsWord(Q,'cls') then begin Frame; ChatX:=1; ChatY:=1 end
   else if IsWord(Q,'help') then ShowHelp
   else begin LastQ:=Q; Ask(Q) end
  end
 until False;
 StatusBar('goodbye'); SndBye; RestoreScreen; ReleaseMemory;
 WriteLn('TINY: goodbye!')
end;
