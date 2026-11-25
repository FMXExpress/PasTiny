unit TNYNET;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$N+}{$E+}
{$IFDEF DEBUG}{$R+}{$Q+}{$ELSE}{$R-}{$Q-}{$ENDIF}
(* Three engines.  The default does everything in whole numbers.  OLDGLUE
   is the engine before that: whole-number dot products with floating
   point between them (scales, normalising, attention weights).  FLOATMATH
   is floating point throughout.  Without a coprocessor every floating
   point operation is a library call, and in the OLDGLUE engine those
   calls were most of the time. *)
{$IFDEF FLOATMATH}{$DEFINE FLOATGLUE}{$ENDIF}
{$IFDEF OLDGLUE}{$DEFINE FLOATGLUE}{$ENDIF}
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
 {$IFDEF FLOATGLUE}Bx,Bh,Bq,Bt,Ba,Bm,Bs,Score:TVec;{$ENDIF}
 Xq,Qq,Ww:TQVec;
 Ee:array[0..CTX-1] of Longint;
 AttDiv:Single; TablesDone,TablesTotal:Integer;
 F:File;
{$I EXPTAB.INC}
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
{$IFNDEF FLOATGLUE}procedure FixModel; forward;{$ENDIF}
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
 {$IFNDEF FLOATGLUE}FixModel;{$ENDIF}
 {$I-}BlockRead(F,B,1,Got); Err:=IOResult; Close(F);{$I+}
 if (Err<>0) or (Got<>0) then Fail('TINY.BIN has the wrong size.')
end;
procedure AllocMemory;
var J,K:Integer;
begin
 for J:=0 to L-1 do begin
  Kc[J]:=Memory(CTX*D); Vc[J]:=Memory(CTX*D);
  Ks[J]:=Memory(CTX*4); Vs[J]:=Memory(CTX*4)
 end
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
{$IFDEF FLOATGLUE}
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
{$ENDIF}
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
{$IFDEF FLOATGLUE}
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
{$ELSE}
(* ------------------------------------------------ the integer engine

   Every value between the dot products is a 32-bit whole number counting
   65536ths (TFix): the largest value met in the 60 test questions is 170,
   and this holds up to 32767.  What the file gives as floating point is
   turned into whole numbers once, when it is read, by taking the bits of
   each number apart; no floating point operation is used for that either.

     a row's scale     a 16-bit number M and a shift:  scale = M / 2^Sh
     a gain            a whole number of 4096ths

   The three routines everything else rests on:

     QuantFix  a vector as 16-bit numbers and one shift for the dot products
     MulShr    A * M / 2^Sh, the 48-bit product kept whole in between
     ISqrt     the whole-number square root of a 32-bit number  *)
type TFix=array[0..511] of Longint;
 TScale=record M:Word; Sh:Integer end;
 TScaleArr=array[0..15999] of TScale; PScaleArr=^TScaleArr;
 TLongArr=array[0..15999] of Longint; PLongArr=^TLongArr;
var Fx,Fh,Ft,Fq,Fa,Fm,Fsc:TFix;
 Tw:array[0..CTX-1] of Longint;         (* attention weight times value scale *)
 Pr:array[0..VOCAB-1] of Longint;       (* chances of the letters, for Pick *)
 VMax:array[0..MAXL-1] of Longint;      (* largest value scale kept so far *)
 SqrtD:Longint; AttM:Word; AttSh:Integer;

{$IFDEF VER70}
function MulShr(A:Longint; M:Word; Sh:Integer):Longint; assembler;
asm
 mov ax,word ptr A
 mov dx,word ptr A+2
 mov di,dx
 or dx,dx
 jns @pos
 neg dx
 neg ax
 sbb dx,0
@pos:
 mov cx,dx
 mul word ptr M
 mov bx,ax
 mov si,dx
 mov ax,cx
 mul word ptr M
 add si,ax
 adc dx,0
 mov cx,Sh
 or cx,cx
 jle @sign
 dec cx
@words:
 cmp cx,16
 jb @bits
 mov bx,si
 mov si,dx
 xor dx,dx
 sub cx,16
 jmp @words
@bits:
 jcxz @round
@bit:
 shr dx,1
 rcr si,1
 rcr bx,1
 loop @bit
@round:
 add bx,1
 adc si,0
 adc dx,0
 shr dx,1
 rcr si,1
 rcr bx,1
@sign:
 mov ax,bx
 mov dx,si
 or di,di
 jns @out
 neg dx
 neg ax
 sbb dx,0
