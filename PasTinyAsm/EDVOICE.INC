{ PC-speaker letter patterns and expert voice profiles from PasTinyMoE. }
var SoundOn,VoiceOn:Boolean;

procedure Tone(Hz,Ms:Word);
begin
 if SoundOn then begin Sound(Hz); DelayMs(Ms); NoSound end
end;

procedure ReadySound;
begin Tone(1319,40); Tone(1760,70) end;

procedure Buzz(F1,F2,Ms,Shift:Word);
var T:Word;
begin
 F1:=Longint(F1)*Shift div 100; F2:=Longint(F2)*Shift div 100;
 T:=0;
 while T<Ms do begin
  Sound(F1); DelayMs(2); Sound(F2); DelayMs(2); Inc(T,4)
 end;
 NoSound
end;

procedure Hiss(Ms:Word);
var T:Word;
begin
 for T:=1 to Ms do begin Sound(2500+Random(4500)); DelayMs(1) end;
 NoSound
end;

{ Same PC-speaker letter patterns as PasTiny. }
procedure SayLetter(C:Char; Shift,Pace:Word);
 function Duration(Ms:Word):Word;
 begin Duration:=(Ms*Pace+50) div 100 end;
begin
 case UpCase(C) of
 'A':Buzz(730,1090,Duration(64),Shift); 'E':Buzz(530,1840,Duration(56),Shift);
 'I','Y':Buzz(300,2290,Duration(52),Shift); 'O':Buzz(570,840,Duration(64),Shift);
 'U':Buzz(320,870,Duration(56),Shift); 'S','Z','C','X':Hiss(Duration(46));
 'F','H','V','J':Hiss(Duration(30));
 'P','T','K','Q':begin Tone(3200,2); DelayMs(Duration(18)) end;
 'B','D','G':begin Buzz(180,260,Duration(12),Shift); DelayMs(Duration(10)) end;
 'M','N':Buzz(210,300,Duration(40),Shift); 'L','R','W':Buzz(400,1100,Duration(36),Shift);
 ' ':DelayMs(Duration(45)); ',','-':DelayMs(Duration(110)); '.','!','?',':':DelayMs(Duration(200));
 '0'..'9':Buzz(420+(Ord(C)-48)*60,900+(Ord(C)-48)*90,Duration(70),Shift);
 else DelayMs(Duration(20))
 end
end;

procedure SpeakAnswer(A:String; ExpertId:Integer);
var I,Profile:Integer; Pitch,Pace:Word; R:Registers;
begin
 if not SoundOn then Exit;
 if not VoiceOn then begin ReadySound; Exit end;
 Pitch:=115; Pace:=100;
 if (ExpertId>=1) and (ExpertId<=100) then begin
  { 37 is coprime to 100, so every expert gets its own pitch and pace pair. }
  Profile:=(ExpertId-1)*37 mod 100;
  Pitch:=101+3*(Profile mod 10);
  Pace:=82+4*(Profile div 10)
 end;
 for I:=1 to Length(A) do begin
  R.AH:=1; Intr($16,R);
  if (R.Flags and $40)=0 then begin
   if R.AL=27 then begin R.AH:=0; Intr($16,R) end;
   Break
  end;
  SayLetter(A[I],Pitch-30*Longint(I-1) div (Length(A)+1),Pace)
 end
end;
