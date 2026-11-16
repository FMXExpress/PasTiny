unit TNYNET;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$N+}{$E+}
{$IFDEF DEBUG}{$R+}{$Q+}{$ELSE}{$R-}{$Q-}{$ENDIF}
interface
const VOCAB=97; CTX=128; MAXD=128; MAXHID=512; MAXL=8; MAXQ=72;
type
 {$IFDEF FPC}TIdx=Longint;{$ELSE}TIdx=Integer;{$ENDIF}
 {$IFNDEF FPC}SmallInt=Integer;{$ENDIF}
 TS8Arr=array[0..64999] of ShortInt; PS8Arr=^TS8Arr;
 TSglArr=array[0..15999] of Single; PSglArr=^TSglArr;
 TVec=array[0..511] of Single;
 TQVec=array[0..511] of SmallInt; PQVec=^TQVec;
 TTable=record Scale:PSglArr; W:PS8Arr; Rows,Cols:TIdx end;
 TStepProc=procedure(I,N:Integer); TLetterProc=procedure(C:Integer);
 TLoadProc=procedure(Done,Total:Integer); TFailProc=procedure;
var D,L,H,HD,HID:Integer; Creativity:Integer; LastConf:Single;
 LayerAct:array[0..MAXL-1] of Single;
 OnLoad:TLoadProc; OnFail:TFailProc;
procedure LoadModel(Name:String);
procedure AllocMemory;
procedure ReleaseMemory;
procedure Think(Q:String; var Answer:String; var Tokens:Longint;
                OnStep:TStepProc; OnLetter:TLetterProc);
function Clean(Line:String):String;
function IsWord(Q,W:String):Boolean;
procedure Fail(Msg:String);
implementation
var Emb,Pos:TTable;
 Wq,Wk,Wv,Wo,F1,F2:array[0..MAXL-1] of TTable;
 G1,G2:array[0..MAXL-1] of PSglArr; Gf:PSglArr;
 Kc,Vc:array[0..MAXL-1] of PS8Arr;
 Ks,Vs:array[0..MAXL-1] of PSglArr;
 Bx,Bh,Bq,Bt,Ba,Bm,Bs,Score:TVec;
 Xq,Qq,Ww:TQVec;
 Ee:array[0..CTX-1] of Longint;
 ExpTab:array[0..1535] of SmallInt;
 AttDiv:Single; TablesDone,TablesTotal:Integer;
 F:File;
procedure Fail(Msg:String);
begin
 if Assigned(OnFail) then OnFail;
 WriteLn; WriteLn('TINY: ',Msg); Halt(1)
end;
function Memory(N:Word):Pointer;
var P:Pointer;
begin
 {$IFNDEF FPC}if MaxAvail<N then Fail('not enough memory. TINY needs about 540 KB free (type MEM).');{$ENDIF}
 GetMem(P,N); Memory:=P
end;
procedure Damaged;
begin Fail('TINY.BIN is too short or damaged.') end;
procedure ReadBytes(var Dest; N:Word);
var Got:Word; Err:Integer;
begin
 {$I-}BlockRead(F,Dest,N,Got); Err:=IOResult;{$I+}
 if (Err<>0) or (Got<>N) then Damaged
end;
function Read16:Word;
var B:array[0..1] of Byte;
begin ReadBytes(B,2); Read16:=Word(B[0])+Word(B[1])*256 end;
procedure LoadTable(var T:TTable; Rows,Cols:Integer);
var R:TIdx;
begin
 if (Longint(Rows)*Cols>65000) or (Cols>512) then
  Fail('a table in TINY.BIN is too big for DOS.');
 T.Rows:=Rows; T.Cols:=Cols;
 T.Scale:=Memory(Rows*4); T.W:=Memory(Longint(Rows)*Cols);
 for R:=0 to Rows-1 do begin
  ReadBytes(T.Scale^[R],4); ReadBytes(T.W^[Longint(R)*Cols],Cols)
 end;
 Inc(TablesDone); if Assigned(OnLoad) then OnLoad(TablesDone,TablesTotal)
