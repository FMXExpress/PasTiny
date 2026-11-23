unit ROUTER;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$S-}{$ENDIF}
(* The router: a recurrent network of about two kilobytes that reads a
   request a letter at a time and says which expert should have it.

   The cell is FastGRNN (Kusupati and others, 2018).  For each letter

      a  = W[letter] + U.h
      z  = sigmoid(a + bz)           h~ = tanh(a + bh)
      h  = (zeta.(1 - z) + nu).h~ + z.h

   and the answer is the largest of C.h + bc after the last letter.
   Sigmoid and tanh are the straight-line kinds, the weights are 8-bit
   with one scale (a weight is n / 2^Shift) and the state is 16-bit fixed
   point (1 is 4096), so there is no floating point in it at all.

   training/train_router.py trains it and does these same sums; its
   ROUTER.TXT lists requests with the answers both must give. *)
interface
const RSCREEN=0; RSOUND=1; RTEXT=2; RTASKS=3; RRECIPES=4; RSEVERAL=5;
var RouterReady:Boolean;
(* How far the answer led the next best one; small means unsure. *)
var RouteLead:Longint;
function LoadRouter(Name:String):Boolean;
(* The class of S: small letters, digits, commas and single spaces.  Only
   the first Classes classes can be the answer. *)
function Route(S:String; Classes:Integer):Integer;
implementation
const MAXH=48; MAXK=8; ONE=4096;
type TBytes=array[0..16383] of ShortInt; PBytes=^TBytes;
var H,V,K,Shift:Integer; Zeta,Nu:Longint; Scale:Longint;
 W,U,C:PBytes; Bz,Bh:array[0..MAXH-1] of Integer; Bc:array[0..MAXK-1] of Integer;

function LoadRouter(Name:String):Boolean;
var F:File; Head:record Magic:array[1..4] of Char; H,V,K,S:Byte; Zeta,Nu:Word end; Got:Word; I:Integer;
begin
 LoadRouter:=False; RouterReady:=False;
 Assign(F,Name); {$I-}Reset(F,1);{$I+}
 if IOResult<>0 then Exit;
 {$I-}BlockRead(F,Head,SizeOf(Head),Got);{$I+}
 if (IOResult=0) and (Got=SizeOf(Head)) and (Head.Magic='RTR1') and (Head.H<=MAXH) and (Head.K<=MAXK) and
    (Head.V=29) and (Head.S<=12) then begin
  H:=Head.H; V:=Head.V; K:=Head.K; Shift:=Head.S; Zeta:=Head.Zeta; Nu:=Head.Nu;
  Scale:=1; for I:=1 to Shift do Scale:=Scale*2;
  GetMem(W,V*H); GetMem(U,H*H); GetMem(C,K*H);
  {$I-}
  BlockRead(F,W^,V*H,Got); BlockRead(F,U^,H*H,Got); BlockRead(F,C^,K*H,Got);
  BlockRead(F,Bz,H*2,Got); BlockRead(F,Bh,H*2,Got); BlockRead(F,Bc,K*2,Got);
  {$I+}
  RouterReady:=(IOResult=0) and (Got=K*2)
 end;
 {$I-}Close(F);{$I+} if IOResult<>0 then ;
 LoadRouter:=RouterReady
end;

function Route(S:String; Classes:Integer):Integer;
var Hs,Nw:array[0..MAXH-1] of Integer; P,X,I,J,Best:Integer; A,Acc,Z,Cd,Top,Next:Longint;
begin
 Route:=0; RouteLead:=0;
 if not RouterReady then Exit;
 for I:=0 to H-1 do Hs[I]:=0;
 for P:=1 to Length(S) do begin
  X:=-1;
  if S[P]=' ' then X:=0
  else if (S[P]>='a') and (S[P]<='z') then X:=Ord(S[P])-96
  else if (S[P]>='0') and (S[P]<='9') then X:=27      (* every digit is the same letter *)
  else if S[P]=',' then X:=28;
  if X>=0 then begin
   for I:=0 to H-1 do begin
    Acc:=0;
    for J:=0 to H-1 do Acc:=Acc+Longint(U^[I*H+J])*Hs[J];
    A:=Longint(W^[X*H+I])*(ONE div Scale)+Acc div Scale;
    Z:=(A+Bz[I]) div 4+ONE div 2;
    if Z<0 then Z:=0 else if Z>ONE then Z:=ONE;
    Cd:=A+Bh[I];
    if Cd<-ONE then Cd:=-ONE else if Cd>ONE then Cd:=ONE;
    Nw[I]:=((Zeta*(ONE-Z)) div ONE+Nu)*Cd div ONE+(Z*Hs[I]) div ONE
   end;
   for I:=0 to H-1 do Hs[I]:=Nw[I]
  end
 end;
 if Classes>K then Classes:=K;
 Best:=0; Top:=-MaxLongint; Next:=-MaxLongint;
 for I:=0 to Classes-1 do begin
  Acc:=0;
  for J:=0 to H-1 do Acc:=Acc+Longint(C^[I*H+J])*Hs[J];
  Acc:=Acc div Scale+Bc[I];
  if Acc>Top then begin Next:=Top; Top:=Acc; Best:=I end
  else if Acc>Next then Next:=Acc
 end;
 RouteLead:=Top-Next;
 Route:=Best
end;

begin
 RouterReady:=False
end.
