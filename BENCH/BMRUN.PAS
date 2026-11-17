program BenchRun;
{$M 4096,0,0}{$N+}{$E+}
uses Dos;
var
 Fin,Fout:File;
 SavedIn,SavedOut:Word;
 T0,Elapsed,EpochTicks:Longint;
 I,Runs,Err,ChildCode,ParseError:Integer;
 ExeName,Prefix,OutputName,S:String;
function BiosTicks:Longint;
var T:Longint;
begin Move(Mem[$40:$6C],T,4); BiosTicks:=T end;
function NowMs:Longint;
var A,B:Longint; Low,High:Byte; Counter:Word;
begin
 repeat
  A:=BiosTicks; Port[$43]:=0; Low:=Port[$40]; High:=Port[$40]; B:=BiosTicks
 until A=B;
 Counter:=Word(Low)+Word(High)*256;
 NowMs:=Trunc(((A-EpochTicks)*65536.0+(65535.0-Counter))*1000.0/1193182.0)
end;
function Duplicate(Handle:Word):Word;
var R:Registers;
begin
 R.AH:=$45; R.BX:=Handle; MsDos(R);
 if R.Flags and 1<>0 then Halt(2);
 Duplicate:=R.AX
end;
procedure Redirect(FromHandle,ToHandle:Word);
var R:Registers;
begin
 R.AH:=$46; R.BX:=FromHandle; R.CX:=ToHandle; MsDos(R);
 if R.Flags and 1<>0 then Halt(3)
end;
procedure CloseHandle(Handle:Word);
var R:Registers;
begin R.AH:=$3E; R.BX:=Handle; MsDos(R) end;
begin
 if ParamCount<2 then begin WriteLn('BMRUN executable output_prefix [repeats]'); Halt(1) end;
 ExeName:=ParamStr(1); Prefix:=ParamStr(2); Runs:=1;
 if ParamCount>=3 then Val(ParamStr(3),Runs,ParseError);
 if (Runs<1) or (Runs>9) then Halt(1);
 EpochTicks:=BiosTicks;
 for I:=1 to Runs do begin
  Str(I,S); OutputName:=Prefix+S+'.TXT';
  Assign(Fin,'Q.TXT'); FileMode:=0; Reset(Fin,1);
  Assign(Fout,OutputName); Rewrite(Fout,1);
  SavedIn:=Duplicate(0); SavedOut:=Duplicate(1);
  Redirect(FileRec(Fin).Handle,0); Redirect(FileRec(Fout).Handle,1);
  T0:=NowMs;
  SwapVectors; Exec(ExeName,' 0 /P'); SwapVectors;
  Err:=DosError; ChildCode:=DosExitCode;
  Elapsed:=NowMs-T0;
  Redirect(SavedIn,0); Redirect(SavedOut,1);
  CloseHandle(SavedIn); CloseHandle(SavedOut);
  Close(Fin); Close(Fout);
  WriteLn('RUN ',I,' MS ',Elapsed,' DOSERROR ',Err,' EXIT ',ChildCode);
  if (Err<>0) or (ChildCode<>0) then Halt(4)
 end
end.