end;
function LoadGains:PSglArr;
var G:PSglArr;
begin G:=Memory(D*4); ReadBytes(G^[0],D*4); LoadGains:=G end;
procedure LoadModel(Name:String);
var Magic:array[1..4] of Char; J:Integer; Got:Word; B:Byte; Err:Integer;
begin
 FileMode:=0; Assign(F,Name);
 {$I-}Reset(F,1); Err:=IOResult;{$I+}
 if Err<>0 then Fail('cannot open TINY.BIN. Keep it in the same directory.');
 {$I-}BlockRead(F,Magic,4,Got); Err:=IOResult;{$I+}
 if (Err<>0) or (Got<>4) or (Magic<>'TNY2') then
  Fail('TINY.BIN is not a version 2 network file.');
 D:=Read16; L:=Read16; H:=Read16; HID:=Read16;
 if (D<8) or (D>MAXD) or (L<1) or (L>MAXL) or (H<1) or
    (H>MAXD) or (HID<8) or (HID>MAXHID) then
  Fail('TINY.BIN has a network size this program cannot handle.');
 if D mod H<>0 then Fail('TINY.BIN has a network size this program cannot handle.');
 HD:=D div H; AttDiv:=Sqrt(HD); TablesDone:=0; TablesTotal:=2+6*L;
 LoadTable(Emb,VOCAB,D); LoadTable(Pos,CTX,D);
 for J:=0 to L-1 do begin
  G1[J]:=LoadGains;
  LoadTable(Wq[J],D,D); LoadTable(Wk[J],D,D);
  LoadTable(Wv[J],D,D); LoadTable(Wo[J],D,D);
  G2[J]:=LoadGains; LoadTable(F1[J],HID,D); LoadTable(F2[J],D,HID)
 end;
 Gf:=LoadGains;
 {$I-}BlockRead(F,B,1,Got); Err:=IOResult; Close(F);{$I+}
 if (Err<>0) or (Got<>0) then Fail('TINY.BIN has the wrong size.')
end;
procedure AllocMemory;
var J,K:Integer;
begin
 for J:=0 to L-1 do begin
  Kc[J]:=Memory(CTX*D); Vc[J]:=Memory(CTX*D);
  Ks[J]:=Memory(CTX*4); Vs[J]:=Memory(CTX*4)
 end;
 for K:=0 to 1535 do ExpTab[K]:=Trunc(Exp(-K/128.0)*32767.0+0.5)
end;
procedure FreeTable(var T:TTable);
begin
 if T.W<>nil then FreeMem(T.W,Longint(T.Rows)*T.Cols);
 if T.Scale<>nil then FreeMem(T.Scale,T.Rows*4);
 T.W:=nil; T.Scale:=nil
end;
procedure ReleaseMemory;
var J:Integer;
begin
 FreeTable(Emb); FreeTable(Pos);
 for J:=0 to L-1 do begin
  FreeTable(Wq[J]); FreeTable(Wk[J]); FreeTable(Wv[J]);
  FreeTable(Wo[J]); FreeTable(F1[J]); FreeTable(F2[J]);
  if G1[J]<>nil then FreeMem(G1[J],D*4);
  if G2[J]<>nil then FreeMem(G2[J],D*4);
  if Kc[J]<>nil then FreeMem(Kc[J],CTX*D);
  if Vc[J]<>nil then FreeMem(Vc[J],CTX*D);
  if Ks[J]<>nil then FreeMem(Ks[J],CTX*4);
  if Vs[J]<>nil then FreeMem(Vs[J],CTX*4)
 end;
 if Gf<>nil then FreeMem(Gf,D*4)
