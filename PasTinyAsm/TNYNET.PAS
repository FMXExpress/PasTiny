unit TNYNET;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$N+}{$E+}{$S-}
{$IFDEF DEBUG}{$R+}{$Q+}{$ELSE}{$R-}{$Q-}{$ENDIF}
interface
(* PasTinyAsm: the limits are cut to the one model shape it uses (D=96,
   HID=256, L=4), which frees about 10 KB of the data segment. *)
const VOCAB=97; CTX=128; MAXD=128; MAXHID=256; MAXL=4; MAXQ=72;
type
 {$IFDEF FPC}TIdx=Longint;{$ELSE}TIdx=Integer;{$ENDIF}
 {$IFNDEF FPC}SmallInt=Integer;{$ENDIF}
 TS8Arr=array[0..64999] of ShortInt; PS8Arr=^TS8Arr;
 TSglArr=array[0..15999] of Single; PSglArr=^TSglArr;
 TVec=array[0..MAXHID-1] of Single; PVec=^TVec;
 TQVec=array[0..MAXHID-1] of SmallInt; PQVec=^TQVec;
 TTable=record Scale:PSglArr; W:PS8Arr; Rows,Cols:TIdx end;
 TStepProc=procedure(I,N:Integer); TLetterProc=procedure(C:Integer);
 TLoadProc=procedure(Done,Total:Integer); TFailProc=procedure;
var D,L,H,HD,HID:Integer; Creativity:Integer; LastConf:Single;
 LayerAct:array[0..MAXL-1] of Single;
 OnLoad:TLoadProc; OnFail:TFailProc;
function TryModel(Name:String; Expected:Longint):Boolean;
var Ready,Cancelled:Boolean; LoadError:String[80];
 ModelXms:Word;    (* PasTinyAsm: 0, or the XMS block TryModel reads the model from *)
procedure AllocMemory;
procedure ReleaseMemory;
procedure Think(Q:String; var Answer:String; var Tokens:Longint;
                OnStep:TStepProc; OnLetter:TLetterProc);
function Clean(Line:String):String;
function IsWord(Q,W:String):Boolean;
(* PasTinyAsm: second choices.  While Think writes an answer it notes the
   places where its first choice led its second by least: Doubt[1] is the
   least sure, At counts the letters of the answer from 1 (one past the end
   is the choice to stop).  ThinkAgain takes the second choice at one such
   place and writes on from there; only that tail is computed again. *)
