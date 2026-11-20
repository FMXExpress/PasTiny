unit ConsoleScreen;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

function InteractiveConsole: Boolean;
function StartScreen: Boolean;
procedure RunScreen;

implementation

uses Classes, SysUtils, NeuralMonitor, TnyNet
  {$IFDEF MSWINDOWS}, {$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF}{$ENDIF};

const Esc = #27'[';

{$IFDEF MSWINDOWS}
var OldMode: DWORD; ScreenHandle: THandle;
{$ELSE}
type TWindowSize = record Rows, Cols, XPixels, YPixels: Word end;
function isatty(Fd: Integer): Integer; cdecl; external 'c';
function ioctl(Fd: Integer; Request: NativeUInt; var Size: TWindowSize): Integer; cdecl; external 'c';
{$ENDIF}

function InteractiveConsole: Boolean;
{$IFDEF MSWINDOWS}var Mode: DWORD;{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Result := GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), Mode) and
    GetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), Mode);
  {$ELSE}
  Result := (isatty(0) = 1) and (isatty(1) = 1);
  {$ENDIF}
end;

function StartScreen: Boolean;
{$IFDEF MSWINDOWS}
var Info: TConsoleScreenBufferInfo;
{$ELSE}
var Size: TWindowSize;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  ScreenHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  Result := InteractiveConsole and
    GetConsoleMode(ScreenHandle, OldMode) and GetConsoleScreenBufferInfo(ScreenHandle, Info);
  if Result then Result := (Info.srWindow.Right - Info.srWindow.Left >= 79) and
    (Info.srWindow.Bottom - Info.srWindow.Top >= 23);
  if Result then Result := SetConsoleMode(ScreenHandle, OldMode or 4);
  {$ELSE}
  Result := InteractiveConsole and
    (GetEnvironmentVariable('TERM') <> 'dumb') and
    (ioctl(1, $5413, Size) = 0) and (Size.Cols >= 80) and (Size.Rows >= 24);
  {$ENDIF}
end;

type
  TScreen = class
    Prompt: string;
    procedure Paint;
  end;

procedure At(Row, Col: Integer; const S: string);
begin
  Write(Esc, Row, ';', Col, 'H', S);
end;

procedure TScreen.Paint;
var Rows: TStringList; I: Integer; Answer, Line: string;
begin
  Rows := TStringList.Create;
  try
    Line := MonitorText;
    for I := 1 to Length(Line) do
      case Ord(Line[I]) of
        $2588: Line[I] := '#';
        $2593: Line[I] := '*';
        $2592: Line[I] := '+';
        $2591: Line[I] := '.';
      end;
    Rows.Text := Line;
    for I := 0 to Rows.Count-1 do begin
      Line := Rows[I];
      At(3+I, 55, Esc+'36m| '+Esc+'32m'+Line+Esc+'0m'+Esc+'K');
    end;
  finally
    Rows.Free;
  end;
  At(3, 2, Esc+'36mCONVERSATION'+Esc+'0m');
  At(5, 2, Copy(Prompt, 1, 50));
  At(6, 2, Copy(Prompt, 51, 50));
  Answer := GeneratedText;
  for I := 0 to (Length(Answer) div 50) do
    At(8+I, 2, Esc+'32m'+Copy(Answer, 1+50*I, 50)+Esc+'0m');
  Flush(Output);
end;

procedure RunScreen;
var Screen: TScreen; Line, Q, Answer: string; Tenths: Longint;
begin
  Screen := TScreen.Create;
  try
    Write(Esc, '?1049h', Esc, '2J');
    BeginMonitor(nil);
    EndMonitor;
    while True do begin
      At(1, 2, Esc+'1;36mTINY 2.1'+Esc+'0m');
      Screen.Paint;
      At(22, 2, 'ASK TINY   |   Type QUIT to exit');
      At(23, 2, '> '+Esc+'K');
      Flush(Output);
      if Eof(Input) then Break;
      ReadLn(Line);
      if Clean(Line, Q) = 0 then Continue;
      if IsWord(Q, 'quit') or IsWord(Q, 'exit') then Break;
      Write(Esc, '2J');
      At(1, 2, Esc+'1;36mTINY 2.1'+Esc+'0m');
      Screen.Prompt := Q;
      BeginMonitor(Screen.Paint);
      try
        Screen.Paint;
        Think(Q, Answer, Tenths, nil, MonitorLetter);
      finally
        EndMonitor;
      end;
      Screen.Paint;
      if Assigned(OnAnswer) then OnAnswer(Answer);
    end;
  finally
    Write(Esc, '0m', Esc, '?1049l');
    Flush(Output);
    {$IFDEF MSWINDOWS}SetConsoleMode(ScreenHandle, OldMode);{$ENDIF}
    Screen.Free;
  end;
end;

end.
