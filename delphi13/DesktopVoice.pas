unit DesktopVoice;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

procedure PlayVoice(const Answer: string);
procedure PlayConsoleVoice(const Answer: string);
procedure StopVoice;

implementation

uses Classes, SysUtils, TinyVoice
  {$IFDEF MSWINDOWS}, {$IFDEF FPC}MMSystem{$ELSE}Winapi.MMSystem{$ENDIF}{$ENDIF};

var Wave: TMemoryStream;

procedure StopVoice;
begin
  {$IFDEF MSWINDOWS}
  if Assigned(Wave) then PlaySound(nil, 0, 0);
  {$ENDIF}
  FreeAndNil(Wave);
end;

procedure StartVoice(const Answer: string; Asynchronous: Boolean);
{$IFDEF MSWINDOWS}
var Flags: Cardinal;
{$ENDIF}
{$IFNDEF MSWINDOWS}
var Temp, Player: string; Status: Integer;
{$ENDIF}
begin
  StopVoice;
  Wave := TMemoryStream.Create;
  RenderVoice(Answer, Wave);
  {$IFDEF MSWINDOWS}
  Flags := SND_MEMORY or SND_NODEFAULT;
  if Asynchronous then Flags := Flags or SND_ASYNC;
  if not PlaySound(PChar(Wave.Memory), 0, Flags) then
    raise Exception.Create('Audio playback failed.');
  {$ELSE}
  Player := FileSearch('aplay', GetEnvironmentVariable('PATH'));
  if Player = '' then Player := FileSearch('ffplay', GetEnvironmentVariable('PATH'));
  if Player = '' then raise Exception.Create('Install aplay or ffplay for /SOUND.');
  Temp := GetTempFileName(GetTempDir, 'tny');
  try
    Wave.SaveToFile(Temp);
    if ExtractFileName(Player) = 'aplay' then
      Status := ExecuteProcess(Player, ['-q', Temp])
    else Status := ExecuteProcess(Player, ['-nodisp','-autoexit','-loglevel','error', Temp]);
    if Status <> 0 then raise Exception.Create('Audio player failed.');
  finally
    DeleteFile(Temp);
  end;
  {$ENDIF}
end;

procedure PlayConsoleVoice(const Answer: string);
begin
  StartVoice(Answer, False);
end;

procedure PlayVoice(const Answer: string);
begin
  StartVoice(Answer, True);
end;

initialization
  Wave := nil;

finalization
  StopVoice;
end.