const MAXDOUBT=3;
(* PasTinyAsm: guided writing.  If Guide is set, it is asked before each
   letter is added to an answer (C=#0: before the answer ends).  When it
   says no, the next best letter is tried, and so on through all of them;
   if none will do the answer comes back empty. *)
type TGuide=function(var Answer:String; C:Char):Boolean;
const MAXTRY=VOCAB;
var Guide:TGuide;
var Doubt:array[1..MAXDOUBT] of record At:Integer; Gap:Single end;
procedure ThinkAgain(Q:String; var Answer:String; At:Integer; OnStep:TStepProc);
procedure Fail(Msg:String);
implementation
uses XMSCACHE;
var Emb,Pos:TTable;
 Wq,Wk,Wv,Wo,F1,F2:array[0..MAXL-1] of TTable;
 G1,G2:array[0..MAXL-1] of PSglArr; Gf:PSglArr;
 Kc,Vc:array[0..MAXL-1] of PS8Arr;
 Ks,Vs:array[0..MAXL-1] of PSglArr;
 (* PasTinyAsm: only Bm is as long as the hidden layer.  The others hold
    as many values as the model is wide, or has letters, or can look
    back, and are on the heap at those sizes, which gives the program
    5 KB back. *)
 Bm:TVec; Bx,Bh,Bq,Bt,Ba,Bs,Score:PVec;
 Xq:TQVec; Qq,Ww:PQVec;
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
const BufSize=512;       (* PasTinyAsm: half a KB, not 4 KB; the program needs the room *)
(* Loading and inference never overlap. Reuse their fixed scratch buffers. *)
var Buffer:array[0..BufSize-1] of Byte absolute Xq;
 Used,Available:Word; Check:Longint; Lookup:array[0..255] of Longint absolute Bm;
 XPos:Longint;      (* how far into the XMS block the reading has got *)
 Reserved:Boolean;
procedure ReserveTable(var T:TTable; Rows,Cols:Integer);
begin
 T.Rows:=Rows; T.Cols:=Cols;
 T.Scale:=Memory(Rows*4); T.W:=Memory(Longint(Rows)*Cols)
end;
procedure Reserve;
var J:Integer;
begin
 D:=96; L:=4; H:=4; HID:=256; HD:=D div H; AttDiv:=Sqrt(HD);
 ReserveTable(Emb,VOCAB,D); ReserveTable(Pos,CTX,D);
 for J:=0 to L-1 do begin
  G1[J]:=Memory(D*4); G2[J]:=Memory(D*4);
  ReserveTable(Wq[J],D,D); ReserveTable(Wk[J],D,D);
  ReserveTable(Wv[J],D,D); ReserveTable(Wo[J],D,D);
  ReserveTable(F1[J],HID,D); ReserveTable(F2[J],D,HID)
 end;
 Gf:=Memory(D*4);
 Reserved:=True
end;
procedure ReadBytes(var Dest; N:Word);
var Offset,Count,J:Word; Err:Integer;
begin
 Offset:=0;
 while (Offset<N) and (LoadError='') do begin
  if Used=Available then begin
   if ModelXms<>0 then begin
    (* from extended memory: the next piece of the 381,808 bytes *)
    Available:=BufSize; Err:=0;
    if 381808-XPos<BufSize then Available:=381808-XPos;
    if Available>0 then if not XmsRead(ModelXms,XPos,Buffer,Available) then Err:=1;
    Inc(XPos,Available)
   end else begin
    {$I-}BlockRead(F,Buffer,BufSize,Available); Err:=IOResult;{$I+}
   end;
   Used:=0;
   if (Err<>0) or (Available=0) then begin LoadError:='read failure'; Exit end;
   for J:=0 to Available-1 do
    Check:=(Check shr 8) xor Lookup[Byte(Check) xor Buffer[J]]
  end;
  Count:=N-Offset;
  if Count>Available-Used then Count:=Available-Used;
  Move(Buffer[Used],TS8Arr(Dest)[Offset],Count);
  Inc(Offset,Count); Inc(Used,Count)
 end
end;
procedure Scalars(var Dest; Count:Word);
var I:Word;
begin
 ReadBytes(Dest,Count*4);
 if LoadError<>'' then Exit;
 for I:=0 to Count-1 do
  if ((Byte(TS8Arr(Dest)[I*4+3]) and $7F)=$7F) and
     ((Byte(TS8Arr(Dest)[I*4+2]) and $80)<>0) then LoadError:='nonfinite scalar'
end;
procedure ReadTable(var T:TTable);
var R:Integer;
begin
 for R:=0 to T.Rows-1 do begin
  Scalars(T.Scale^[R],1); ReadBytes(T.W^[Longint(R)*T.Cols],T.Cols)
 end
end;
function TryModel(Name:String; Expected:Longint):Boolean;
var Header:packed record Magic:array[1..4] of Char; Width,Layers,Heads,Hidden:Word end;
 J,K,Err:Integer; Size,V:Longint;
begin
 Ready:=False; TryModel:=False; LoadError:='';
 if not Reserved then Reserve;
 for J:=0 to 255 do begin
  V:=J;
  for K:=1 to 8 do
   if Odd(V) then V:=(V shr 1) xor Longint($EDB88320) else V:=V shr 1;
  Lookup[J]:=V
 end;
 XPos:=0;
 if ModelXms=0 then begin
  FileMode:=0; Assign(F,Name);
  {$I-}Reset(F,1); Err:=IOResult;{$I+}
  if Err<>0 then begin LoadError:='open failed'; Exit end;
  {$I-}Size:=FileSize(F); Err:=IOResult;{$I+}
  if (Err<>0) or (Size<>381808) then LoadError:='wrong file size'
 end;
 Used:=0; Available:=0; Check:=-1;
 ReadBytes(Header,SizeOf(Header));
 if LoadError='' then
 if (Header.Magic<>'TNY2') or (Header.Width<>D) or (Header.Layers<>L) or
    (Header.Heads<>H) or (Header.Hidden<>HID) then LoadError:='unsupported TNY2 header';
 ReadTable(Emb); ReadTable(Pos);
 for J:=0 to L-1 do begin
  Scalars(G1[J]^[0],D); ReadTable(Wq[J]); ReadTable(Wk[J]);
  ReadTable(Wv[J]); ReadTable(Wo[J]); Scalars(G2[J]^[0],D);
  ReadTable(F1[J]); ReadTable(F2[J])
 end;
 Scalars(Gf^[0],D);
 if ModelXms=0 then begin
  {$I-}Close(F); Err:=IOResult;{$I+}
  if Err<>0 then LoadError:='close failure'
 end;
 if (LoadError='') and ((not Check)<>Expected) then LoadError:='CRC32 mismatch';
 Ready:=LoadError=''; TryModel:=Ready
end;
procedure AllocMemory;
var J,K:Integer;
begin
 for J:=0 to L-1 do begin
  Kc[J]:=Memory(CTX*D); Vc[J]:=Memory(CTX*D);
  Ks[J]:=Memory(CTX*4); Vs[J]:=Memory(CTX*4)
 end;
 Bx:=Memory(D*4); Bh:=Memory(D*4); Bt:=Memory(D*4); Bq:=Bt; Ba:=Bh;
 Bs:=Memory(CTX*4); Score:=Memory(VOCAB*4); Qq:=Memory(D*2); Ww:=Memory(CTX*2);
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
 if not Reserved then Exit;
 Reserved:=False; Ready:=False;
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
 if Gf<>nil then FreeMem(Gf,D*4);
 if Bx<>nil then begin
  FreeMem(Bx,D*4); FreeMem(Bh,D*4); FreeMem(Bt,D*4);
  FreeMem(Bs,CTX*4); FreeMem(Score,VOCAB*4); FreeMem(Qq,D*2); FreeMem(Ww,CTX*2); Bx:=nil
 end
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
  V:=Pos.W^[P*D+I]*Pos.Scale^[P]; Bx^[I]:=S+V
 end;
 for Z:=0 to L-1 do begin
  Norm(Bx^,G1[Z],Bh^);
  Matvec(Wk[Z],Bh^,Bt^); Ks[Z]^[P]:=Store(PS8Arr(@Kc[Z]^[P*D]),Bt^);
  Matvec(Wv[Z],Bh^,Bt^); Vs[Z]^[P]:=Store(PS8Arr(@Vc[Z]^[P*D]),Bt^);
  Matvec(Wq[Z],Bh^,Bq^);
  {$IFNDEF FLOATMATH}Qs:=Quant16(Bq^,D,Qq^);{$ENDIF}
  for Head:=0 to H-1 do begin
   Off:=Head*HD; Big:=-1e30;
   for J:=0 to P do begin
    At:=J*D+Off;
    {$IFDEF FLOATMATH}
    S:=0; for I:=0 to HD-1 do begin
     V:=Bq^[Off+I]*Kc[Z]^[At+I]; S:=S+V
    end;
    {$ELSE}
    Acc:=DotS8I16(PS8Arr(@Kc[Z]^[At]),PQVec(@Qq^[Off])^,HD);
    S:=Acc; S:=S*Qs;
    {$ENDIF}
    S:=S*Ks[Z]^[J]; S:=S/AttDiv; Bs^[J]:=S;
    if S>Big then Big:=S
   end;
   {$IFDEF FLOATMATH}
   Sum:=0;
   for J:=0 to P do begin Bs^[J]:=SafeExp(Bs^[J]-Big); Sum:=Sum+Bs^[J] end;
   for I:=0 to HD-1 do Ba^[Off+I]:=0;
   for J:=0 to P do if Bs^[J]<>0 then begin
    S:=Bs^[J]*Vs[Z]^[J]; S:=S/Sum;
    for I:=0 to HD-1 do begin
     V:=S*Vc[Z]^[J*D+Off+I]; Ba^[Off+I]:=Ba^[Off+I]+V
    end
   end;
   {$ELSE}
   Esum:=0;
   for J:=0 to P do begin
    S:=Big-Bs^[J]; S:=S*128.0;
    if S>=1535.5 then K:=1536 else begin S:=S+0.5; K:=Trunc(S) end;
    if K<1536 then Ee[J]:=ExpTab[K] else Ee[J]:=0;
    Esum:=Esum+Ee[J]
   end;
   Wm:=0; for J:=0 to P do begin
    Bs^[J]:=Ee[J]*Vs[Z]^[J]; if Bs^[J]>Wm then Wm:=Bs^[J]
   end;
   if Wm>0 then Wsc:=Wm/32767.0 else Wsc:=0;
   for J:=0 to P do begin
    if Wsc>0 then begin S:=Bs^[J]/Wsc; S:=S+0.5; Ww^[J]:=Trunc(S) end
    else Ww^[J]:=0
   end;
   for I:=0 to HD-1 do begin
    Acc:=0; for J:=0 to P do Acc:=Acc+Longint(Ww^[J])*Vc[Z]^[J*D+Off+I];
    S:=Acc; S:=S*Wsc; Ba^[Off+I]:=S/Esum
   end;
   {$ENDIF}
  end;
  Matvec(Wo[Z],Ba^,Bt^); for I:=0 to D-1 do Bx^[I]:=Bx^[I]+Bt^[I];
  Norm(Bx^,G2[Z],Bh^); Matvec(F1[Z],Bh^,Bm); S:=0;
  for I:=0 to HID-1 do if Bm[I]<0 then Bm[I]:=0 else S:=S+Bm[I];
  LayerAct[Z]:=S/HID; Matvec(F2[Z],Bm,Bt^);
  for I:=0 to D-1 do Bx^[I]:=Bx^[I]+Bt^[I]
 end;
 Norm(Bx^,Gf,Bh^); Matvec(Emb,Bh^,Score^)
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
 Sum:=0; for I:=0 to VOCAB-1 do Sum:=Sum+SafeExp(Score^[I]-Score^[Tok]);
 LastConf:=1.0/Sum;
 {$ELSE}
 Best:=0; for I:=1 to VOCAB-1 do if Score^[I]>Score^[Best] then Best:=I;
 Sum:=0; for I:=0 to VOCAB-1 do Sum:=Sum+Probability(Score^[Best]-Score^[I]);
 V:=Probability(Score^[Best]-Score^[Tok]); LastConf:=V/Sum;
 {$ENDIF}
 Chosen:=Tok
end;
function Pick:Integer;
var I,Best,Selected:Integer; T,Sum,R,V:Single;
begin
 Best:=0; for I:=1 to VOCAB-1 do if Score^[I]>Score^[Best] then Best:=I;
 Selected:=Best;
 if Creativity>0 then begin
  T:=Creativity/5.0; Sum:=0;
  for I:=0 to VOCAB-1 do begin
   V:=(Score^[Best]-Score^[I])/T; Bs^[I]:=Probability(V);
   if Bs^[I]<0.15 then Bs^[I]:=0; Sum:=Sum+Bs^[I]
  end;
  R:=Sum*Random(10000); R:=R/10000.0;
  I:=0;
  while I<VOCAB do begin
   R:=R-Bs^[I];
   if (R<0) and (Bs^[I]>0) then begin Selected:=I; I:=VOCAB end
   else Inc(I)
  end
 end;
 Pick:=Chosen(Selected)
end;
(* The best choice, and the best of the rest. *)
procedure TopTwo(var Best,Second:Integer);
var I:Integer;
begin
 Best:=0; for I:=1 to VOCAB-1 do if Score^[I]>Score^[Best] then Best:=I;
 if Best=0 then Second:=1 else Second:=0;
 for I:=0 to VOCAB-1 do if (I<>Best) and (Score^[I]>Score^[Second]) then Second:=I
end;

procedure NoteDoubt(At:Integer);
var Best,Second,I,J:Integer; Gap:Single;
begin
 TopTwo(Best,Second); Gap:=Score^[Best]-Score^[Second];
 for I:=1 to MAXDOUBT do if (Doubt[I].At=0) or (Gap<Doubt[I].Gap) then begin
  for J:=MAXDOUBT downto I+1 do Doubt[J]:=Doubt[J-1];
  Doubt[I].At:=At; Doubt[I].Gap:=Gap; Exit
 end
end;

function Allowed(var Answer:String; Tok:Integer):Boolean;
begin
 if not Assigned(Guide) then Allowed:=True
 else if Tok<=1 then Allowed:=Guide(Answer,#0)
 else Allowed:=Guide(Answer,Chr(Tok+30))
end;
(* The best letter the guide allows, or -1. *)
function PickGuided(var Answer:String):Integer;
var Tok,N:Integer;
begin
 Tok:=Pick; N:=1;
 while not Allowed(Answer,Tok) do begin
  if N=MAXTRY then begin PickGuided:=-1; Exit end;
  Inc(N); Score^[Tok]:=-1e30; Tok:=Pick
 end;
 PickGuided:=Tok
end;

procedure ThinkAgain(Q:String; var Answer:String; At:Integer; OnStep:TStepProc);
var P,N,Tok,Best:Integer;
begin
 Cancelled:=False; if not Ready then begin Answer:=''; Exit end;
 Q:=Clean(Q); N:=Length(Q);
 if (At<1) or (At>Length(Answer)+1) then begin Answer:=''; Exit end;
 Answer:=Copy(Answer,1,At-1);
 (* the letter before the place gives the choices at the place once more *)
 if At=1 then Tok:=1 else Tok:=Ord(Answer[At-1])-30;
 P:=N+At-1; Step(Tok,P); Inc(P);
 TopTwo(Best,Tok);
 if not Allowed(Answer,Tok) then Tok:=-1;
 while P<CTX do begin
  if Tok<0 then begin Answer:=''; P:=CTX end
  else if Tok<=1 then P:=CTX else begin
   Answer:=Answer+Chr(Tok+30);
   if Assigned(OnStep) then OnStep(P,CTX);
   if Cancelled then Exit;
   Step(Tok,P); Inc(P);
   Tok:=PickGuided(Answer)
  end
 end
end;

procedure Think(Q:String; var Answer:String; var Tokens:Longint;
                OnStep:TStepProc; OnLetter:TLetterProc);
var P,N,Tok:Integer;
begin
 for P:=1 to MAXDOUBT do Doubt[P].At:=0;
 Cancelled:=False; if not Ready then begin Answer:=''; Tokens:=0; Exit end;
 Q:=Clean(Q); P:=0; N:=Length(Q); Answer:=''; Tokens:=0;
 while P<N do begin
  if Assigned(OnStep) then OnStep(P,N);
  if Cancelled then Exit;
  Step(Ord(Q[P+1])-30,P); Inc(P); Inc(Tokens)
 end;
 Step(1,P); Inc(P); Inc(Tokens);
 while P<CTX do begin
  NoteDoubt(Length(Answer)+1);
  Tok:=PickGuided(Answer);
  if Tok<0 then begin Answer:=''; P:=CTX end
  else if Tok<=1 then P:=CTX else begin
   Answer:=Answer+Chr(Tok+30);
   if Assigned(OnLetter) then OnLetter(Tok+30);
   if Cancelled then Exit;
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
 ModelXms:=0;
 Creativity:=5; OnLoad:=nil; OnFail:=nil; Guide:=nil; Bx:=nil
end.
