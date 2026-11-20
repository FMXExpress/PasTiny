unit EXPCAT;
{$IFDEF SPEC30}{$DEFINE SPEC20}{$ENDIF}
{$IFDEF SPEC20}{$DEFINE SPEC10}{$ENDIF}
{$IFDEF SPEC10}{$DEFINE SPEC9}{$ENDIF}
{$IFDEF SPEC9}{$DEFINE SPEC8}{$ENDIF}
{$IFDEF SPEC8}{$DEFINE SPEC5}{$ENDIF}
{$IFDEF SPEC5}{$DEFINE SPEC4}{$ENDIF}
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF SPEC4}{$DEFINE SPEC3}{$ENDIF}
interface
type Entry=packed record Id:Byte; Name:String[12]; Title:String[28];
 Keyword:String[20]; Check:Longint end;
var Items:array[1..128] of Entry; Count:Integer;
function ReadCatalog:Boolean;
function FindId(Id:Integer):Integer;
function Route(Q:String):Integer;
implementation
{$IFDEF SPEC3}uses PILOTRT;{$ENDIF}
function FindId(Id:Integer):Integer;
var J:Integer;
begin FindId:=0; for J:=1 to Count do if Items[J].Id=Id then FindId:=J end;
function SafeName(S:String):Boolean;
var I:Integer;
begin SafeName:=False;
 if (Length(S)<5) or (Length(S)>12) or (Copy(S,Length(S)-3,4)<>'.BIN') then Exit;
 for I:=1 to Length(S)-4 do if not (S[I] in ['A'..'Z','0'..'9','_']) then Exit;
 SafeName:=True
end;
function ReadCatalog:Boolean;
var F:File; H:array[1..4] of Char; N:Byte; E:Entry; Got:Word; Err:Integer;
begin
 ReadCatalog:=False; Count:=0; FileMode:=0; Assign(F,'EXPERTS.CAT');
 {$I-}Reset(F,1); Err:=IOResult;{$I+} if Err<>0 then Exit;
 {$I-}BlockRead(F,H,4,Got);
 if (Got=4) and (H='PEC1') then begin
  BlockRead(F,N,1,Got);
  if (Got=1) and (N>=1) and (N<=128) and (FileSize(F)=5+Longint(N)*SizeOf(E)) then
   while Count<N do begin
    BlockRead(F,E,SizeOf(E),Got);
    if (Got<>SizeOf(E)) or (E.Id=0) or (E.Id>128) or (FindId(E.Id)<>0)
      or (Length(E.Name)>12) or (Length(E.Title)>28) or (Length(E.Keyword)>20) then Break;
    if not SafeName(E.Name) then Break;
    Inc(Count); Items[Count]:=E
   end;
  ReadCatalog:=(N>0) and (Count=N)
 end;
 Close(F); Err:=IOResult;{$I+} if Err<>0 then ReadCatalog:=False
end;
function Route(Q:String):Integer;
var J,Hit:Integer;
begin
 {$IFDEF SPEC3}Route:=FindId(PilotDomain(Q)); Exit;{$ENDIF}
 Hit:=0; Q:=' '+Q+' ';
 for J:=1 to Count do if Items[J].Keyword<>'' then
  if Pos(' '+Items[J].Keyword+' ',Q)>0 then begin
   if Hit<>0 then begin Route:=1; Exit end; Hit:=J
  end;
 if Hit=0 then Hit:=1; Route:=Hit
end;
end.
