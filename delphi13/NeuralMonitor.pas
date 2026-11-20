unit NeuralMonitor;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

type
  TMonitorRefresh = procedure of object;

procedure BeginMonitor(Refresh: TMonitorRefresh);
procedure EndMonitor;
procedure MonitorLetter(C: Integer);
function MonitorText: string;
function GeneratedText: string;

implementation

uses Classes, SysUtils, TnyNet;

var
  Peaks, Levels: array[0..MAXL-1] of Single;
  Heat, Letters: string;
  Confidence: Single;
  Started, LastPaint, Elapsed: UInt64;
  Redraw: TMonitorRefresh;

function Tick: UInt64;
begin
  Result := {$IFDEF FPC}GetTickCount64{$ELSE}TThread.GetTickCount64{$ENDIF};
end;

procedure BeginMonitor(Refresh: TMonitorRefresh);
begin
  FillChar(Peaks, SizeOf(Peaks), 0);
  FillChar(Levels, SizeOf(Levels), 0);
  Letters := '';
  Heat := '';
  Confidence := 0;
  Started := Tick;
  LastPaint := Started;
  Elapsed := 0;
  Redraw := Refresh;
end;

procedure EndMonitor;
begin
  Elapsed := Tick - Started;
  Redraw := nil;
end;

procedure MonitorLetter(C: Integer);
var I: Integer; Now: UInt64; Shade: WideChar;
begin
  Letters := Letters + Chr(C);
  for I := 0 to L-1 do begin
    if LayerAct[I] > Peaks[I] then Peaks[I] := LayerAct[I];
    if Peaks[I] > 0 then Levels[I] := LayerAct[I] / Peaks[I];
    Peaks[I] := Peaks[I] * 0.995;
  end;
  Confidence := LastConf;
  if LastConf > 0.90 then Shade := #$2588
  else if LastConf > 0.70 then Shade := #$2593
  else if LastConf > 0.45 then Shade := #$2592
  else Shade := #$2591;
  Heat := Heat + Shade;
  if Length(Heat) > 18 then Delete(Heat, 1, 1);
  Now := Tick;
  Elapsed := Now - Started;
  if Assigned(Redraw) and (Now - LastPaint >= 32) then begin
    LastPaint := Now;
    Redraw;
  end;
end;

function Meter(Value: Single): string;
var I, N: Integer;
begin
  N := Round(Value * 12);
  if N < 0 then N := 0;
  if N > 12 then N := 12;
  SetLength(Result, 12);
  for I := 1 to 12 do
    if I <= N then Result[I] := #$2588 else Result[I] := #$2591;
end;

function MonitorText: string;
var I: Integer;
begin
  Result := 'NEURAL MONITOR' + sLineBreak + sLineBreak + 'Layer activity' + sLineBreak;
  for I := 0 to L-1 do
    Result := Result + 'L' + IntToStr(I+1) + ' ' + Meter(Levels[I]) + sLineBreak;
  Result := Result + sLineBreak + 'Letter confidence' + sLineBreak +
    Meter(Confidence) + ' ' + IntToStr(Trunc(100 * Confidence)) + '%' +
    sLineBreak + 'Last 18 letters' + sLineBreak + Heat + sLineBreak + sLineBreak;
  if Elapsed > 0 then Result := Result + Format('%.1f letters/s', [1000.0 * Length(Letters) / Elapsed])
  else Result := Result + 'Speed pending';
  Result := Result + sLineBreak + Format('%d layers / %d wide', [L, D]) +
    sLineBreak + 'Creativity ' + IntToStr(Creativity);
end;

function GeneratedText: string;
begin
  Result := Letters;
end;

end.