end;
function Quant16(var X:TVec; N:Integer; var Q:TQVec):Single;
var I:TIdx; M,V,K:Single;
begin
 M:=0; for I:=0 to N-1 do if Abs(X[I])>M then M:=Abs(X[I]);
 if M<1e-20 then begin
  for I:=0 to N-1 do Q[I]:=0; Quant16:=0
 end else begin
  K:=32767.0/M;
  for I:=0 to N-1 do begin
   V:=X[I]*K;
   if V<0 then V:=V-0.5 else V:=V+0.5; Q[I]:=Trunc(V)
  end;
  Quant16:=M/32767.0
 end
end;
{$IFDEF VER70}{$IFNDEF NOASM}{$DEFINE DOTASM}{$ENDIF}{$ENDIF}
{$IFDEF DOTASM}
function DotS8I16(W:PS8Arr; var X:TQVec; N:Word):Longint; assembler;
asm
 push ds
 mov cx,N
 lds si,W
 les di,X
 push bp
 xor bx,bx
 xor bp,bp
 jcxz @done
@loop:
 lodsb
 cbw
 imul word ptr es:[di]
 add bx,ax
 adc bp,dx
 add di,2
 loop @loop
@done:
 mov ax,bx
 mov dx,bp
 pop bp
 pop ds
end;
{$ELSE}
function DotS8I16(W:PS8Arr; var X:TQVec; N:Word):Longint;
var I:TIdx; A:Longint;
begin
 A:=0; for I:=0 to N-1 do A:=A+Longint(W^[I])*X[I]; DotS8I16:=A
end;
{$ENDIF}
procedure Matvec(var T:TTable; var X,Y:TVec);
var R,C:TIdx; Offset:Longint; S,Sx,V:Single; A:Longint;
begin
 {$IFNDEF FLOATMATH}Sx:=Quant16(X,T.Cols,Xq);{$ENDIF}
 Offset:=0;
 for R:=0 to T.Rows-1 do begin
 {$IFDEF FLOATMATH}
  S:=0; for C:=0 to T.Cols-1 do begin
   V:=T.W^[Offset+C]*X[C]; S:=S+V
  end;
  Y[R]:=S*T.Scale^[R];
 {$ELSE}
  A:=DotS8I16(PS8Arr(@T.W^[Offset]),Xq,T.Cols);
  S:=A; S:=S*T.Scale^[R]; Y[R]:=S*Sx;
 {$ENDIF}
  Inc(Offset,T.Cols)
 end
end;
procedure Norm(var X:TVec; G:PSglArr; var Y:TVec);
var I:TIdx; S,V:Single;
begin
 S:=0; for I:=0 to D-1 do begin V:=X[I]*X[I]; S:=S+V end;
 V:=S/D; S:=1.0/Sqrt(V+1e-5);
 for I:=0 to D-1 do begin V:=X[I]*S; Y[I]:=V*G^[I] end
end;
function SafeExp(X:Single):Single;
begin if X< -60.0 then SafeExp:=0 else SafeExp:=Exp(X) end;
function Store(Dst:PS8Arr; var Src:TVec):Single;
var I:TIdx; Big,V,K:Single;
begin
 Big:=0; for I:=0 to D-1 do if Abs(Src[I])>Big then Big:=Abs(Src[I]);
 if Big<1e-20 then Big:=1e-20;
 K:=127.0/Big;
 for I:=0 to D-1 do begin
  V:=Src[I]*K;
  if V<0 then V:=V-0.5 else V:=V+0.5; Dst^[I]:=Trunc(V)
 end;
 Store:=Big/127.0
end;
procedure Step(Tok,P:Integer);
var I,J,Z,Head,Off,At:TIdx; S,Big,Sum,V,Qs,Wm,Wsc:Single;
 Acc,Esum:Longint; K:Longint;
