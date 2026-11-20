program Tiny;

(* TINY 2.1 for Delphi 1 - a question answering neural network for
   Windows 3.1.

   Port of TINY 2.1 for DOS (Turbo C 2.0) by WollyMonjac:
   https://github.com/WollyMonjac/Tiny-2.1
   Keep TINY.BIN in the same directory as TINY.EXE.

   Options (Program Manager: File, Properties, Command Line; or File, Run):
     TINY 0 .. TINY 9   creativity (0 = always the surest answer, default 5)
     /DEMO              TINY asks itself sample questions
     /QUIET             no sound
     /MONO              grey colours
     /CLASSIC           standard DOS colours instead of the neon palette
     /FLOAT             the original floating point engine (slow without
                        a coprocessor; for comparison)
     /BENCH             speed test; results also go to BENCH.TXT
     /IN=file           answer the questions in a text file (one per line)
     /OUT=file          ... and write the answers here (default TINY.OUT)
     /DUMP, /DUMPALL    test mode: writes BOOT.DMP, SCREEN.DMP, SOUND.LOG *)

{$IFDEF FPC} {$MODE TP} {$ENDIF}
{$F+,X+}

uses TnyNet, TnyWin, TnyUI;

const
{$IFDEF FPC}
  Build = 'Free Pascal, Win16';
{$ELSE}
  Build = 'Delphi 1, Win16';
{$ENDIF}

var
  I: Integer;
  S, InName, OutName: String;
  Bench: Boolean;

procedure WinFail(const Msg: String);
begin
  ScrClose;
  ShowBox('TINY: ' + Msg, 'TINY 2.1', True);
  Halt(1);
end;

function HasPrefix(const S, P: String): Boolean;
begin
  HasPrefix := IsWord(Copy(S, 1, Length(P)), P);
end;

{ show a text file in the window (for /BENCH), then wait for a key }
procedure ShowFile(const Name: String);
var
  F: Text;
  Line: String;
begin
  TextAttr := 7;
  Window(1, 1, 80, 25);
  ClrScr;
  Assign(F, Name);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then Exit;
  TextAttr := 10;
  while not Eof(F) do
  begin
    ReadLn(F, Line);
    CPutS(Copy(Line, 1, 79) + #13#10);
  end;
  Close(F);
  TextAttr := 8;
  CPutS(#13#10'(saved in ' + Name + ')  press any key');
  ReadKey;
end;

procedure Message(const S: String);
begin
  TextAttr := 11;
  Window(1, 1, 80, 25);
  ClrScr;
  GotoXY(3, 3);
  CPutS(S);
  GotoXY(3, 5);
  TextAttr := 8;
  CPutS('Close the window to stop.');
  Flush;
end;

procedure RunBenchUI;
var
  F: Text;
  Name: String;
begin
  Name := ExeDir + 'BENCH.TXT';
  Message('TINY is timing itself ... (five questions)');
  LoadModel(ExeDir + 'TINY.BIN');
  AllocMemory;
  Assign(F, Name);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult <> 0 then WinFail('cannot write ' + Name);
  RunBench(F, Build, Ord(HasFpu));
  Close(F);
  if not Quitting then ShowFile(Name);
end;

procedure RunFiles;
var
  Fin, Fout: Text;
begin
  if OutName = '' then OutName := ExeDir + 'TINY.OUT';
  Message('TINY is answering the questions in ' + InName + ' ...');
  LoadModel(ExeDir + 'TINY.BIN');
  AllocMemory;
  Assign(Fin, InName);
  {$I-}
  Reset(Fin);
  {$I+}
  if IOResult <> 0 then WinFail('cannot open ' + InName);
  Assign(Fout, OutName);
  {$I-}
  Rewrite(Fout);
  {$I+}
  if IOResult <> 0 then WinFail('cannot write ' + OutName);
  PlainRun(Fin, Fout);
  Close(Fin);
  Close(Fout);
  if not Quitting then
    ShowBox('The answers are in ' + OutName, 'TINY 2.1', False);
end;

begin
  Bench := False;
  InName := '';
  OutName := '';
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if (S[1] >= '0') and (S[1] <= '9') then Creativity := Ord(S[1]) - 48
    else if IsWord(S, '/demo') or IsWord(S, '-demo') then Demo := True
    else if IsWord(S, '/dump') then Dump := True
    else if IsWord(S, '/dumpall') then begin Dump := True; DumpAll := True; end
    else if IsWord(S, '/mono') or IsWord(S, '-mono') then Mono := True
    else if IsWord(S, '/quiet') or IsWord(S, '-quiet') then SoundOn := False
    else if IsWord(S, '/classic') or IsWord(S, '-classic') then Neon := False
    else if IsWord(S, '/float') then UseInt := False
    else if IsWord(S, '/bench') then Bench := True
    else if HasPrefix(S, '/in=') then InName := Copy(S, 5, 255)
    else if HasPrefix(S, '/out=') then OutName := Copy(S, 6, 255);
  end;
  Randomize;
  OnFail := WinFail;
  ClockMs := Clock;
  OnIdle := Idle;
  if Mono then ScrOpen(PAL_MONO)
  else if Neon then ScrOpen(PAL_NEON)
  else ScrOpen(PAL_CLASSIC);
  if Bench then RunBenchUI
  else if InName <> '' then RunFiles
  else UiMain;
  ScrClose;
end.
