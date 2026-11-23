program XmsBench;
{$M 16384,0,655360}{$F+}
uses TNYNET, XMSCACHE, TNYSYS;

var
  CRC, Tokens, Started, First, Finished: Longint;
  Code: Integer;
  Question, Answer: String;

procedure RecordFirst(C: Integer);
begin
  if First < 0 then First := NowMs;
end;

begin
  Val(ParamStr(2), CRC, Code);
  if Code <> 0 then Halt(1);
  ModelXms := XmsStore(ParamStr(1));
  if ModelXms = 0 then Halt(2);
  if not TryModel(ParamStr(1), CRC) then begin
    WriteLn(LoadError);
    Halt(3);
  end;
  AllocMemory;
  Creativity := 0;
  WriteLn('heap=', MemAvail);
  while not Eof do begin
    ReadLn(Question);
    First := -1;
    Started := NowMs;
    Think(Question, Answer, Tokens, nil, RecordFirst);
    Finished := NowMs;
    WriteLn(Answer);
    if First >= 0 then WriteLn(First - Started, ' ', Finished - Started)
    else WriteLn(-1, ' ', Finished - Started)
  end;
  ReleaseMemory
end.