begin
 for I:=0 to D-1 do begin
  S:=Emb.W^[Tok*D+I]*Emb.Scale^[Tok];
  V:=Pos.W^[P*D+I]*Pos.Scale^[P]; Bx[I]:=S+V
 end;
 for Z:=0 to L-1 do begin
  Norm(Bx,G1[Z],Bh);
  Matvec(Wk[Z],Bh,Bt); Ks[Z]^[P]:=Store(PS8Arr(@Kc[Z]^[P*D]),Bt);
  Matvec(Wv[Z],Bh,Bt); Vs[Z]^[P]:=Store(PS8Arr(@Vc[Z]^[P*D]),Bt);
  Matvec(Wq[Z],Bh,Bq);
  {$IFNDEF FLOATMATH}Qs:=Quant16(Bq,D,Qq);{$ENDIF}
  for Head:=0 to H-1 do begin
   Off:=Head*HD; Big:=-1e30;
   for J:=0 to P do begin
    At:=J*D+Off;
    {$IFDEF FLOATMATH}
    S:=0; for I:=0 to HD-1 do begin
     V:=Bq[Off+I]*Kc[Z]^[At+I]; S:=S+V
    end;
    {$ELSE}
    Acc:=DotS8I16(PS8Arr(@Kc[Z]^[At]),PQVec(@Qq[Off])^,HD);
    S:=Acc; S:=S*Qs;
    {$ENDIF}
    S:=S*Ks[Z]^[J]; S:=S/AttDiv; Bs[J]:=S;
    if S>Big then Big:=S
   end;
   {$IFDEF FLOATMATH}
   Sum:=0;
   for J:=0 to P do begin Bs[J]:=SafeExp(Bs[J]-Big); Sum:=Sum+Bs[J] end;
   for I:=0 to HD-1 do Ba[Off+I]:=0;
   for J:=0 to P do if Bs[J]<>0 then begin
    S:=Bs[J]*Vs[Z]^[J]; S:=S/Sum;
    for I:=0 to HD-1 do begin
     V:=S*Vc[Z]^[J*D+Off+I]; Ba[Off+I]:=Ba[Off+I]+V
    end
   end;
   {$ELSE}
   Esum:=0;
   for J:=0 to P do begin
    S:=Big-Bs[J]; S:=S*128.0;
    if S>=1535.5 then K:=1536 else begin S:=S+0.5; K:=Trunc(S) end;
    if K<1536 then Ee[J]:=ExpTab[K] else Ee[J]:=0;
    Esum:=Esum+Ee[J]
   end;
   Wm:=0; for J:=0 to P do begin
    Bs[J]:=Ee[J]*Vs[Z]^[J]; if Bs[J]>Wm then Wm:=Bs[J]
   end;
   if Wm>0 then Wsc:=Wm/32767.0 else Wsc:=0;
   for J:=0 to P do begin
    if Wsc>0 then begin S:=Bs[J]/Wsc; S:=S+0.5; Ww[J]:=Trunc(S) end
    else Ww[J]:=0
   end;
   for I:=0 to HD-1 do begin
    Acc:=0; for J:=0 to P do Acc:=Acc+Longint(Ww[J])*Vc[Z]^[J*D+Off+I];
    S:=Acc; S:=S*Wsc; Ba[Off+I]:=S/Esum
   end;
   {$ENDIF}
  end;
  Matvec(Wo[Z],Ba,Bt); for I:=0 to D-1 do Bx[I]:=Bx[I]+Bt[I];
  Norm(Bx,G2[Z],Bh); Matvec(F1[Z],Bh,Bm); S:=0;
  for I:=0 to HID-1 do if Bm[I]<0 then Bm[I]:=0 else S:=S+Bm[I];
  LayerAct[Z]:=S/HID; Matvec(F2[Z],Bm,Bt);
  for I:=0 to D-1 do Bx[I]:=Bx[I]+Bt[I]
 end;
 Norm(Bx,Gf,Bh); Matvec(Emb,Bh,Score)
end;
function Probability(Delta:Single):Single;
var K:Longint; V:Single;
begin
 {$IFDEF FLOATMATH}Probability:=SafeExp(-Delta);{$ELSE}
 V:=Delta*128.0;
 if V>=1535.5 then Probability:=0 else begin
  K:=Trunc(V+0.5); if K<0 then K:=0; Probability:=ExpTab[K]/32767.0
 end
 {$ENDIF}