@out:
end;
(* The sum of N products of a byte, every Stride bytes from V on, and a
   16-bit number. *)
function DotStride(V:PS8Arr; Stride:Word; var W:TQVec; N:Word):Longint; assembler;
var Hi:Word;
asm
 push ds
 mov Hi,0
 xor bx,bx
 mov cx,N
 lds si,V
 les di,W
 jcxz @done
@loop:
 mov al,[si]
 cbw
 imul word ptr es:[di]
 add bx,ax
 adc Hi,dx
 add si,Stride
 add di,2
 loop @loop
@done:
 pop ds
 mov ax,bx
 mov dx,Hi
end;
{$ELSE}
function MulShr(A:Longint; M:Word; Sh:Integer):Longint;
var P:Int64;
begin
 P:=Int64(Abs(A))*M;
 if Sh>0 then P:=(P+(Int64(1) shl (Sh-1))) shr Sh;
 if A<0 then MulShr:=-Longint(P) else MulShr:=Longint(P)
end;
function DotStride(V:PS8Arr; Stride:Word; var W:TQVec; N:Word):Longint;
var J:TIdx; A:Longint;
begin
 A:=0; for J:=0 to N-1 do A:=A+Longint(W[J])*V^[Longint(J)*Stride]; DotStride:=A
end;
{$ENDIF}

function ISqrt(N:Longint):Longint;
var R,B,T:Longint;
begin
 R:=0; B:=$40000000;
 while B>N do B:=B shr 2;
 while B<>0 do begin
  T:=R+B;
  if N>=T then begin N:=N-T; R:=(R shr 1)+B end else R:=R shr 1;
  B:=B shr 2
 end;
 ISqrt:=R
end;

(* 1/Den as a 16-bit number M and a shift:  1/Den = M / 2^Sh. *)
procedure Recip(Den:Longint; var M:Word; var Sh:Integer);
var A:Integer;
begin
 A:=0;
 while Den>65535 do begin Den:=Den shr 1; Inc(A) end;
 while Den<32768 do begin Den:=Den shl 1; Dec(A) end;
 Den:=$7FFFFFFF div Den; if Den>65535 then Den:=65535;
 M:=Den; Sh:=31+A
end;

(* The file's floating point numbers, taken apart: a row scale as M and a
   shift, a gain as 4096ths. *)
procedure FixScales(var T:TTable);
var R:TIdx; B:Longint;
begin
 for R:=0 to T.Rows-1 do begin
  B:=PLongArr(T.Scale)^[R];
  with PScaleArr(T.Scale)^[R] do
   if B<=0 then begin M:=0; Sh:=0 end
   else begin Sh:=142-Integer((B shr 23) and 255); M:=((B and $7FFFFF) or $800000) shr 8 end
 end
end;
procedure FixGains(G:PSglArr);
var I:TIdx; B,M:Longint; S:Integer;
begin
 for I:=0 to D-1 do begin
  B:=PLongArr(G)^[I]; M:=0;
  if B and $7FFFFFFF<>0 then begin
   M:=(B and $7FFFFF) or $800000; S:=138-Integer((B shr 23) and 255);
   if S>=31 then M:=0
   else if S>0 then M:=(M+(Longint(1) shl (S-1))) shr S
   else if S<0 then M:=M shl (-S);
   if B<0 then M:=-M
  end;
  PLongArr(G)^[I]:=M
 end
end;
procedure FixModel;
var J:Integer;
begin
 FixScales(Emb); FixScales(Pos);
 for J:=0 to L-1 do begin
  FixGains(G1[J]); FixGains(G2[J]);
  FixScales(Wq[J]); FixScales(Wk[J]); FixScales(Wv[J]); FixScales(Wo[J]);
  FixScales(F1[J]); FixScales(F2[J]); VMax[J]:=1
 end;
 FixGains(Gf);
 SqrtD:=ISqrt(Longint(D) shl 24);                       (* sqrt(D) in 4096ths *)
 Recip(127*ISqrt(Longint(HD) shl 24),AttM,AttSh)        (* 1 / (127 sqrt(HD)), sqrt in 4096ths *)
end;

