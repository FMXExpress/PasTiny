(* Read examples in blocks on the stack; nothing stays on the model heap. *)
function SoundLookup(S:String; var A:String):Boolean;
type Mask=array[0..15] of Byte;
 Row=packed record Bits:Mask; Slots:Byte; Reply:String[20] end;
const Pop:array[0..15] of Byte=(0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4);
var F:File; Rows:array[1..12] of Row; B:Mask;
 W,R,T:String; V:Longint; I,J,H,N,Hit,Total,Best,Den:Integer;
 Got:Word; Ambiguous:Boolean;
begin
 SoundLookup:=False; FillChar(B,SizeOf(B),0); SlotN:=0;
 while S<>'' do begin
  W:=NextWord(S);
  if Number(W,V) or WordNumber(W,V) or (W='half') then begin
   if SlotN=MAXNUM then Exit;
   R:=S; T:=NextWord(R);
   if W='half' then begin
    if (T<>'a') or (NextWord(R)<>'second') then Exit;
    V:=500
   end else if (T='seconds') or (T='second') then V:=V*1000;
   Inc(SlotN); NumV[SlotN]:=V; W:='n'+Chr(48+SlotN)
  end;
  H:=0; for I:=1 to Length(W) do H:=(H*31+Ord(W[I])) and 127;
  B[H div 8]:=B[H div 8] or (1 shl (H mod 8))
 end;
 Assign(F,'SOUND.MAP'); {$I-}Reset(F,SizeOf(Row));{$I+}
 if IOResult<>0 then Exit;
 Best:=0; Den:=1; Ambiguous:=False;
 repeat
  {$I-}BlockRead(F,Rows,12,Got);{$I+}
  if IOResult<>0 then begin Best:=0; Break end;
  for J:=1 to Got do if Rows[J].Slots=SlotN then begin
   Hit:=0; Total:=0;
   for I:=0 to 15 do begin
    N:=B[I] and Rows[J].Bits[I]; Inc(Hit,Pop[N and 15]+Pop[N shr 4]);
    N:=B[I] or Rows[J].Bits[I]; Inc(Total,Pop[N and 15]+Pop[N shr 4])
   end;
   if Hit*Den>Best*Total then begin
    Best:=Hit; Den:=Total; A:=Rows[J].Reply; Ambiguous:=False
   end else if (Hit*Den=Best*Total) and (Rows[J].Reply<>A) then Ambiguous:=True
  end
 until Got<12;
 Close(F);
 if (Best*2<Den) or Ambiguous then Exit;
 A:=PutBack(A,False,True); SoundLookup:=True
end;
