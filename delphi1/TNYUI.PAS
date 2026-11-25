unit TnyUI;

(* TINY 2.1 for Delphi 1 - the full-screen interface.

   A function-by-function port of the DOS interface in TINY.C: boot
   sequence (digital rain, logo, loading bar), chat window, neural monitor,
   status bar, help, demo mode and the PC-speaker robot voice. It draws
   through TnyWin's 80 x 25 cell buffer, so the layout is the same. *)

{$IFDEF FPC} {$MODE TP} {$ENDIF}
{$F+,R-,S-,X+}

interface

var
  Mono, Neon, SoundOn, VoiceOn, Demo, Dump, DumpAll: Boolean;

function UiMain: Integer;
procedure Idle;

implementation

uses TnyNet, TnyWin;

const
  SCRW   = 80;
  CHAT_L = 3;              { chat window, inside its frame }
  CHAT_T = 3;
  CHAT_R = 56;
  CHAT_B = 20;
  CHATW  = CHAT_R - CHAT_L + 1;
  MON_X  = 61;             { neural monitor panel }
  IN_Y   = 23;

  C_FRAME  = 11;           { electric cyan }
  C_FRAME2 = 3;            { dark cyan }
  C_TITLE  = $1B;          { cyan on blue }
  C_TITLE2 = $1F;          { white on blue }
  C_PANEL  = $3F;          { white on dark cyan: panel names }
  C_YOU    = 13;           { neon pink }
  C_QTEXT  = 14;           { amber }
  C_TINY   = 11;
  C_ANSWER = 10;           { neon mint }
  C_GLOW   = 15;           { newest letter }
  C_SPEAK  = $2F;          { word being spoken }
  C_DIM    = 8;
  C_TEXT   = 7;
  C_BRIGHT = 15;
  C_BAR    = $30;          { status bar }
  C_BARKEY = $3F;
  C_BARON  = $3E;
  C_HOT    = 12;

  LOGO_X = 16;
  LOGO_Y = 2;

  Logo: array[0..4] of String[24] = (
    '#####  ###  #   #  #   #',
    '  #     #   ##  #   # # ',
    '  #     #   # # #    #  ',
    '  #     #   #  ##    #  ',
    '  #    ###  #   #    #  ');
  LogoCol: array[0..4] of Integer = (11, 11, 9, 13, 13);

  NDEMO = 12;
  DemoQ: array[1..NDEMO] of String[40] = (
    'what is the capital of estonia', 'is a whale a fish', 'what is 7 times 8',
    'which countries border estonia', 'spell computer', 'what is the symbol for gold',
    'how do you say thank you in spanish', 'what is a group of lions called',
    'what comes after 199', 'what time is it', 'tell me a joke',
    'name the continents');

  NHELP = 7;
  HelpText: array[1..NHELP] of String[44] = (
    'Ask a question and press Enter.',
    'Try: capital of peru '#250' is a whale a fish',
    '     what is 7 times 8 '#250' spell elephant',
    '     which countries border estonia',
    '     how do you say thank you in spanish',
    'F2 sound '#250' F3 robot voice '#250' F4 creativity',
    #24' last question '#250' Esc quit '#250' CLS clears');

var
  ChatX, ChatY: Integer;
  LastQ: String;
  SndLog: Text;
  SndLogOpen: Boolean;
  ActMax: array[0..MAXL - 1] of Longint;
  Heat: array[0..17] of Integer;
  HeatN: Integer;
  Speed10: Longint;                         { letters per 10 seconds }
  StatusRight: String[15];
  BootY: Integer;
  AnsX0, AnsY0, AnsCol, Spin: Integer;
  ScrPrev: Char;

{ ---- small helpers --------------------------------------------------------- }

function PadR(const S: String; W: Integer): String;
var
  T: String;
begin
  T := Copy(S, 1, W);
  while Length(T) < W do T := T + ' ';
  PadR := T;
end;

function PadL(const S: String; W: Integer): String;
var
  T: String;
begin
  T := S;
  while Length(T) < W do T := ' ' + T;
  PadL := T;
end;

function Z2(N: Integer): String;
begin
  if N < 10 then Z2 := '0' + NumStr(N) else Z2 := NumStr(N);
end;

{ keep Windows running; stop thinking if the window was closed }
procedure Idle;
begin
  Flush;
  Pump;
  if Quitting then AbortThink := True;
end;

procedure Color(A: Integer);
var
  Fg, Bg: Integer;
begin
  if Mono then
  begin
    Fg := A and 15;
    Bg := (A shr 4) and 7;
    if Bg <> 0 then A := $70
    else if Fg = 8 then A := 7
    else if Fg >= 9 then A := 15
    else A := 7;
  end;
  TextAttr := A;
end;

{ ---- sound -------------------------------------------------------------------- }

procedure Tone(Hz, Ms: Word);                { Hz 0 = silence }
begin
  if SndLogOpen then WriteLn(SndLog, Hz, ' ', Ms);
  if not SoundOn then Exit;
  if Hz > 0 then Sound(Hz);
  DelayMs(Ms);
  NoSound;
end;

procedure Quiet(Ms: Word);
begin
  if SndLogOpen then WriteLn(SndLog, '0 ', Ms);
  DelayMs(Ms);
end;

procedure Sweep(FromHz, ToHz, Ms: Word);
var
  T: Word;
begin
  T := 0;
  while T < Ms do
  begin
    Tone(Word(FromHz + (Longint(ToHz) - FromHz) * T div Ms), 3);
    Inc(T, 3);
  end;
end;

procedure SndBoot;
const
  Notes: array[0..5] of Word = (392, 523, 659, 784, 1047, 1319);
var
  I: Integer;
begin
  for I := 0 to 5 do Tone(Notes[I], 55);
  Tone(1568, 140);
end;

procedure SndReady; begin Tone(1319, 40); Tone(1760, 70); end;
procedure SndClick; begin Tone(1800, 2); end;
procedure SndError; begin Tone(140, 120); end;
procedure SndBye;   begin Sweep(1600, 200, 360); end;

(* The robot voice. Not real speech: each letter becomes a little sound
   with the rhythm of speech. Vowels buzz between two formant-like
   pitches, s/f/h hiss, p/t/k click, m/n hum. The pitch slowly falls
   through a sentence. *)

procedure Buzz(F1, F2, Ms, Shift: Word);
var
  T: Word;
begin
  F1 := Word(Longint(F1) * Shift div 100);
  F2 := Word(Longint(F2) * Shift div 100);
  if SndLogOpen then WriteLn(SndLog, 'B', F1, ' ', F2, ' ', Ms);
  if not SoundOn then
  begin
    DelayMs(Ms);
    Exit;
  end;
  T := 0;
  while T < Ms do
  begin
    Sound(F1); DelayMs(2);
    Sound(F2); DelayMs(2);
    Inc(T, 4);
  end;
  NoSound;
end;

procedure Hiss(Ms: Word);
var
  T: Word;
begin
  if SndLogOpen then WriteLn(SndLog, 'H ', Ms);
  if not SoundOn then
  begin
    DelayMs(Ms);
    Exit;
  end;
  for T := 1 to Ms do
  begin
    Sound(2500 + Random(4500));
    DelayMs(1);
  end;
  NoSound;
end;

procedure SayLetter(C: Char; Shift: Word);
begin
  if (C >= 'A') and (C <= 'Z') then C := Chr(Ord(C) + 32);
  case C of
    'a': Buzz(730, 1090, 64, Shift);
    'e': Buzz(530, 1840, 56, Shift);
    'i', 'y': Buzz(300, 2290, 52, Shift);
    'o': Buzz(570, 840, 64, Shift);
    'u': Buzz(320, 870, 56, Shift);
    's', 'z', 'c', 'x': Hiss(46);
    'f', 'h', 'v', 'j': Hiss(30);
    'p', 't', 'k', 'q': begin Tone(3200, 2); Quiet(18); end;
    'b', 'd', 'g': begin Buzz(180, 260, 12, Shift); Quiet(10); end;
    'm', 'n': Buzz(210, 300, 40, Shift);
    'l', 'r', 'w': Buzz(400, 1100, 36, Shift);
    ' ': Quiet(45);
    ',', '-': Quiet(110);
    '.', '!', '?', ':': Quiet(200);
    '0'..'9': Buzz(420 + (Ord(C) - 48) * 60, 900 + (Ord(C) - 48) * 90, 70, Shift);
  else
    Quiet(20);
  end;
end;

{ ---- drawing helpers ----------------------------------------------------------- }

procedure Full;
begin
  Window(1, 1, SCRW, 25);
end;

procedure HLine(X, Y, N: Integer; Ch: Char);
begin
  GotoXY(X, Y);
  while N > 0 do
  begin
    PutCh(Ch);
    Dec(N);
  end;
end;

procedure PutAt(X, Y, Attr: Integer; const S: String);
begin
  GotoXY(X, Y);
  Color(Attr);
  CPutS(S);
end;

procedure Box(X1, Y1, X2, Y2, Attr: Integer; const Title: String);
var
  Y: Integer;
begin
  Color(Attr);
  GotoXY(X1, Y1); PutCh(#201); HLine(X1 + 1, Y1, X2 - X1 - 1, #205); PutCh(#187);
  for Y := Y1 + 1 to Y2 - 1 do
  begin
    GotoXY(X1, Y); PutCh(#186);
    GotoXY(X2, Y); PutCh(#186);
  end;
  GotoXY(X1, Y2); PutCh(#200); HLine(X1 + 1, Y2, X2 - X1 - 1, #205);
  GotoXY(X2, Y2); PutCh(#188);
  if Title <> '' then
  begin
    PutAt(X1 + 2, Y1, Attr, #181);
    PutAt(X1 + 3, Y1, C_PANEL, Title);
    Color(Attr);
    PutCh(#198);
  end;
end;

{ a bar of W cells, V from 0 to 1000 }
procedure Meter(X, Y, W, V, Attr: Integer);
var
  I, N: Integer;
begin
  N := Integer(Longint(V) * W * 2 div 1000);
  GotoXY(X, Y);
  for I := 0 to W - 1 do
    if N >= 2 * I + 2 then begin Color(Attr); PutCh(#219); end
    else if N = 2 * I + 1 then begin Color(Attr); PutCh(#221); end
    else begin Color(C_DIM); PutCh(#250); end;
end;

function OnOff(B: Boolean): String;
begin
  if B then OnOff := 'ON ' else OnOff := 'OFF';
end;

procedure StatusBar(const Right: String; Change: Boolean);
begin
  Full;
  Color(C_BAR);
  GotoXY(1, 25);
  CPutS(' ');
  Color(C_BARKEY); CPutS('F1'); Color(C_BAR); CPutS(' Help  ');
  Color(C_BARKEY); CPutS('F2'); Color(C_BAR); CPutS(' Sound ');
  Color(C_BARON); CPutS(OnOff(SoundOn)); Color(C_BAR); CPutS('  ');
  Color(C_BARKEY); CPutS('F3'); Color(C_BAR); CPutS(' Voice ');
  Color(C_BARON); CPutS(OnOff(VoiceOn)); Color(C_BAR); CPutS('  ');
  Color(C_BARKEY); CPutS('F4'); Color(C_BAR); CPutS(' Creativity ');
  Color(C_BARON); PutCh(Chr(48 + Creativity)); Color(C_BAR); CPutS('  ');
  Color(C_BARKEY); CPutS('Esc'); Color(C_BAR); CPutS(' Quit ');
  if Change then StatusRight := Copy(Right, 1, 15);
  CPutS(PadR(StatusRight, 15));               { ends at column 79 }
end;

procedure TitleBar;
var
  Hr, Mn: Integer;
begin
  Full;
  Color(C_TITLE);
  HLine(1, 1, SCRW, ' ');
  PutAt(2, 1, C_TITLE, #17#16);
  PutAt(5, 1, C_TITLE2, 'T I N Y');
  PutAt(13, 1, C_TITLE, #250'  NEURAL INTERFACE 2.1  '#250'  367,000 WEIGHTS');
  TimeHM(Hr, Mn);
  PutAt(62, 1, $1A, #254);
  PutAt(64, 1, C_TITLE, 'ONLINE');
  PutAt(73, 1, C_TITLE2, Z2(Hr) + ':' + Z2(Mn));
end;

{ ---- the neural monitor (right panel) -------------------------------------------- }

procedure MonitorStatic;
var
  Lr: Integer;
begin
  PutAt(MON_X, 3, C_DIM, 'LAYER ACTIVITY');
  Lr := 0;
  while (Lr < L) and (Lr < 6) do
  begin
    PutAt(MON_X, 4 + Lr, C_FRAME, 'L' + NumStr(Lr + 1));
    Meter(MON_X + 3, 4 + Lr, 15, 0, C_ANSWER);
    Inc(Lr);
  end;
  PutAt(MON_X, 10, C_DIM, 'CONFIDENCE');
  Meter(MON_X, 11, 13, 0, C_ANSWER);
  PutAt(MON_X, 12, C_DIM, 'LAST LETTERS');
  PutAt(MON_X, 14, C_DIM, 'SPEED');
  PutAt(MON_X, 16, C_DIM, 'NETWORK');
  PutAt(MON_X, 17, C_TEXT, NumStr(L));
  CPutS(' layers '#250' ');
  CPutS(NumStr(D)); CPutS(' wide');
  PutAt(MON_X, 19, C_DIM, 'MODE');
end;

function ConfColor(V: Integer): Integer;
begin
  if V > 800 then ConfColor := C_ANSWER
  else if V > 500 then ConfColor := C_QTEXT
  else ConfColor := C_HOT;
end;

procedure MonitorLive;
var
  Lr, V, I: Integer;
begin
  Full;
  Lr := 0;
  while (Lr < L) and (Lr < 6) do
  begin
    if LayerLvl[Lr] > ActMax[Lr] then ActMax[Lr] := LayerLvl[Lr];
    if ActMax[Lr] > 0 then V := Integer((1000 * LayerLvl[Lr]) div ActMax[Lr]) else V := 0;
    if Odd(Lr) then Meter(MON_X + 3, 4 + Lr, 15, V, C_FRAME)
    else Meter(MON_X + 3, 4 + Lr, 15, V, C_ANSWER);
    ActMax[Lr] := ActMax[Lr] - (ActMax[Lr] + 199) div 200;   { sinks by a 200th }
    Inc(Lr);
  end;
  V := LastMil;
  Meter(MON_X, 11, 13, V, ConfColor(V));
  PutAt(MON_X + 13, 11, C_BRIGHT, ' ' + PadL(NumStr(V div 10), 3) + '%');
  GotoXY(MON_X, 13);
  for I := 0 to 17 do
    if I >= HeatN then
    begin
      Color(C_DIM);
      PutCh(#250);
    end
    else
    begin
      V := Heat[I];
      Color(ConfColor(V));
      if V > 900 then PutCh(#219)
      else if V > 700 then PutCh(#178)
      else if V > 450 then PutCh(#177)
      else PutCh(#176);
    end;
  PutAt(MON_X, 15, C_TEXT, TenthsStr(Speed10) + ' letters/s  ');
  PutAt(MON_X, 20, C_TEXT, 'creativity ' + NumStr(Creativity) + '     ');
end;

{ ---- frame ----------------------------------------------------------------------- }

procedure Frame;
begin
  Full;
  Color(C_TEXT);
  ClrScr;
  TitleBar;
  Box(1, 2, 58, 21, C_FRAME, ' CONVERSATION ');
  Box(59, 2, 80, 21, C_FRAME2, ' NEURAL MONITOR ');
  Box(1, 22, 80, 24, C_FRAME2, ' ASK TINY ');
  PutAt(3, IN_Y, C_YOU, #16);
  PutAt(59, 22, C_FRAME2, #209);
  PutAt(59, 24, C_FRAME2, #207);
  PutAt(59, IN_Y, C_FRAME2, #179);
  PutAt(62, IN_Y, C_DIM, #24' last  F1 help');
  MonitorStatic;
  MonitorLive;
  StatusBar('', False);
end;

{ ---- chat window ---------------------------------------------------------------------- }

procedure ChatWin;
begin
  Window(CHAT_L, CHAT_T, CHAT_R, CHAT_B);
  GotoXY(ChatX, ChatY);
end;

procedure ChatSave;
begin
  ChatX := WhereX;
  ChatY := WhereY;
  Full;
end;

procedure ChatNl;
begin
  CPutS(#13#10);
end;

(* make sure Lines free lines are left below the cursor (no scrolling while
   an answer is printed, so its screen position stays known) *)
procedure ChatRoom(Lines: Integer);
var
  H, Y, X: Integer;
begin
  H := CHAT_B - CHAT_T + 1;
  Y := WhereY;
  X := WhereX;
  while (Y > H - Lines + 1) and (Y > 1) do
  begin
    GotoXY(1, H);
    CPutS(#10);                             { scrolls the window up }
    Dec(Y);
  end;
  GotoXY(X, Y);
end;

procedure ChatText(Attr: Integer; const S: String; Indent: Integer);
var
  I: Integer;
begin
  Color(Attr);
  for I := 1 to Length(S) do
  begin
    if WhereX >= CHATW then
    begin
      ChatNl;
      GotoXY(Indent, WhereY);
    end;
    PutCh(S[I]);
  end;
end;

procedure DumpScreen(const Name: String);  { for testing }
var
  F: file;
begin
  Assign(F, ExeDir + Name);
  {$I-}
  Rewrite(F, 1);
  if IOResult = 0 then
  begin
    BlockWrite(F, Cells, SizeOf(Cells));
    Close(F);
    if IOResult <> 0 then ;
  end;
  {$I+}
end;

{ ---- boot screen --------------------------------------------------------------------- }

function WaitOrKey(Ms: Word): Boolean;
begin
  WaitOrKey := False;
  if Dump then Exit;
  DelayMs(Ms);
  if KeyPressed then
  begin
    ReadKey;
    WaitOrKey := True;
  end;
end;

function RandCh: Char;
begin
  RandCh := Chr(33 + Random(90));
end;

{ falling green letters, like a film computer }
procedure Rain;
var
  Col, Spd: array[0..SCRW - 1] of Integer;
  F, X, Y: Integer;
begin
  for X := 0 to SCRW - 1 do
  begin
    Col[X] := -Random(25);
    Spd[X] := 1 + Random(2);
  end;
  for F := 0 to 45 do
  begin
    X := 0;
    while X < SCRW - 1 do
    begin
      Y := Col[X];
      if (Y >= 1) and (Y <= 25) then
      begin
        GotoXY(X + 1, Y);
        if F < 40 then Color(C_ANSWER) else Color(C_DIM);
        PutCh(RandCh);
      end;
      if (Y + 1 >= 1) and (Y + 1 <= 25) then
      begin
        GotoXY(X + 1, Y + 1);
        Color(C_BRIGHT);
        PutCh(RandCh);
      end;
      if (Y - 7 >= 1) and (Y - 7 <= 25) then
      begin
        GotoXY(X + 1, Y - 7);
        PutCh(' ');
      end;
      Inc(Col[X], Spd[X]);
      if Col[X] > 32 then Col[X] := -Random(10);
      Inc(X, 2);
    end;
    if F mod 4 = 0 then Tone(3000 + Random(3000), 2);
    if WaitOrKey(28) then Break;
    if Quitting then Break;
  end;
  Color(C_TEXT);
  ClrScr;
end;

function IsHash(Y, X: Integer): Boolean;
begin
  IsHash := Logo[Y][X + 1] = '#';
end;

procedure Block2(X, Y, Attr: Integer; C1, C2: Char);
begin
  GotoXY(X, Y);
  Color(Attr);
  PutCh(C1);
  PutCh(C2);
end;

{ the logo appears out of random symbols, then a light sweeps over it }
procedure LogoIn;
var
  Done: array[0..4, 0..23] of Boolean;
  I, K, Y, X, N, Total: Integer;
begin
  N := 0;
  Total := 0;
  for Y := 0 to 4 do
    for X := 0 to 23 do
    begin
      Done[Y, X] := False;
      if IsHash(Y, X) then Inc(Total);
    end;
  K := 0;
  while (N < Total) and (K < 400) and not Quitting do
  begin
    for I := 0 to 4 do                      { settle five cells per frame }
    begin
      Y := Random(5); X := Random(24);
      if not IsHash(Y, X) or Done[Y, X] then Continue;
      Done[Y, X] := True;
      Inc(N);
      { shadow, one cell down and right }
      if not ((Y < 4) and (X < 23) and IsHash(Y + 1, X + 1)) then
        Block2(LOGO_X + 2 * X + 2, LOGO_Y + Y + 1, 1, #177, #177);
      Block2(LOGO_X + 2 * X, LOGO_Y + Y, LogoCol[Y], #219, #219);
    end;
    for I := 0 to 5 do                      { flicker in some noise }
    begin
      Y := Random(5); X := Random(24);
      if not IsHash(Y, X) or Done[Y, X] then Continue;
      Block2(LOGO_X + 2 * X, LOGO_Y + Y, C_DIM, Chr(176 + Random(3)), Chr(176 + Random(3)));
    end;
    if K mod 3 = 0 then Tone(200 + N * 12, 3);
    if not Dump then DelayMs(12);
    Inc(K);
  end;
  for Y := 0 to 4 do                        { finish anything left }
    for X := 0 to 23 do
      if IsHash(Y, X) then
        Block2(LOGO_X + 2 * X, LOGO_Y + Y, LogoCol[Y], #219, #219);
  X := 0;
  while (X < 26) and not Dump and not Quitting do  { light sweep }
  begin
    for Y := 0 to 4 do
    begin
      if (X < 24) and IsHash(Y, X) then
        Block2(LOGO_X + 2 * X, LOGO_Y + Y, C_BRIGHT, #219, #219);
      if (X >= 2) and IsHash(Y, X - 2) then
        Block2(LOGO_X + 2 * (X - 2), LOGO_Y + Y, LogoCol[Y], #219, #219);
    end;
    DelayMs(14);
    Inc(X);
  end;
end;

procedure BootBar(DoneT, TotalT: Integer);
var
  I, N: Integer;
  S: String;
begin
  N := Integer(36 * Longint(DoneT) div TotalT);
  Full;
  GotoXY(22, 15);
  Color(C_FRAME);
  PutCh(#222);
  for I := 0 to 35 do
  begin
    if I < N then
    begin
      if I * 3 < N then Color(C_FRAME) else Color(C_ANSWER);
      PutCh(#219);
    end
    else
    begin
      Color(C_DIM);
      PutCh(#250);
    end;
  end;
  Color(C_FRAME);
  PutCh(#221);
  Color(C_BRIGHT);
  CPutS(' ' + PadL(NumStr(100 * Longint(DoneT) div TotalT), 3) + '%');
  if (DoneT = 2) or ((DoneT > 2) and ((DoneT - 2) mod 6 = 0)) then
  begin
    if DoneT = 2 then S := 'letters + places'
    else S := 'layer ' + NumStr((DoneT - 2) div 6) + ' of ' + NumStr(L);
    GotoXY(26, BootY);
    Color(C_YOU); CPutS(#16' ');
    Color(C_TEXT); CPutS(S);
    CPutS(' ');
    I := WhereX;
    Color(C_DIM); HLine(I, BootY, 50 - I, #250);
    Color(C_ANSWER); CPutS(' ONLINE');
    Inc(BootY);
    Tone(880 + 110 * (BootY mod 6), 12);
  end;
  Idle;
end;

procedure Boot;
var
  X: Integer;
begin
  Color(C_TEXT);
  ClrScr;
  Cursor(False);
  Rain;
  LogoIn;
  PutAt(24, 8, C_BRIGHT, 'N E U R A L    I N T E R F A C E');
  PutAt(29, 9, C_DIM, 'version 2.1  '#250'  Delphi 1');
  Color(C_FRAME2);
  HLine(10, 11, 60, #196);
  PutAt(22, 13, C_FRAME, 'LOADING NEURAL WEIGHTS FROM TINY.BIN');
  BootY := 17;
  OnLoad := BootBar;
  LoadModel(ExeDir + 'TINY.BIN');
  AllocMemory;
  OnLoad := nil;
  SndBoot;
  for X := 0 to 5 do
  begin
    if Odd(X) then PutAt(30, BootY + 1, C_BRIGHT, #16' SYSTEM  READY '#17)
    else PutAt(30, BootY + 1, C_ANSWER, #16' SYSTEM  READY '#17);
    if not Dump then DelayMs(120);
  end;
  if Dump then DumpScreen('BOOT.DMP');
end;

{ ---- help ----------------------------------------------------------------------- }

procedure ShowHelp;
var
  I: Integer;
begin
  ChatWin;
  if WhereX > 1 then ChatNl;
  ChatRoom(9);
  Color(C_PANEL); CPutS(' HELP '); ChatNl;
  for I := 1 to NHELP do
  begin
    Color(C_TEXT); CPutS(' '); CPutS(HelpText[I]); ChatNl;
  end;
  ChatSave;
end;

{ ---- asking ---------------------------------------------------------------------- }

{ where letter I of the answer is on the screen }
procedure AnsPos(I: Integer; var SX, SY: Integer);
var
  Per: Integer;
begin
  Per := CHATW - AnsX0;                     { letters per line }
  SX := CHAT_L + AnsX0 - 1 + I mod Per;
  SY := CHAT_T + AnsY0 - 1 + I div Per;
end;

{ a scanner sweeps back and forth while TINY reads the question }
procedure UiStep(I, N: Integer);
var
  K, Head, SX, SY, Dd: Integer;
begin
  Full;
  Head := Spin mod 18;
  if Head >= 9 then Head := 17 - Head;
  AnsPos(0, SX, SY);
  GotoXY(SX, SY);
  for K := 0 to 9 do
  begin
    Dd := Abs(Head - K);
    case Dd of
      0: begin Color(C_BRIGHT); PutCh(#219); end;
      1: begin Color(C_YOU); PutCh(#178); end;
      2: begin Color(5); PutCh(#177); end;
    else
      begin Color(C_DIM); PutCh(#250); end;
    end;
  end;
  Color(C_DIM);
  CPutS(' reading ' + NumStr(100 * Longint(I + 1) div N) + '%');
  Inc(Spin);
  MonitorLive;
  if I mod 3 = 0 then Tone(2400 + Random(8) * 150, 3);
end;

procedure UiLetter(C: Integer);
var
  X, Y, K, V: Integer;
begin
  Full;
  if AnsCol = 0 then                        { erase the scanner }
  begin
    AnsPos(0, X, Y);
    GotoXY(X, Y);
    Color(C_TEXT);
    CPutS('                       ');
  end
  else                                      { last letter stops glowing }
  begin
    AnsPos(AnsCol - 1, X, Y);
    GotoXY(X, Y);
    Color(C_ANSWER);
    PutCh(ScrPrev);
  end;
  AnsPos(AnsCol, X, Y);
  if C <> 32 then                           { decode flicker }
  begin
    GotoXY(X, Y);
    Color(C_FRAME);
    PutCh(RandCh);
    if not Dump then DelayMs(10);
  end;
  GotoXY(X, Y);
  Color(C_GLOW);
  PutCh(Chr(C));
  ScrPrev := Chr(C);
  Inc(AnsCol);
  V := LastMil;
  if HeatN < 18 then
  begin
    Heat[HeatN] := V;
    Inc(HeatN);
  end
  else
  begin
    for K := 0 to 16 do Heat[K] := Heat[K + 1];
    Heat[17] := V;
  end;
  MonitorLive;
  if not VoiceOn then Tone(900 + (C mod 16) * 70, 6);
end;

procedure Speak(const A: String);
var
  I, J, K, SX, SY, N: Integer;
  Shift: Word;
begin
  Full;
  N := Length(A);
  I := 1;
  while I <= N do
  begin
    J := I;
    while (J <= N) and (A[J] <> ' ') do Inc(J);  { one word: I..J-1 }
    while (J <= N) and (A[J] = ' ') do Inc(J);
    Color(C_SPEAK);
    K := I;
    while (K < J) and (A[K] <> ' ') do
    begin
      AnsPos(K - 1, SX, SY);
      GotoXY(SX, SY);
      PutCh(A[K]);
      Inc(K);
    end;
    Shift := Word(115 - 30 * Longint(I - 1) div (N + 1));
    for K := I to J - 1 do
    begin
      if KeyPressed then
      begin
        Shift := 0;
        Break;
      end;
      SayLetter(A[K], Shift);
    end;
    Color(C_ANSWER);
    K := I;
    while (K < J) and (A[K] <> ' ') do
    begin
      AnsPos(K - 1, SX, SY);
      GotoXY(SX, SY);
      PutCh(A[K]);
      Inc(K);
    end;
    if Shift = 0 then Break;                { a key stops the voice }
    I := J;
  end;
end;

procedure Ask(const Q: String);
var
  Answer: String;
  Tenths: Longint;
  Letters, SX, SY: Integer;
begin
  ChatWin;
  if WhereX > 1 then ChatNl;
  if WhereY > 1 then ChatNl;                { empty line between turns }
  ChatRoom(6);
  Color(C_YOU); CPutS(' YOU '#175' ');
  ChatText(C_QTEXT, Q, 8);
  ChatNl;
  Color(C_TINY); CPutS('TINY '#175' ');
  AnsX0 := WhereX;
  AnsY0 := WhereY;
  AnsCol := 0;
  HeatN := 0;
  ChatSave;
  Cursor(False);
  StatusBar('thinking...', True);
  Letters := Think(Q, Answer, Tenths, UiStep, UiLetter);
  if Quitting then Exit;
  if Letters = 0 then
  begin
    UiLetter(Ord('.'));
    Answer := '.';
    Letters := 1;
  end;
  AnsPos(AnsCol - 1, SX, SY);               { last letter stops glowing }
  GotoXY(SX, SY); Color(C_ANSWER); PutCh(ScrPrev);
  if Tenths > 0 then Speed10 := 100 * Longint(Letters) div Tenths else Speed10 := 0;
  StatusBar(NumStr(Letters) + ' ltr ' + TenthsStr(Tenths) + 's', True);
  MonitorLive;
  if SoundOn and VoiceOn then
  begin
    Tone(1200, 8);
    Speak(Answer);
  end
  else
    SndReady;
  ChatX := 1;
  ChatY := SY - CHAT_T + 2;
  ChatWin;
  ChatSave;
  TitleBar;
  Cursor(True);
end;

{ ---- typing ---------------------------------------------------------------------- }

procedure DrawInput(const Buf: String);
const
  W = 54;                                   { visible part of the line }
var
  N, M: Integer;
begin
  Full;
  N := Length(Buf);
  if N > W then M := W else M := N;
  GotoXY(5, IN_Y);
  Color(C_BRIGHT);
  if N > W then CPutS(Copy(Buf, N - W + 1, W)) else CPutS(Buf);
  Color(C_TEXT);
  HLine(5 + M, IN_Y, 55 - M, ' ');
  GotoXY(5 + M, IN_Y);
end;

{ read a line; returns -1 for Esc }
function ReadLine(var Buf: String): Integer;
var
  C: Integer;
begin
  Buf := '';
  DrawInput(Buf);
  while True do
  begin
    C := ReadKey;
    if C = K_ENTER then
    begin
      ReadLine := Length(Buf);
      Exit;
    end;
    if C = K_ESC then
    begin
      ReadLine := -1;
      Exit;
    end;
    if C = K_BS then
    begin
      if Length(Buf) > 0 then
      begin
        Delete(Buf, Length(Buf), 1);
        SndClick;
      end;
    end
    else if C = K_UP then
      Buf := LastQ
    else if C = K_F1 then
      ShowHelp
    else if C = K_F2 then
    begin
      SoundOn := not SoundOn;
      SndClick;
    end
    else if C = K_F3 then
    begin
      VoiceOn := not VoiceOn;
      SndClick;
    end
    else if C = K_F4 then
    begin
      Creativity := (Creativity + 1) mod 10;
      SndClick;
      MonitorLive;
    end
    else if (C >= 32) and (C <= 126) then
    begin
      if Length(Buf) < MAXQ then
      begin
        Buf := Buf + Chr(C);
        SndClick;
      end
      else
        SndError;
    end;
    StatusBar('', False);
    DrawInput(Buf);
  end;
end;

{ ---- demo mode --------------------------------------------------------------------- }

procedure DemoType(const Q: String);
var
  N: Integer;
begin
  for N := 1 to Length(Q) do
  begin
    DrawInput(Copy(Q, 1, N));
    SndClick;
    if not Dump then DelayMs(45 + Random(50));
  end;
  if not Dump then DelayMs(250);
  DrawInput('');
end;

function UiMain: Integer;
var
  Line, Q: String;
  I, N: Integer;
begin
  UiMain := 0;
  if Dump then
  begin
    Assign(SndLog, ExeDir + 'SOUND.LOG');
    {$I-}
    Rewrite(SndLog);
    {$I+}
    SndLogOpen := IOResult = 0;
  end;
  Boot;
  if Quitting then Exit;
  if not Demo and not Dump then
  begin
    PutAt(29, BootY + 3, C_DIM, 'press any key to begin');
    if ReadKey = K_ESC then Exit;
  end;
  Sweep(300, 1400, 120);
  Frame;
  Cursor(True);
  ChatWin;
  Color(C_DIM);
  CPutS('Hello! I am TINY, a neural network in your computer.');
  ChatNl;
  CPutS('Ask about countries, animals, space, words or sums.');
  ChatNl;
  ChatSave;
  SndReady;

  if Demo or Dump then
  begin
    for I := 1 to NDEMO do
    begin
      if KeyPressed then
      begin
        ReadKey;
        Break;
      end;
      DemoType(DemoQ[I]);
      Ask(DemoQ[I]);
      if Quitting then Exit;
      if Dump and not DumpAll and (I = 4) then Break;
      if not Dump then DelayMs(1500);
    end;
    if Dump then
    begin
      DumpScreen('SCREEN.DMP');
      if SndLogOpen then Close(SndLog);
      SndLogOpen := False;
      Exit;
    end;
  end;
  while not Quitting do
  begin
    N := ReadLine(Line);
    if N < 0 then Break;
    DrawInput('');
    if Clean(Line, Q) = 0 then Continue;
    if IsWord(Q, 'quit') or IsWord(Q, 'exit') then Break;
    if IsWord(Q, 'cls') then
    begin
      Frame;
      ChatX := 1;
      ChatY := 1;
      Continue;
    end;
    if IsWord(Q, 'help') then
    begin
      ShowHelp;
      Continue;
    end;
    LastQ := Q;
    Ask(Q);
  end;
  if not Quitting then
  begin
    StatusBar('goodbye', True);
    SndBye;
  end;
end;

begin
  Mono := False;
  Neon := True;
  SoundOn := True;
  VoiceOn := True;
  Demo := False;
  Dump := False;
  DumpAll := False;
  ChatX := 1;
  ChatY := 1;
  LastQ := '';
  SndLogOpen := False;
  HeatN := 0;
  Speed10 := 0;
  StatusRight := '';
  Spin := 0;
  ScrPrev := ' ';
  FillChar(ActMax, SizeOf(ActMax), 0);
end.
