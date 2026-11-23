program WorldGen;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
const MaxRooms=120;
type Room=record Title:String[60]; East,West:Byte end;
var Rooms:array[1..MaxRooms] of Room;
 Core:array[0..2047] of Byte;
 Header:packed record Magic:array[1..4] of Char; Bytes,Lamp:Word end;
 F:File; OutputName,S:String; Count,I,Lamp:Integer; Address:Word;
procedure Stop(Msg:String);
begin WriteLn(Msg); Halt(1) end;
function Reply(Prompt:String):String;
var S:String;
begin
 Write(Prompt,' '); if Eof(Input) then Stop('Interview ended.');
 ReadLn(S); Reply:=S
end;
function AskNum(Prompt:String; Minimum,Maximum:Integer):Integer;
var N,Err:Integer; S:String;
begin
 repeat
  S:=Reply(Prompt); Val(S,N,Err);
  if (Err=0) and (N>=Minimum) and (N<=Maximum) then begin AskNum:=N; Exit end;
  WriteLn('Enter ',Minimum,' through ',Maximum,'.')
 until False
end;
function ValidName(S:String):Boolean;
var J:Integer;
begin
 ValidName:=False;
 if (S='') or (Length(S)>8) then Exit;
 for J:=1 to Length(S) do if not (UpCase(S[J]) in ['A'..'Z','0'..'9','_']) then Exit;
 ValidName:=True
end;
procedure WriteData(var Data; Bytes:Word);
var Put:Word;
begin
 {$I-}BlockWrite(F,Data,Bytes,Put);{$I+}
 if (IOResult<>0) or (Put<>Bytes) then begin Close(F); Erase(F); Stop('Disk write failed.') end
end;
const Newline:array[1..3] of Char=(#13,#10,'$');
begin
 if ParamCount>0 then begin
  Assign(Input,ParamStr(1)); {$I-}Reset(Input);{$I+}
  if IOResult<>0 then Stop('Cannot open interview file.')
 end;
 WriteLn('World builder. Players type east, west, look, take lamp, inventory or quit.');
 OutputName:=Reply('New game filename (1-8 letters or digits, no extension)?');
 if not ValidName(OutputName) then Stop('Invalid filename.');
 OutputName:=OutputName+'.COM';
 FileMode:=0; Assign(F,OutputName); {$I-}Reset(F,1);{$I+}
 if IOResult=0 then begin Close(F); Stop('This game already exists.') end;
 Assign(F,'WORLD.DAT'); {$I-}Reset(F,1);{$I+}
 if IOResult<>0 then Stop('Cannot open WORLD.DAT.');
 if FileSize(F)<SizeOf(Header) then Stop('Invalid WORLD.DAT.');
 BlockRead(F,Header,SizeOf(Header));
 if (Header.Magic<>'WRL1') or (Header.Bytes>SizeOf(Core)) or
    (Header.Lamp+1>=Header.Bytes) or (FileSize(F)<>SizeOf(Header)+Header.Bytes) then Stop('Invalid WORLD.DAT.');
 BlockRead(F,Core,Header.Bytes); Close(F);
 Count:=AskNum('How many rooms?',1,MaxRooms);
 for I:=1 to Count do begin
  WriteLn('Room ',I,' of ',Count,' (room 1 is the start).');
  repeat S:=Reply('Description (1-60 characters, no dollar sign)?')
  until (Length(S)>0) and (Length(S)<=60) and (Pos('$',S)=0);
  Rooms[I].Title:=S;
  Rooms[I].East:=(AskNum('East exit (room number, 0 for none)?',0,Count)+255) mod 256;
  Rooms[I].West:=(AskNum('West exit (room number, 0 for none)?',0,Count)+255) mod 256
 end;
 Lamp:=AskNum('Which room contains the lamp?',1,Count)-1;
 Move(Lamp,Core[Header.Lamp],2);
 Assign(F,OutputName); Rewrite(F,1); WriteData(Core,Header.Bytes);
 Address:=$100+Header.Bytes+Count*4;
 for I:=1 to Count do begin
  WriteData(Rooms[I].East,1); WriteData(Rooms[I].West,1); WriteData(Address,2);
  Inc(Address,Length(Rooms[I].Title)+3)
 end;
 for I:=1 to Count do begin WriteData(Rooms[I].Title[1],Length(Rooms[I].Title)); WriteData(Newline,3) end;
 Close(F); WriteLn('Wrote ',OutputName,'. Run it at the DOS prompt.')
end.
