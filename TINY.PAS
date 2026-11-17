program TINY;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$M 16384,0,655360}{$DEFINE TINYDOS}{$ENDIF}
{$IFDEF GO32V2}{$DEFINE TINYDOS}{$ENDIF}
{$IFDEF MSDOS}{$DEFINE TINYDOS}{$ENDIF}
{$N+}{$E+}
{$IFDEF DEBUG}{$R+}{$Q+}{$ELSE}{$R-}{$Q-}{$ENDIF}
uses {$IFDEF GO32V2}Emu387,{$ENDIF}TNYNET,TNYSYS;
var Plain,Bench,Demo,Dump,DumpAll,Mono,Neon,SoundOn,VoiceOn:Boolean;
 I:Integer; Arg:String;
procedure PlainLetter(C:Integer);
begin Write(Chr(C)); System.Flush(Output) end;
procedure PlainMain;
var Line,Q,Answer:String; Tokens,T0,Tenths:Longint;
begin
 WriteLn('TINY 2 - a neural network that answers questions.');
 WriteLn('Loading TINY.BIN ...'); LoadModel('TINY.BIN'); AllocMemory;
 WriteLn('Ready: ',L,' layers, ',D,' wide. Creativity ',Creativity,' (TINY 0 to TINY 9).');
 WriteLn('Ask about countries, animals, space, the body, nature, science, food,');
 WriteLn('sums, numbers, spelling, words, shapes, history, music or computers.');
 WriteLn('Type QUIT to stop.');
 repeat
  WriteLn; Write('> '); System.Flush(Output);
  if Eof(Input) then Break;
  ReadLn(Line); Q:=Clean(Line);
  if IsWord(Q,'quit') or IsWord(Q,'exit') then Break;
  if Q<>'' then begin
   Write('  '); T0:=NowMs;
   Think(Q,Answer,Tokens,nil,PlainLetter); Tenths:=(NowMs-T0) div 100;
   WriteLn; WriteLn('   [',Length(Answer),' letters in ',Tenths div 10,'.',Tenths mod 10,' seconds]')
  end
 until False;
 WriteLn('Goodbye!'); ReleaseMemory
end;
procedure BenchMain;
const Questions:array[1..5] of String[40]=(
 'what is the capital of peru','is a whale a fish','what is 7 times 8',
 'which countries border estonia','spell elephant');
var J:Integer; Answer:String; Tokens,TotalTokens,TotalMs,T0,Elapsed:Longint;
 Seconds:Single;
begin
 Creativity:=0; T0:=NowMs; LoadModel('TINY.BIN'); AllocMemory;
 WriteLn('Load seconds: ',(NowMs-T0)/1000.0:0:3);
 TotalTokens:=0; TotalMs:=0;
 for J:=1 to 5 do begin
  T0:=NowMs; Think(Questions[J],Answer,Tokens,nil,nil); Elapsed:=NowMs-T0;
  WriteLn('> ',Questions[J]); WriteLn('  ',Answer);
  WriteLn('  tokens: ',Tokens,' seconds: ',Elapsed/1000.0:0:3);
  Inc(TotalTokens,Tokens); Inc(TotalMs,Elapsed)
 end;
 Seconds:=TotalMs/1000.0;
 WriteLn('Total tokens: ',TotalTokens);
 if Seconds>0 then WriteLn('Tokens/second: ',TotalTokens/Seconds:0:3)
 else WriteLn('Tokens/second: timer resolution exceeded');
 WriteLn('Seconds/answer: ',Seconds/5:0:3);
 {$IFDEF FLOATMATH}WriteLn('Engine: FLOAT PASCAL');
 {$ELSE}
 {$IFDEF VER70}{$IFNDEF NOASM}WriteLn('Engine: INTEGER ASM');
 {$ELSE}WriteLn('Engine: INTEGER PASCAL');{$ENDIF}
 {$ELSE}WriteLn('Engine: INTEGER PASCAL');{$ENDIF}{$ENDIF}
 WriteLn('Build: ',BuildName); WriteLn('FPU found: ',FPUName); ReleaseMemory
end;
{$IFDEF TINYDOS}
{$I TNYUI.INC}
{$ENDIF}
begin
 Plain:=False; Bench:=False; Demo:=False; Dump:=False; DumpAll:=False;
 Mono:=False; Neon:=True; SoundOn:=True; VoiceOn:=True;
 Randomize;
 for I:=1 to ParamCount do begin
  Arg:=ParamStr(I);
  if (Length(Arg)>0) and (Arg[1]>='0') and (Arg[1]<='9') then Creativity:=Ord(Arg[1])-48
  else begin
   if (Length(Arg)>0) and (Arg[1]='-') then Arg[1]:='/';
   if IsWord(Arg,'/p') then Plain:=True
   else if IsWord(Arg,'/bench') then Bench:=True
   else if IsWord(Arg,'/demo') then Demo:=True
   else if IsWord(Arg,'/dump') then Dump:=True
   else if IsWord(Arg,'/dumpall') then begin Dump:=True; DumpAll:=True end
   else if IsWord(Arg,'/quiet') then SoundOn:=False
   else if IsWord(Arg,'/mono') then Mono:=True
   else if IsWord(Arg,'/classic') then Neon:=False
  end
 end;
 if Bench then BenchMain else begin
 {$IFDEF TINYDOS}
 if (not Plain) and ConsoleIO then UiMain else PlainMain
 {$ELSE}PlainMain{$ENDIF}
 end
end.
