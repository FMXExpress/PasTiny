program TinyConsole;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ELSE}{$APPTYPE CONSOLE}{$ENDIF}

uses
  {$IFDEF FPC}SysUtils,{$ELSE}System.SysUtils,{$ENDIF}
  {$IFNDEF FPC}Winapi.Windows,{$ENDIF}
  DesktopVoice,
  TnyNet in 'TNYNET.PAS';

var
  I: Integer;
  Arg, InputName, OutputName, ModelName: string;
  Bench: Boolean;
  Fin, Fout: TextFile;

function Clock: Longint;
begin
  Result := Longint(GetTickCount64 and $7FFFFFFF);
end;

procedure ModelError(const Msg: string);
begin
  raise Exception.Create(Msg);
end;

procedure Usage;
begin
  Writeln('TinyConsole [0..9] [/SOUND] [/FLOAT] [/BENCH] [/IN=file] [/OUT=file] [/MODEL=file]');
end;

procedure Run(var Dest: TextFile);
begin
  if Bench then
    RunBench(Dest, {$IFDEF FPC}'Free Pascal'{$ELSE}'Delphi'{$ENDIF}, -1)
  else if InputName = '' then
    PlainRun(Input, Dest)
  else begin
    AssignFile(Fin, InputName);
    Reset(Fin);
    try
      PlainRun(Fin, Dest);
    finally
      CloseFile(Fin);
    end;
  end;
end;

begin
  try
    ModelName := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'TINY.BIN';
    for I := 1 to ParamCount do begin
      Arg := ParamStr(I);
      if (Length(Arg) = 1) and (Arg[1] >= '0') and (Arg[1] <= '9') then
        Creativity := Ord(Arg[1]) - Ord('0')
      else if SameText(Arg, '/SOUND') then OnAnswer := PlayConsoleVoice
      else if SameText(Arg, '/FLOAT') then UseInt := False
      else if SameText(Arg, '/BENCH') then Bench := True
      else if SameText(Copy(Arg, 1, 4), '/IN=') and (Length(Arg) > 4) then InputName := Copy(Arg, 5, MaxInt)
      else if SameText(Copy(Arg, 1, 5), '/OUT=') and (Length(Arg) > 5) then OutputName := Copy(Arg, 6, MaxInt)
      else if SameText(Copy(Arg, 1, 7), '/MODEL=') and (Length(Arg) > 7) then ModelName := Copy(Arg, 8, MaxInt)
      else if (Arg = '/?') or (Arg = '--help') then begin Usage; Halt(0) end
      else begin Usage; Halt(2) end;
    end;
    if (OutputName <> '') and
       (SameFileName(ExpandFileName(OutputName), ExpandFileName(ModelName)) or
       ((InputName <> '') and SameFileName(ExpandFileName(OutputName), ExpandFileName(InputName)))) then
      raise Exception.Create('Choose an output file separate from the model and input.');
    Randomize;
    ClockMs := Clock;
    OnFail := ModelError;
    LoadModel(ModelName);
    AllocMemory;
    if OutputName = '' then Run(Output)
    else begin
      AssignFile(Fout, OutputName);
      Rewrite(Fout);
      try
        Run(Fout);
      finally
        CloseFile(Fout);
      end;
    end;
  except
    on E: Exception do begin Writeln(ErrOutput, E.Message); Halt(1) end;
  end;
end.
