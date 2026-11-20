program TinyHost;

(* Test driver for TNYNET.PAS on a modern machine (Free Pascal).
   Same as the DOS original's plain mode:  TINYHOST 0 < QUESTION.TXT > ANSWERS.TXT
   Options: 0..9 creativity, /FLOAT float engine, /BENCH benchmark. *)

{$MODE TP}
{$F+}

uses SysUtils, TnyNet;

var
  I: Integer;
  Bench: Boolean;
  S: String;

function HostClock: Longint;
begin
  HostClock := Longint(GetTickCount64);
end;

begin
  Bench := False;
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if (S[1] >= '0') and (S[1] <= '9') then Creativity := Ord(S[1]) - 48
    else if IsWord(S, '/float') then UseInt := False
    else if IsWord(S, '/bench') then Bench := True;
  end;
  ClockMs := HostClock;
  LoadModel('TINY.BIN');
  AllocMemory;
  if Bench then RunBench(Output, 'host (Free Pascal)', -1)
  else PlainRun(Input, Output);
end.