(* X as 16-bit numbers:  X[i] is about Q[i] * 2^S.  The largest takes 15 bits. *)
function QuantFix(var X:TFix; N:Integer; var Q:TQVec):Integer;
var I:TIdx; M,V,Half:Longint; S:Integer;
begin
 M:=0; for I:=0 to N-1 do begin V:=Abs(X[I]); if V>M then M:=V end;
 S:=0;
 if M=0 then begin for I:=0 to N-1 do Q[I]:=0; QuantFix:=0; Exit end;
 while (M shr S)>32766 do Inc(S);
 if S>0 then begin
  Half:=Longint(1) shl (S-1);
  for I:=0 to N-1 do begin
   V:=X[I]; if V<0 then Q[I]:=-((Half-V) shr S) else Q[I]:=(V+Half) shr S
  end
 end else begin
  while (M shl 1)<=32766 do begin M:=M shl 1; Dec(S) end;
  for I:=0 to N-1 do Q[I]:=X[I] shl (-S)
 end;
 QuantFix:=S
end;

(* Y = T times the vector Q * 2^S. *)
procedure MatFix(var T:TTable; var Q:TQVec; S:Integer; var Y:TFix);
var R:TIdx; Offset:Longint;
begin
 Offset:=0;
 for R:=0 to T.Rows-1 do begin
  with PScaleArr(T.Scale)^[R] do
   Y[R]:=MulShr(DotS8I16(PS8Arr(@T.W^[Offset]),Q,T.Cols),M,Sh-S);
  Inc(Offset,T.Cols)
 end
end;

(* Y = X divided by its root mean square, times the gains.  The square root
   is taken of 12-bit numbers, whose 96 squares fit in 32 bits; the
   division is by a 16-bit reciprocal. *)
procedure NormFix(var X:TFix; G:PSglArr; var Y:TFix);
var I:TIdx; S,E:Integer; Acc,F,V:Longint;
begin
 S:=QuantFix(X,D,Xq); Acc:=0;
 for I:=0 to D-1 do begin V:=Xq[I] div 8; Acc:=Acc+V*V end;
 if Acc=0 then begin for I:=0 to D-1 do Y[I]:=0; Exit end;
 F:=(SqrtD shl 15) div ISqrt(Acc); E:=0;
 while F>65535 do begin F:=F shr 1; Inc(E) end;
 for I:=0 to D-1 do Y[I]:=MulShr(Longint(Xq[I])*PLongArr(G)^[I],F,26-E)
end;

(* Keep Src as bytes, the largest as 127.  Returns that largest value. *)
function StoreFix(Dst:PS8Arr; var Src:TFix):Longint;
var I:TIdx; Big,V,Den:Longint; Sh:Integer;
begin
 Big:=0; for I:=0 to D-1 do begin V:=Abs(Src[I]); if V>Big then Big:=V end;
 if Big=0 then Big:=1;
 Sh:=0; while (Big shr Sh)>$7FFFFF do Inc(Sh);
 Den:=Big shr Sh;
 for I:=0 to D-1 do begin
  V:=((Abs(Src[I]) shr Sh)*127+Den shr 1) div Den;
  if Src[I]<0 then Dst^[I]:=-V else Dst^[I]:=V
 end;
 StoreFix:=Big
end;

function ExpOf(Diff:Longint; Shift:Integer):Longint;
begin
 Diff:=(Diff+(Longint(1) shl (Shift-1))) shr Shift;
 if Diff>1535 then ExpOf:=0 else ExpOf:=ExpTab[Diff]
end;

procedure Step(Tok,P:Integer);
var I,J,Z,Head,Off:TIdx; S,Sq,Sw,Vsh:Integer; Big,Acc,Esum,V,Wm:Longint; Rm:Word; Rs:Integer;
 E:array[0..CTX-1] of Longint;
