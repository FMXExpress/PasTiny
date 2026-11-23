{$IFDEF VER70}
const
 PaletteIndex:array[0..15] of Byte=(0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);
 PaletteRGB:array[0..15,0..2] of Byte=(
 (1,1,7),(5,7,22),(0,26,18),(0,20,30),(40,4,12),(28,6,40),
 (42,26,4),(40,45,54),(13,16,28),(18,34,63),(18,63,42),(10,57,63),
 (63,22,34),(63,18,58),(63,54,14),(60,62,63));
var ChatX,ChatY:Integer; Peak:array[0..5] of Single; Heat:String[18]; Letters:Integer;

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
 At(X1+2,Y1,15,' '+Title+' ')
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
 At(2,1,27,' PasTinyMoE  /  SPEC100  /  DOS ');
 Box(1,2,55,21,11,'CONVERSATION');
 Box(56,2,80,21,9,'NEURAL MONITOR');
 Box(1,22,80,24,9,'ASK');
 At(2,25,27,' LIST  USE id  AUTO  TOOLS ON/OFF  MEM  F9 capture  Esc quit ');
 ChatX:=1; ChatY:=1;
 FillChar(Peak,SizeOf(Peak),0);
 Heat:=''; Letters:=0
end;

procedure Chat(S:String; Color:Byte);
begin
 Window(3,3,53,20); GotoXY(ChatX,ChatY);
 TextAttr:=Color; PutS(S); ChatX:=WhereX; ChatY:=WhereY; Flush
end;

procedure Meter(X,Y,N:Integer; Value:Single; Color:Byte);
var I,Filled:Integer;
begin
 Filled:=Trunc(Value*N);
 for I:=0 to N-1 do
  if I<Filled then At(X+I,Y,Color,#219) else At(X+I,Y,8,#250)
end;

procedure Monitor;
var I:Integer; V:Single; S:String;
begin
 At(58,3,7,'LAYER ACTIVITY');
 for I:=0 to L-1 do if I<6 then begin
  At(58,4+I,11,'L'+Chr(49+I));
  if LayerAct[I]>Peak[I] then Peak[I]:=LayerAct[I];
  V:=0; if Peak[I]>0 then V:=LayerAct[I]/Peak[I];
  Meter(61,4+I,17,V,10); Peak[I]:=Peak[I]*0.995
 end;
 At(58,10,7,'LETTER CONFIDENCE');
 Meter(58,11,16,LastConf,11);
 Str(Trunc(100*LastConf):3,S); At(74,11,15,S+'%');
 At(58,13,7,'RECENT LETTERS');
 At(58,14,10,'                     ');
 At(58,14,10,Heat);
 if Last>T then begin
  Str((1000.0*Letters)/(Last-T):5:1,S);
  At(58,16,7,S+' letters/s    ')
 end;
 Flush
end;

procedure ReadUI(var S:String);
var C:Integer; F:File; Blank:String;
begin
 S:=''; Blank:=''; repeat Blank:=Blank+' ' until Length(Blank)=76;
 repeat
  At(3,23,7,Blank); At(3,23,13,#16+' '); At(5,23,14,S);
  Window(1,1,80,25); GotoXY(5+Length(S),23);
  C:=TNYSYS.ReadKey;
  case C of
   13: Exit;
   27: begin S:='quit'; Exit end;
   8: if Length(S)>0 then Delete(S,Length(S),1);
   256+67: begin
    Assign(F,'SCREEN.DMP'); {$I-}Rewrite(F,1);
    if IOResult=0 then begin BlockWrite(F,Screen,SizeOf(Screen)); Close(F) end;
    if IOResult<>0 then ;{$I+}
   end;
   32..126: if Length(S)<72 then S:=S+Chr(C)
  end
 until False
end;
{$ENDIF}
