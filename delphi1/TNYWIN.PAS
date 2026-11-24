unit TnyWin;

(* TINY 2.1 for Delphi 1 - the Windows 3.1 side.

   The DOS original draws on the 80 x 25 text screen with Turbo C's conio
   functions. This unit gives TINY the same thing inside a window: an
   80 x 25 cell buffer with conio-style text windows, cursor, scrolling and
   colours, drawn with the OEM "Terminal" font (which has the DOS box and
   block characters). It also gives a key queue, millisecond delays
   (MMSYSTEM timer) and the PC speaker.

   The program runs its own loops instead of an event loop: every wait
   (KeyPressed, ReadKey, DelayMs, Pump) handles the window's messages, so
   Windows 3.1 keeps running while TINY thinks.

   Written with plain WinTypes/WinProcs calls (no VCL, no DFM files).
   Also compiles with Free Pascal's win16 target. *)

{$IFDEF FPC} {$MODE TP} {$ENDIF}
{$F+,R-,S-,X+}

interface

{ Delphi 1 keeps the WM_ message numbers in Messages }
{$IFDEF FPC}
uses WinTypes, WinProcs;
{$ELSE}
uses WinTypes, WinProcs, Messages;
{$ENDIF}

const
  K_ESC   = 27;
  K_ENTER = 13;
  K_BS    = 8;
  K_F1    = 256 + 59;
  K_F2    = 256 + 60;
  K_F3    = 256 + 61;
  K_F4    = 256 + 62;
  K_UP    = 256 + 72;

  PAL_NEON    = 0;
  PAL_CLASSIC = 1;
  PAL_MONO    = 2;

type
  TCells = array[0..1999] of Word;          { char + attr shl 8, row by row }

var
  TextAttr: Byte;
  Cells: TCells;
  Quitting: Boolean;                        { the window was closed }
  MainWnd: HWnd;

procedure ScrOpen(Palette: Integer);
procedure ScrClose;
procedure SetPalette(Palette: Integer);
procedure Window(X1, Y1, X2, Y2: Integer);
procedure GotoXY(X, Y: Integer);
function WhereX: Integer;
function WhereY: Integer;
procedure PutCh(C: Char);
procedure CPutS(const S: String);
procedure ClrScr;
procedure Flush;
procedure Cursor(Visible: Boolean);

procedure Pump;
function KeyPressed: Boolean;
function ReadKey: Integer;

function Clock: Longint;
procedure DelayMs(Ms: Word);
procedure Sound(Hz: Word);
procedure NoSound;
procedure TimeHM(var Hour, Minute: Integer);
function HasFpu: Boolean;
procedure ShowBox(const Text, Title: String; Error: Boolean);
function ExeDir: String;

implementation

{ MMSYSTEM.DLL timer (Windows 3.1), imported by ordinal }
{$IFDEF FPC}
function timeGetTime: Longint; external 'MMSYSTEM' index 607;
function timeBeginPeriod(Period: Word): Word; external 'MMSYSTEM' index 605;
function timeEndPeriod(Period: Word): Word; external 'MMSYSTEM' index 606;
{$ELSE}
function timeGetTime: Longint; far; external 'MMSYSTEM' index 607;
function timeBeginPeriod(Period: Word): Word; far; external 'MMSYSTEM' index 605;
function timeEndPeriod(Period: Word): Word; far; external 'MMSYSTEM' index 606;
{$ENDIF}

const
  ClassName = 'TINY21';

  { the neon colours of the original, VGA 0..63 per channel }
  NeonRGB: array[0..15, 0..2] of Byte = (
    (1, 1, 7),    (5, 7, 22),   (0, 26, 18),  (0, 20, 30),
    (40, 4, 12),  (28, 6, 40),  (42, 26, 4),  (40, 45, 54),
    (13, 16, 28), (18, 34, 63), (18, 63, 42), (10, 57, 63),
    (63, 22, 34), (63, 18, 58), (63, 54, 14), (60, 62, 63));

  { standard VGA text colours }
  VgaRGB: array[0..15, 0..2] of Byte = (
    (0, 0, 0),    (0, 0, 42),   (0, 42, 0),   (0, 42, 42),
    (42, 0, 0),   (42, 0, 42),  (42, 21, 0),  (42, 42, 42),
    (21, 21, 21), (21, 21, 63), (21, 63, 21), (21, 63, 63),
    (63, 21, 21), (63, 21, 63), (63, 63, 21), (63, 63, 63));

var
  Pal: array[0..15, 0..2] of Byte;          { 0..255 per channel }
  Dirty: array[0..1999] of Boolean;
  AnyDirty: Boolean;
  WinL, WinT, WinR, WinB: Integer;          { text window, 1-based }
  CurX, CurY: Integer;                      { cursor, 1-based, screen }
  Font: HFont;
  CW, CH, OX, OY: Integer;                  { cell size, grid offset }
  HasFocus, CaretOn, CaretShown: Boolean;
  Keys: array[0..31] of Integer;
  KeyHead, KeyTail: Integer;
  PBuf1, PBuf2: array[0..255] of Char;

function PStr(const S: String; var Buf: array of Char): PChar;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    Buf[I - 1] := S[I];
  Buf[Length(S)] := #0;
  PStr := @Buf[0];
end;

{ ---- colours ----------------------------------------------------------- }

procedure SetPalette(Palette: Integer);
var
  I, K: Integer;
begin
  for I := 0 to 15 do
    for K := 0 to 2 do
      if Palette = PAL_NEON then
        Pal[I, K] := (Word(NeonRGB[I, K]) * 255) div 63
      else
        Pal[I, K] := (Word(VgaRGB[I, K]) * 255) div 63;
  for I := 0 to 1999 do Dirty[I] := True;
  AnyDirty := True;
  if MainWnd <> 0 then InvalidateRect(MainWnd, nil, False);
end;

{ colour A mixed with colour B: Part/4 of A }
function Mix(A, B, Part: Integer): Longint;
var
  K: Integer;
  C: array[0..2] of Longint;
begin
  for K := 0 to 2 do
    C[K] := (Longint(Pal[A, K]) * Part + Longint(Pal[B, K]) * (4 - Part)) div 4;
  Mix := C[0] or (C[1] shl 8) or (C[2] shl 16);
end;

function Rgb(A: Integer): Longint;
begin
  Rgb := Mix(A, A, 4);
end;

{ ---- the cell buffer (conio) -------------------------------------------- }

procedure SetCell(X, Y: Integer; C: Char; A: Byte);
var
  I: Integer;
  V: Word;
begin
  I := (Y - 1) * 80 + (X - 1);
  V := Ord(C) or (Word(A) shl 8);
  if Cells[I] <> V then
  begin
    Cells[I] := V;
    Dirty[I] := True;
    AnyDirty := True;
  end;
end;

procedure Window(X1, Y1, X2, Y2: Integer);
begin
  if (X1 < 1) or (Y1 < 1) or (X2 > 80) or (Y2 > 25) or (X1 > X2) or (Y1 > Y2) then
    Exit;
  WinL := X1; WinT := Y1; WinR := X2; WinB := Y2;
  CurX := X1; CurY := Y1;
end;

procedure GotoXY(X, Y: Integer);
begin
  if (X < 1) or (Y < 1) or (X > WinR - WinL + 1) or (Y > WinB - WinT + 1) then
    Exit;
  CurX := WinL + X - 1;
  CurY := WinT + Y - 1;
end;

function WhereX: Integer;
begin
  WhereX := CurX - WinL + 1;
end;

function WhereY: Integer;
begin
  WhereY := CurY - WinT + 1;
end;

procedure ScrollUp;
var
  X, Y: Integer;
begin
  for Y := WinT to WinB - 1 do
    for X := WinL to WinR do
      SetCell(X, Y, Chr(Lo(Cells[Y * 80 + X - 1])), Hi(Cells[Y * 80 + X - 1]));
  for X := WinL to WinR do
    SetCell(X, WinB, ' ', TextAttr);
end;

procedure LineFeed;
begin
  if CurY < WinB then Inc(CurY) else ScrollUp;
end;

{ like Turbo C's putch: CR, LF (down only), wraps at the window edge }
procedure PutCh(C: Char);
begin
  case C of
    #13: CurX := WinL;
    #10: LineFeed;
    #7:  ;
    #8:  if CurX > WinL then Dec(CurX);
  else
    SetCell(CurX, CurY, C, TextAttr);
    Inc(CurX);
    if CurX > WinR then
    begin
      CurX := WinL;
      LineFeed;
    end;
  end;
end;

procedure CPutS(const S: String);
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    PutCh(S[I]);
end;

procedure ClrScr;
var
  X, Y: Integer;
begin
  for Y := WinT to WinB do
    for X := WinL to WinR do
      SetCell(X, Y, ' ', TextAttr);
  CurX := WinL;
  CurY := WinT;
end;

{ ---- drawing -------------------------------------------------------------- }

procedure FillCell(DC: HDC; X, Y, W, H: Integer; Color: Longint);
var
  R: TRect;
  B: HBrush;
begin
  R.Left := X; R.Top := Y; R.Right := X + W; R.Bottom := Y + H;
  B := CreateSolidBrush(Color);
  FillRect(DC, R, B);
  DeleteObject(B);
end;

{ a block or shade character, drawn as rectangles }
function DrawBlock(DC: HDC; X, Y: Integer; C, Fg, Bg: Integer): Boolean;
var
  H2, W2: Integer;
begin
  DrawBlock := True;
  H2 := CH div 2;
  W2 := CW div 2;
  case C of
    176: FillCell(DC, X, Y, CW, CH, Mix(Fg, Bg, 1));
    177: FillCell(DC, X, Y, CW, CH, Mix(Fg, Bg, 2));
    178: FillCell(DC, X, Y, CW, CH, Mix(Fg, Bg, 3));
    219: FillCell(DC, X, Y, CW, CH, Rgb(Fg));
    220: begin
           FillCell(DC, X, Y, CW, H2, Rgb(Bg));
           FillCell(DC, X, Y + H2, CW, CH - H2, Rgb(Fg));
         end;
    223: begin
           FillCell(DC, X, Y, CW, H2, Rgb(Fg));
           FillCell(DC, X, Y + H2, CW, CH - H2, Rgb(Bg));
         end;
    221: begin
           FillCell(DC, X, Y, W2, CH, Rgb(Fg));
           FillCell(DC, X + W2, Y, CW - W2, CH, Rgb(Bg));
         end;
    222: begin
           FillCell(DC, X, Y, W2, CH, Rgb(Bg));
           FillCell(DC, X + W2, Y, CW - W2, CH, Rgb(Fg));
         end;
  else
    DrawBlock := False;
  end;
end;

{ draw cells X1..X2 (0-based) of row Y (0-based) }
procedure DrawSpan(DC: HDC; Y, X1, X2: Integer);
var
  X, N, Start, A, C: Integer;
  Buf: array[0..79] of Char;
begin
  X := X1;
  while X <= X2 do
  begin
    A := Hi(Cells[Y * 80 + X]);
    C := Lo(Cells[Y * 80 + X]);
    if DrawBlock(DC, OX + X * CW, OY + Y * CH, C, A and 15, A shr 4) then
      Inc(X)
    else
    begin
      { a run of text with the same colours }
      Start := X;
      N := 0;
      while (X <= X2) and (Hi(Cells[Y * 80 + X]) = A) and
            not (Lo(Cells[Y * 80 + X]) in [176..178, 219..223]) do
      begin
        Buf[N] := Chr(Lo(Cells[Y * 80 + X]));
        Inc(N);
        Inc(X);
      end;
      SetTextColor(DC, Rgb(A and 15));
      SetBkColor(DC, Rgb(A shr 4));
      TextOut(DC, OX + Start * CW, OY + Y * CH, @Buf[0], N);
    end;
  end;
end;

procedure PlaceCaret;
begin
  if HasFocus then
    SetCaretPos(OX + (CurX - 1) * CW, OY + CurY * CH - 2);
end;

procedure DrawDirty(DC: HDC);
var
  Y, X, X1, X2: Integer;
  OldFont: HFont;
begin
  OldFont := SelectObject(DC, Font);
  SetBkMode(DC, OPAQUE);
  for Y := 0 to 24 do
  begin
    X1 := -1;
    X2 := -1;
    for X := 0 to 79 do
      if Dirty[Y * 80 + X] then
      begin
        if X1 < 0 then X1 := X;
        X2 := X;
        Dirty[Y * 80 + X] := False;
      end;
    if X1 >= 0 then
      DrawSpan(DC, Y, X1, X2);
  end;
  SelectObject(DC, OldFont);
  AnyDirty := False;
end;

{ show what changed }
procedure Flush;
var
  DC: HDC;
begin
  if MainWnd = 0 then Exit;
  if AnyDirty then
  begin
    if CaretShown then HideCaret(MainWnd);
    DC := GetDC(MainWnd);
    DrawDirty(DC);
    ReleaseDC(MainWnd, DC);
    if CaretShown then ShowCaret(MainWnd);
  end;
  PlaceCaret;
end;

procedure Paint;
var
  PS: TPaintStruct;
  DC: HDC;
  R: TRect;
  I: Integer;
  B: HBrush;
begin
  DC := BeginPaint(MainWnd, PS);
  GetClientRect(MainWnd, R);
  B := CreateSolidBrush(Rgb(0));
  FillRect(DC, R, B);
  DeleteObject(B);
  for I := 0 to 1999 do Dirty[I] := True;
  DrawDirty(DC);
  EndPaint(MainWnd, PS);
end;

procedure ShowTheCaret(Show: Boolean);
begin
  if not HasFocus then
  begin
    CaretShown := False;
    Exit;
  end;
  if Show and not CaretShown then
  begin
    PlaceCaret;
    ShowCaret(MainWnd);
    CaretShown := True;
  end
  else if not Show and CaretShown then
  begin
    HideCaret(MainWnd);
    CaretShown := False;
  end;
end;

procedure Cursor(Visible: Boolean);
begin
  CaretOn := Visible;
  ShowTheCaret(Visible);
end;

{ ---- the window ------------------------------------------------------------ }

procedure PushKey(K: Integer);
var
  N: Integer;
begin
  N := (KeyTail + 1) and 31;
  if N <> KeyHead then
  begin
    Keys[KeyTail] := K;
    KeyTail := N;
  end;
end;

function WndProc(Wnd: HWnd; Msg, WParam: Word; LParam: Longint): Longint;
  {$IFDEF FPC} far; {$ENDIF} export;
var
  R: TRect;
begin
  WndProc := 0;
  case Msg of
    WM_PAINT:
      Paint;
    WM_ERASEBKGND:
      WndProc := 1;
    WM_SIZE:
      begin
        GetClientRect(Wnd, R);
        OX := (R.Right - 80 * CW) div 2;
        OY := (R.Bottom - 25 * CH) div 2;
        if OX < 0 then OX := 0;
        if OY < 0 then OY := 0;
        InvalidateRect(Wnd, nil, False);
      end;
    WM_SETFOCUS:
      begin
        HasFocus := True;
        CreateCaret(Wnd, 0, CW, 2);
        CaretShown := False;
        ShowTheCaret(CaretOn);
      end;
    WM_KILLFOCUS:
      begin
        HasFocus := False;
        CaretShown := False;
        DestroyCaret;
      end;
    WM_KEYDOWN:
      case WParam of
        VK_F1: PushKey(K_F1);
        VK_F2: PushKey(K_F2);
        VK_F3: PushKey(K_F3);
        VK_F4: PushKey(K_F4);
        VK_UP: PushKey(K_UP);
      else
        WndProc := DefWindowProc(Wnd, Msg, WParam, LParam);
      end;
    WM_CHAR:
      if (WParam = K_ENTER) or (WParam = K_ESC) or (WParam = K_BS) or
         ((WParam >= 32) and (WParam <= 126)) then
        PushKey(WParam);
    WM_CLOSE:
      begin
        Quitting := True;
        PushKey(K_ESC);
      end;
    WM_DESTROY:
      ;
  else
    WndProc := DefWindowProc(Wnd, Msg, WParam, LParam);
  end;
end;

{ choose the biggest Terminal font that fits the screen }
procedure ChooseFont(MaxW, MaxH: Integer);
const
  Sizes: array[0..5] of Integer = (24, 18, 16, 14, 12, 8);
var
  I: Integer;
  F: HFont;
  DC: HDC;
  TM: TTextMetric;
  Old: HFont;
begin
  Font := 0;
  DC := GetDC(0);
  for I := 0 to 5 do
  begin
    F := CreateFont(Sizes[I], 0, 0, 0, FW_NORMAL, 0, 0, 0, OEM_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY,
      FIXED_PITCH or FF_MODERN, 'Terminal');
    Old := SelectObject(DC, F);
    GetTextMetrics(DC, TM);
    SelectObject(DC, Old);
    if ((80 * TM.tmAveCharWidth <= MaxW) and (25 * TM.tmHeight <= MaxH)) or (I = 5) then
    begin
      Font := F;
      CW := TM.tmAveCharWidth;
      CH := TM.tmHeight;
      Break;
    end;
    DeleteObject(F);
  end;
  ReleaseDC(0, DC);
end;

procedure ScrOpen(Palette: Integer);
var
  WC: TWndClass;
  R: TRect;
  Style: Longint;
  SW, SH, Show, I: Integer;
begin
  SetPalette(Palette);
  for I := 0 to 1999 do Cells[I] := $0720;
  TextAttr := 7;
  Window(1, 1, 80, 25);
  SW := GetSystemMetrics(SM_CXSCREEN);
  SH := GetSystemMetrics(SM_CYSCREEN);
  ChooseFont(SW, SH - GetSystemMetrics(SM_CYCAPTION));
  if HPrevInst = 0 then
  begin
    WC.Style := CS_HREDRAW or CS_VREDRAW;
    {$IFDEF FPC}
    WC.lpfnWndProc := WndProc;
    {$ELSE}
    WC.lpfnWndProc := @WndProc;
    {$ENDIF}
    WC.cbClsExtra := 0;
    WC.cbWndExtra := 0;
    WC.hInstance := HInstance;
    WC.hIcon := LoadIcon(0, IDI_APPLICATION);
    WC.hCursor := LoadCursor(0, IDC_ARROW);
    WC.hbrBackground := 0;
    WC.lpszMenuName := nil;
    WC.lpszClassName := ClassName;
    RegisterClass(WC);
  end;
  Style := WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX or
    WS_MAXIMIZEBOX or WS_THICKFRAME;
  R.Left := 0; R.Top := 0; R.Right := 80 * CW; R.Bottom := 25 * CH;
  AdjustWindowRect(R, Style, False);
  MainWnd := CreateWindow(ClassName, 'TINY 2.1 - Neural Interface', Style,
    CW_USEDEFAULT, 0, R.Right - R.Left, R.Bottom - R.Top, 0, 0, HInstance, nil);
  if MainWnd = 0 then
  begin
    ShowBox('Cannot create the window.', 'TINY', True);
    Halt(1);
  end;
  { too big for the screen (640 x 480): use the whole screen }
  if (R.Right - R.Left > SW) or (R.Bottom - R.Top > SH) then
    Show := SW_SHOWMAXIMIZED
  else
    Show := SW_SHOWNORMAL;
  ShowWindow(MainWnd, Show);
  UpdateWindow(MainWnd);
  timeBeginPeriod(1);
  Pump;
end;

procedure ScrClose;
begin
  NoSound;
  if MainWnd <> 0 then
  begin
    timeEndPeriod(1);
    DestroyWindow(MainWnd);
    MainWnd := 0;
  end;
  if Font <> 0 then DeleteObject(Font);
  Font := 0;
end;

{ ---- messages and keys ------------------------------------------------------ }

procedure Pump;
var
  M: TMsg;
begin
  while PeekMessage(M, 0, 0, 0, PM_REMOVE) do
    if M.Message = WM_QUIT then
      Quitting := True
    else
    begin
      TranslateMessage(M);
      DispatchMessage(M);
    end;
end;

function KeyPressed: Boolean;
begin
  Flush;
  Pump;
  KeyPressed := (KeyHead <> KeyTail) or Quitting;
end;

function ReadKey: Integer;
begin
  Flush;
  while True do
  begin
    Pump;
    if KeyHead <> KeyTail then
    begin
      ReadKey := Keys[KeyHead];
      KeyHead := (KeyHead + 1) and 31;
      Exit;
    end;
    if Quitting then
    begin
      ReadKey := K_ESC;
      Exit;
    end;
    WaitMessage;
  end;
end;

{ ---- time and sound -------------------------------------------------------- }

function Clock: Longint;
begin
  Clock := timeGetTime;
end;

(* Wait Ms milliseconds. Short waits (the robot voice) are exact and do not
   let other programs run; longer ones keep Windows going. *)
procedure DelayMs(Ms: Word);
var
  T0: Longint;
begin
  Flush;
  T0 := timeGetTime;
  while (timeGetTime - T0 < Ms) and not Quitting do
    if Ms >= 10 then Pump;
end;

procedure Sound(Hz: Word);
var
  Dv: Word;
begin
  if Hz < 20 then Exit;
  Dv := Word(1193180 div Hz);
  asm
        mov   al, 0B6h
        out   43h, al
        mov   ax, Dv
        out   42h, al
        mov   al, ah
        out   42h, al
        in    al, 61h
        or    al, 3
        out   61h, al
  end;
end;

procedure NoSound;
begin
  asm
        in    al, 61h
        and   al, 0FCh
        out   61h, al
  end;
end;

procedure TimeHM(var Hour, Minute: Integer);
var
  Hr, Mn: Byte;
begin
  asm
        mov   ah, 2Ch
        int   21h
        mov   Hr, ch
        mov   Mn, cl
  end;
  Hour := Hr;
  Minute := Mn;
end;

function HasFpu: Boolean;
begin
  HasFpu := (GetWinFlags and WF_80x87) <> 0;
end;

procedure ShowBox(const Text, Title: String; Error: Boolean);
var
  Flags: Word;
begin
  if Error then Flags := MB_OK or MB_ICONSTOP
  else Flags := MB_OK or MB_ICONINFORMATION;
  MessageBox(MainWnd, PStr(Text, PBuf1), PStr(Title, PBuf2), Flags);
end;

function ExeDir: String;
var
  S: String;
  I: Integer;
begin
  S := ParamStr(0);
  I := Length(S);
  while (I > 0) and (S[I] <> '\') and (S[I] <> ':') do Dec(I);
  ExeDir := Copy(S, 1, I);
end;

begin
  MainWnd := 0;
  Font := 0;
  Quitting := False;
  KeyHead := 0;
  KeyTail := 0;
  HasFocus := False;
  CaretOn := False;
  CaretShown := False;
  WinL := 1; WinT := 1; WinR := 80; WinB := 25;
  CurX := 1; CurY := 1;
end.