begin
 (* a new text: forget the value scales of the last one, so that an answer
    does not depend on what was asked before *)
 if P=0 then for Z:=0 to L-1 do VMax[Z]:=1;
 for I:=0 to D-1 do begin
  with PScaleArr(Emb.Scale)^[Tok] do V:=MulShr(Emb.W^[Tok*D+I],M,Sh-16);
  with PScaleArr(Pos.Scale)^[P] do Fx[I]:=V+MulShr(Pos.W^[P*D+I],M,Sh-16)
 end;
 for Z:=0 to L-1 do begin
  NormFix(Fx,G1[Z],Fh); S:=QuantFix(Fh,D,Xq);
  (* the key of this place: its bytes, and its scale over 127 sqrt(HD) *)
  MatFix(Wk[Z],Xq,S,Ft); Big:=StoreFix(PS8Arr(@Kc[Z]^[P*D]),Ft);
  Sw:=0; while Big>65535 do begin Big:=Big shr 1; Inc(Sw) end;
  with PScaleArr(Ks[Z])^[P] do begin M:=MulShr(Big,AttM,16); Sh:=AttSh+4-Sw-16 end;
  MatFix(Wv[Z],Xq,S,Ft); Big:=StoreFix(PS8Arr(@Vc[Z]^[P*D]),Ft);
  PLongArr(Vs[Z])^[P]:=Big; if Big>VMax[Z] then VMax[Z]:=Big;
  MatFix(Wq[Z],Xq,S,Fq); Sq:=QuantFix(Fq,D,Qq);
  Vsh:=0; while (VMax[Z] shr Vsh)>32767 do Inc(Vsh);
  for Head:=0 to H-1 do begin
   Off:=Head*HD; Big:=-MaxLongint;
   (* how well each earlier place answers this one, in 1024ths *)
   for J:=0 to P do begin
    with PScaleArr(Ks[Z])^[J] do
     V:=MulShr(DotS8I16(PS8Arr(@Kc[Z]^[J*D+Off]),PQVec(@Qq[Off])^,HD),M,Sh+6-Sq);
    E[J]:=V; if V>Big then Big:=V
   end;
   Esum:=0; Wm:=0;
   for J:=0 to P do begin
    V:=ExpOf(Big-E[J],3); Esum:=Esum+V;
    V:=V*(PLongArr(Vs[Z])^[J] shr Vsh); Tw[J]:=V; if V>Wm then Wm:=V
   end;
   Sw:=0; while (Wm shr Sw)>32767 do Inc(Sw);
   for J:=0 to P do Ww[J]:=Tw[J] shr Sw;
   Recip(127*Esum,Rm,Rs);
   for I:=0 to HD-1 do
    Fa[Off+I]:=MulShr(DotStride(PS8Arr(@Vc[Z]^[Off+I]),D,Ww,P+1),Rm,Rs-Sw-Vsh)
  end;
  S:=QuantFix(Fa,D,Xq); MatFix(Wo[Z],Xq,S,Ft);
  for I:=0 to D-1 do Fx[I]:=Fx[I]+Ft[I];
  NormFix(Fx,G2[Z],Fh); S:=QuantFix(Fh,D,Xq); MatFix(F1[Z],Xq,S,Fm);
  Acc:=0;
  for I:=0 to HID-1 do if Fm[I]<0 then Fm[I]:=0 else Acc:=Acc+Fm[I] shr 8;
  LayerAct[Z]:=Acc/(256.0*HID);
  S:=QuantFix(Fm,HID,Xq); MatFix(F2[Z],Xq,S,Ft);
  for I:=0 to D-1 do Fx[I]:=Fx[I]+Ft[I]
 end;
 NormFix(Fx,Gf,Fh); S:=QuantFix(Fh,D,Xq); MatFix(Emb,Xq,S,Fsc)
end;

function Chosen(Tok:Integer):Integer;
var I,Best:Integer; Sum:Longint;
begin
 Best:=0; for I:=1 to VOCAB-1 do if Fsc[I]>Fsc[Best] then Best:=I;
 Sum:=0; for I:=0 to VOCAB-1 do Sum:=Sum+ExpOf(Fsc[Best]-Fsc[I],9);
 LastConf:=ExpOf(Fsc[Best]-Fsc[Tok],9)/Sum;
 Chosen:=Tok
end;
function Pick:Integer;
var I,Best,Selected:Integer; Sum,Cum,R:Longint;
begin
 Best:=0; for I:=1 to VOCAB-1 do if Fsc[I]>Fsc[Best] then Best:=I;
 Selected:=Best;
 if Creativity>0 then begin
  (* a letter's chance: exp of how far it is behind the best, over
     Creativity/5; letters under 0.15 are left out *)
  Sum:=0;
  for I:=0 to VOCAB-1 do begin
   Pr[I]:=ExpOf((Fsc[Best]-Fsc[I])*5 div Creativity,9);
   if Pr[I]<4916 then Pr[I]:=0; Sum:=Sum+Pr[I]
  end;
  R:=MulShr(Sum,Random(10000),4); Cum:=0;
  I:=0;
  while I<VOCAB do begin
   Cum:=Cum+Pr[I];
   if (Pr[I]>0) and (R<MulShr(Cum,10000,4)) then begin Selected:=I; I:=VOCAB end
   else Inc(I)
  end
 end;
 Pick:=Chosen(Selected)
end;
{$ENDIF}
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