end;
function Chosen(Tok:Integer):Integer;
var I,Best:Integer; Sum,V:Single;
begin
 {$IFDEF FLOATMATH}
 Sum:=0; for I:=0 to VOCAB-1 do Sum:=Sum+SafeExp(Score[I]-Score[Tok]);
 LastConf:=1.0/Sum;
 {$ELSE}
 Best:=0; for I:=1 to VOCAB-1 do if Score[I]>Score[Best] then Best:=I;
 Sum:=0; for I:=0 to VOCAB-1 do Sum:=Sum+Probability(Score[Best]-Score[I]);
 V:=Probability(Score[Best]-Score[Tok]); LastConf:=V/Sum;
 {$ENDIF}
 Chosen:=Tok
end;
function Pick:Integer;
var I,Best,Selected:Integer; T,Sum,R,V:Single;
begin
 Best:=0; for I:=1 to VOCAB-1 do if Score[I]>Score[Best] then Best:=I;
 Selected:=Best;
 if Creativity>0 then begin
  T:=Creativity/5.0; Sum:=0;
  for I:=0 to VOCAB-1 do begin
   V:=(Score[Best]-Score[I])/T; Bs[I]:=Probability(V);
   if Bs[I]<0.15 then Bs[I]:=0; Sum:=Sum+Bs[I]
  end;
  R:=Sum*Random(10000); R:=R/10000.0;
  I:=0;
  while I<VOCAB do begin
   R:=R-Bs[I];
   if (R<0) and (Bs[I]>0) then begin Selected:=I; I:=VOCAB end
   else Inc(I)
  end
 end;
 Pick:=Chosen(Selected)
end;
procedure Think(Q:String; var Answer:String; var Tokens:Longint;
                OnStep:TStepProc; OnLetter:TLetterProc);
var P,N,Tok:Integer;
begin
 Q:=Clean(Q); P:=0; N:=Length(Q); Answer:=''; Tokens:=0;
 while P<N do begin
  if Assigned(OnStep) then OnStep(P,N);
  Step(Ord(Q[P+1])-30,P); Inc(P); Inc(Tokens)
 end;
 Step(1,P); Inc(P); Inc(Tokens);
 while P<CTX do begin
  Tok:=Pick; if Tok<=1 then P:=CTX else begin
   Answer:=Answer+Chr(Tok+30);
   if Assigned(OnLetter) then OnLetter(Tok+30);
   Step(Tok,P); Inc(P); Inc(Tokens)
  end
 end
end;
function Clean(Line:String):String;
var I,Lower,Upper:Integer; Q:String;
begin
 Q:=''; Lower:=0; Upper:=0;
 for I:=1 to Length(Line) do
  if (Line[I]>=' ') and (Line[I]<='~') and (Length(Q)<MAXQ) then Q:=Q+Line[I];
 while (Length(Q)>0) and (Q[Length(Q)]=' ') do Delete(Q,Length(Q),1);
 for I:=1 to Length(Q) do begin
  if (Q[I]>='a') and (Q[I]<='z') then Inc(Lower);
  if (Q[I]>='A') and (Q[I]<='Z') then Inc(Upper)
 end;
 if (Upper>0) and (Lower=0) then for I:=1 to Length(Q) do
  if (Q[I]>='A') and (Q[I]<='Z') then Q[I]:=Chr(Ord(Q[I])+32);
 Clean:=Q
end;
function IsWord(Q,W:String):Boolean;
var I:Integer;
begin
 IsWord:=False; if Length(Q)<>Length(W) then Exit;
 for I:=1 to Length(Q) do if UpCase(Q[I])<>UpCase(W[I]) then Exit;
 IsWord:=True
end;
begin
 Creativity:=5; OnLoad:=nil; OnFail:=nil
end.
