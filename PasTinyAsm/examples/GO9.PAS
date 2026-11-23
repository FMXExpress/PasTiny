program Go9;
{$IFDEF FPC}{$MODE TP}{$ENDIF}

const
  Side = 9;
  Cells = Side * Side;
  Empty = 0;
  Black = 1;
  White = 2;
  Marks: array[0..2] of Char = ('.', 'X', 'O');
  Names: array[1..2] of String[5] = ('Black', 'White');
  Cols = 'ABCDEFGHJ';

type
  Board = array[0..Cells-1] of Byte;
  Visits = array[0..Cells-1] of Boolean;
  Points = array[0..Cells-1] of Integer;

var
  Current, Previous, Trial: Board;
  Player, Passes, Point: Integer;
  HasPrevious: Boolean;
  Command: String;

procedure Collect(var Position: Board; Start: Integer; var Seen: Visits;
                  var Group: Points; var Count, Border: Integer);
var
  Head, P, Color: Integer;

  procedure Visit(Neighbor: Integer);
  begin
    if Position[Neighbor] <> Color then
      Border := Border or (1 shl Position[Neighbor])
    else if not Seen[Neighbor] then begin
      Seen[Neighbor] := True;
      Group[Count] := Neighbor;
      Inc(Count)
    end
  end;

begin
  Color := Position[Start];
  Head := 0;
  Count := 1;
  Border := 0;
  Group[0] := Start;
  Seen[Start] := True;
  while Head < Count do begin
    P := Group[Head];
    Inc(Head);
    if P mod Side > 0 then Visit(P-1);
    if P mod Side < Side-1 then Visit(P+1);
    if P >= Side then Visit(P-Side);
    if P < Cells-Side then Visit(P+Side)
  end
end;

function SameBoard(var A, B: Board): Boolean;
var I: Integer;
begin
  SameBoard := False;
  for I := 0 to Cells-1 do if A[I] <> B[I] then Exit;
  SameBoard := True
end;

function Play(P: Integer): Boolean;
var
  Seen: Visits;
  Group: Points;
  I, J, Count, Border, Captured: Integer;
begin
  Play := False;
  if Current[P] <> Empty then begin WriteLn('Occupied.'); Exit end;
  Trial := Current;
  Trial[P] := Player;
  FillChar(Seen, SizeOf(Seen), 0);
  Captured := 0;
  for I := 0 to Cells-1 do
    if (Trial[I] = 3-Player) and not Seen[I] then begin
      Collect(Trial, I, Seen, Group, Count, Border);
      if (Border and 1) = 0 then begin
        for J := 0 to Count-1 do Trial[Group[J]] := Empty;
        Inc(Captured, Count)
      end
    end;
  FillChar(Seen, SizeOf(Seen), 0);
  Collect(Trial, P, Seen, Group, Count, Border);
  if (Border and 1) = 0 then begin WriteLn('Suicide is illegal.'); Exit end;
  if HasPrevious and SameBoard(Trial, Previous) then begin WriteLn('Ko.'); Exit end;
  Previous := Current;
  HasPrevious := True;
  Current := Trial;
  if Captured > 0 then WriteLn('Captured ', Captured, '.');
  Play := True
end;

procedure Draw;
var Row, Col: Integer;
begin
  WriteLn;
  for Row := Side downto 1 do begin
    Write(Row, '  ');
    for Col := 0 to Side-1 do Write(Marks[Current[(Row-1)*Side+Col]], ' ');
    WriteLn
  end;
  WriteLn('   A B C D E F G H J')
end;

procedure Score;
var
  Seen: Visits;
  Group: Points;
  I, Count, Border, B, W: Integer;
begin
  FillChar(Seen, SizeOf(Seen), 0);
  B := 0;
  W := 0;
  for I := 0 to Cells-1 do
    case Current[I] of
      Black: Inc(B);
      White: Inc(W);
      Empty: if not Seen[I] then begin
        Collect(Current, I, Seen, Group, Count, Border);
        if Border = (1 shl Black) then Inc(B, Count);
        if Border = (1 shl White) then Inc(W, Count)
      end
    end;
  WriteLn('Black ', B, ', White ', W+6, '.5 (includes 6.5 komi).');
  if B > W+6 then WriteLn('Black wins.') else WriteLn('White wins.')
end;

function Coordinate(S: String): Integer;
var Col: Integer;
begin
  Coordinate := -1;
  if Length(S) <> 2 then Exit;
  Col := Pos(S[1], Cols);
  if (Col > 0) and (S[2] >= '1') and (S[2] <= '9') then
    Coordinate := (Ord(S[2])-Ord('1'))*Side+Col-1
end;

var I: Integer;
begin
  FillChar(Current, SizeOf(Current), Empty);
  HasPrevious := False;
  Passes := 0;
  Player := Black;
  WriteLn('Go 9x9. X = Black, O = White. Enter D4, PASS or QUIT.');
  Draw;
  while Passes < 2 do begin
    Write(Names[Player], '> ');
    if Eof then Break;
    ReadLn(Command);
    for I := 1 to Length(Command) do Command[I] := UpCase(Command[I]);
    if Command = 'QUIT' then Break
    else if Command = 'PASS' then begin
      Previous := Current;
      HasPrevious := True;
      Inc(Passes);
      Player := 3-Player
    end else begin
      Point := Coordinate(Command);
      if Point < 0 then WriteLn('Enter A1 through J9 (skip I), PASS or QUIT.')
      else if Play(Point) then begin
        Passes := 0;
        Player := 3-Player;
        Draw
      end
    end
  end;
  if Passes = 2 then Score
end.
