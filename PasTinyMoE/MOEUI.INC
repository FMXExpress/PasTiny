{$IFDEF VER70}
const
 PaletteIndex:array[0..15] of Byte=(0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);
 PaletteRGB:array[0..15,0..2] of Byte=(
 (1,1,7),(5,7,22),(0,26,18),(0,20,30),(40,4,12),(28,6,40),
 (42,26,4),(40,45,54),(13,16,28),(18,34,63),(18,63,42),(10,57,63),
 (63,22,34),(63,18,58),(63,54,14),(60,62,63));
const MonitorX=61; InputWidth=54;
var ChatX,ChatY:Integer; Peak:array[0..5] of Single;
 Heat:array[0..17] of Byte; HeatCount,Letters:Integer; LastQuestion:String[MAXQ];

procedure At(X,Y,Color:Integer; S:String);
var I:Integer;
begin
 for I:=1 to Length(S) do Screen[(Y-1)*80+X+I-2]:=Ord(S[I])+Word(Color)*256
end;

procedure Box(X1,Y1,X2,Y2,Color:Integer; Title:String);
var X,Y:Integer;
begin
 for X:=X1+1 to X2-1 do begin At(X,Y1,Color,#205); At(X,Y2,Color,#205) end;
 for Y:=Y1+1 to Y2-1 do begin At(X1,Y,Color,#186); At(X2,Y,Color,#186) end;
 At(X1,Y1,Color,#201); At(X2,Y1,Color,#187);
 At(X1,Y2,Color,#200); At(X2,Y2,Color,#188);
 At(X1+2,Y1,Color,#181);
 At(X1+3,Y1,$3F,' '+Title+' ');
 At(X1+5+Length(Title),Y1,Color,#198)
end;

procedure BeginUI;
var I:Integer;
begin
 TextMode(3);
 if HasVGA then begin
  for I:=0 to 15 do SetDAC(PaletteIndex[I],PaletteRGB[I,0],PaletteRGB[I,1],PaletteRGB[I,2]);
  DisableBlink
 end;
 Window(1,1,80,25); TextAttr:=7; ClrScr;
 At(1,1,$1B,'                                                                                ');
 At(2,1,$1B,#17#16); At(5,1,$1F,'P A S T I N Y M O E');
 At(26,1,$1B,#250+'  NEURAL INTERFACE  '+#250+'  SPEC100');
 At(68,1,$1A,#254); At(70,1,$1B,'ONLINE');
 Box(1,2,58,21,11,'CONVERSATION');
 Box(59,2,80,21,3,'NEURAL MONITOR');
 Box(1,22,80,24,3,'ASK TINY');
 At(3,23,13,#16);
 At(59,22,3,#209); At(59,23,3,#179); At(59,24,3,#207);
 At(62,23,8,#24+' last  F1 help');
 At(1,25,$30,'                                                                                ');
 At(2,25,$3F,'F1'); At(4,25,$30,' Help');
 At(11,25,$3F,'F9'); At(13,25,$30,' Capture');
 At(23,25,$3F,'Esc'); At(26,25,$30,' Quit');
 At(MonitorX,16,8,'EXPERT');
 ChatX:=1; ChatY:=1;
 FillChar(Peak,SizeOf(Peak),0);
 HeatCount:=0; Letters:=0; LastQuestion:=''
end;

procedure Chat(S:String; Color:Byte);
begin
 Window(3,3,56,20); GotoXY(ChatX,ChatY);
 TextAttr:=Color; PutS(S); ChatX:=WhereX; ChatY:=WhereY; Flush
end;

procedure Meter(X,Y,N:Integer; Value:Single; Color:Byte);
var I,Filled:Integer;
begin
 Filled:=Trunc(Value*N*2);
 for I:=0 to N-1 do
  if 2*I+2<=Filled then At(X+I,Y,Color,#219)
  else if 2*I+1=Filled then At(X+I,Y,Color,#221)
  else At(X+I,Y,8,#250)
end;

function ConfidenceColor(Value:Byte):Byte;
begin
 if Value>80 then ConfidenceColor:=10
 else if Value>50 then ConfidenceColor:=14
 else ConfidenceColor:=12
end;

procedure RecordConfidence;
begin
 if HeatCount=18 then Move(Heat[1],Heat[0],17)
 else Inc(HeatCount);
 Heat[HeatCount-1]:=Trunc(100*LastConf)
end;

procedure ExpertStatus;
var S:String; Split:Integer;
begin
 At(MonitorX,17,7,'                  ');
 At(MonitorX,18,7,'                  ');
 if Active=0 then S:='Unloaded' else S:=Items[Active].Title;
 Split:=Length(S);
 if Split>18 then begin
  Split:=18;
  while (Split>0) and (S[Split]<>' ') do Dec(Split);
  if Split=0 then Split:=18;
  At(MonitorX,18,15,Copy(S,Split+1,18))
 end;
 At(MonitorX,17,15,Copy(S,1,Split));
 At(MonitorX,19,8,'MODE');
 if Pinned then S:='PINNED' else S:='AUTO  ';
 if ToolsOn then S:=S+'  TOOLS ON ' else S:=S+'  TOOLS OFF';
 At(MonitorX,20,7,S); Flush
end;

procedure Monitor;
var I:Integer; V:Single; S:String; Color, Confidence:Byte; Glyph:Char;
begin
 At(MonitorX,3,8,'LAYER ACTIVITY');
 for I:=0 to L-1 do if I<6 then begin
  At(MonitorX,4+I,11,'L'+Chr(49+I));
  if LayerAct[I]>Peak[I] then Peak[I]:=LayerAct[I];
  V:=0; if Peak[I]>0 then V:=LayerAct[I]/Peak[I];
  if Odd(I) then Color:=11 else Color:=10;
  Meter(MonitorX+3,4+I,15,V,Color); Peak[I]:=Peak[I]*0.995
 end;
 Confidence:=0;
 if HeatCount>0 then Confidence:=Heat[HeatCount-1];
 At(MonitorX,10,8,'CONFIDENCE');
 Meter(MonitorX,11,13,Confidence/100,ConfidenceColor(Confidence));
 Str(Confidence:3,S); At(MonitorX+13,11,15,' '+S+'%');
 At(MonitorX,12,8,'LAST LETTERS');
 for I:=0 to 17 do begin
  if I>=HeatCount then At(MonitorX+I,13,8,#250)
  else begin
   Confidence:=Heat[I];
   if Confidence>90 then Glyph:=#219
   else if Confidence>70 then Glyph:=#178
   else if Confidence>45 then Glyph:=#177 else Glyph:=#176;
   At(MonitorX+I,13,ConfidenceColor(Confidence),Glyph)
  end
 end;
 At(MonitorX,14,8,'SPEED');
 S:=' --.-';
 if (Letters>0) and (Last>T) then Str((1000.0*Letters)/(Last-T):5:1,S);
 At(MonitorX,15,7,S+' letters/s  '); Flush
end;

procedure ShowHelp;
begin
 Chat('PasTinyMoE keyboard and commands'+#13#10,11);
 Chat('Up recalls the last question. F9 saves SCREEN.DMP.'+#13#10,7);
 Chat('Esc cancels generation or quits at the prompt.'+#13#10,7);
 Chat('LIST shows expert IDs. USE id pins an expert.'+#13#10,7);
 Chat('AUTO restores routing. TOOLS ON/OFF toggles tools.'+#13#10,7);
 Chat('MEM shows free conventional memory.'+#13#10,7)
end;

procedure ReadUI(var S:String);
var C:Integer; F:File; Blank,Visible:String;
begin
 S:=''; Blank:=''; repeat Blank:=Blank+' ' until Length(Blank)=InputWidth;
 repeat
  Visible:=S;
  if Length(S)>InputWidth then Visible:=Copy(S,Length(S)-InputWidth+1,InputWidth);
  At(5,23,7,Blank); At(5,23,15,Visible);
  Window(1,1,80,25); GotoXY(5+Length(Visible),23);
  C:=TNYSYS.ReadKey;
  case C of
   13: begin
    if S<>'' then LastQuestion:=S;
    At(5,23,7,Blank); Exit
   end;
   27: begin S:='quit'; Exit end;
   8: if Length(S)>0 then Delete(S,Length(S),1);
   315: ShowHelp;
   328: S:=LastQuestion;
   256+67: begin
    Assign(F,'SCREEN.DMP'); {$I-}Rewrite(F,1);
    if IOResult=0 then begin BlockWrite(F,Screen,SizeOf(Screen)); Close(F) end;
    if IOResult<>0 then ;{$I+}
   end;
   32..126: if Length(S)<MAXQ then S:=S+Chr(C)
  end
 until False
end;
{$ENDIF}
