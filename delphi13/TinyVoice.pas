unit TinyVoice;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses Classes;

procedure RenderVoice(const Answer: string; Wave: TMemoryStream);

implementation

procedure RenderVoice(const Answer: string; Wave: TMemoryStream);
const
  Rate = 24000;
var
  I, Shift, Phase, Freq: Integer;
  Noise: Cardinal;

  procedure Tag(const S: AnsiString);
  begin
    Wave.WriteBuffer(S[1], 4);
  end;

  procedure Number(Value, Bytes: Integer);
  var B: Byte;
  begin
    while Bytes > 0 do begin
      B := Value and 255;
      Wave.WriteBuffer(B, 1);
      Value := Value shr 8;
      Dec(Bytes);
    end;
  end;

  procedure Tone(Hz, Ms: Integer);
  var
    Samples: array[0..23] of Byte;
    T, K: Integer;
  begin
    for T := 1 to Ms do begin
      for K := Low(Samples) to High(Samples) do begin
        Phase := (Phase + Hz) mod Rate;
        if Hz = 0 then Samples[K] := 128
        else if Phase < Rate div 2 then Samples[K] := 156
        else Samples[K] := 100;
      end;
      Wave.WriteBuffer(Samples, SizeOf(Samples));
    end;
  end;

  procedure Buzz(F1, F2, Ms: Integer);
  begin
    while Ms > 0 do begin
      Tone(F1 * Shift div 100, 2);
      Tone(F2 * Shift div 100, 2);
      Dec(Ms, 4);
    end;
  end;

  procedure Hiss(Ms: Integer);
  begin
    while Ms > 0 do begin
      Noise := Noise xor (Noise shl 13);
      Noise := Noise xor (Noise shr 17);
      Noise := Noise xor (Noise shl 5);
      Tone(2500 + Integer(Noise mod 4500), 1);
      Dec(Ms);
    end;
  end;

begin
  Wave.Clear;
  Wave.Position := 44;
  Phase := 0;
  Noise := 173;
  Shift := 115;
  for I := 1 to Length(Answer) do begin
    if (I = 1) or (Answer[I-1] = ' ') then
      Shift := 115 - 30 * (I-1) div (Length(Answer)+1);
    case UpCase(Answer[I]) of
      'A': Buzz(730, 1090, 64);
      'E': Buzz(530, 1840, 56);
      'I','Y': Buzz(300, 2290, 52);
      'O': Buzz(570, 840, 64);
      'U': Buzz(320, 870, 56);
      'S','Z','C','X': Hiss(46);
      'F','H','V','J': Hiss(30);
      'P','T','K','Q': begin Tone(3200, 2); Tone(0, 18) end;
      'B','D','G': begin Buzz(180, 260, 12); Tone(0, 10) end;
      'M','N': Buzz(210, 300, 40);
      'L','R','W': Buzz(400, 1100, 36);
      ' ': Tone(0, 45);
      ',','-': Tone(0, 110);
      '.','!','?',':': Tone(0, 200);
      '0'..'9': begin
        Freq := Ord(Answer[I])-Ord('0');
        Buzz(420+Freq*60, 900+Freq*90, 70);
      end;
    else Tone(0, 20);
    end;
  end;
  Wave.Size := Wave.Position;
  Wave.Position := 0;
  Tag('RIFF'); Number(Wave.Size-8, 4); Tag('WAVE'); Tag('fmt ');
  Number(16, 4); Number(1, 2); Number(1, 2); Number(Rate, 4);
  Number(Rate, 4); Number(1, 2); Number(8, 2);
  Tag('data'); Number(Wave.Size-44, 4);
  Wave.Position := 0;
end;

end.
