{$IFNDEF TINYMODERN}unit TnyNet;{$ENDIF}

(* TINY 2.1 for Delphi 1 - the neural network.

   A port of the network part of TINY.C (Turbo C 2.0, by WollyMonjac).
   It reads the unchanged TINY.BIN and answers one letter at a time.

   Two engines, chosen at run time with UseInt:
     integer engine (default) - the heavy loops are 8-bit x 16-bit integer
                                multiply-adds; fast without a coprocessor
     float engine (/FLOAT)    - the original all-float code, for comparison

   Plain Object Pascal with no units, so the same file also compiles with
   Free Pascal ({$MODE TP}) for automated tests on a modern machine.
   Under Delphi 1 (VER80) the two inner loops are 8086 assembler. *)

{$IFDEF FPC}
  {$IFDEF TINYMODERN}{$MODE DELPHIUNICODE}{$ELSE}{$MODE TP}{$ENDIF}
{$ENDIF}
{$IFDEF TINYMODERN}{$R-,X+}{$ELSE}{$F+,R-,S-,X+}{$ENDIF}

interface

const
  VOCAB  = 97;     { 0 end, 1 newline, 2.. the letters ' '..'~' }
  CTX    = 128;    { longest question + answer, in letters      }
  MAXD   = 128;
  MAXHID = 512;
  MAXL   = 8;
  MAXQ   = 72;     { longest question, in letters }
  NBENCH = 5;

type
  PS8Arr   = ^TS8Arr;
  TS8Arr   = array[0..65000] of ShortInt;
  PSglArr  = ^TSglArr;
  TSglArr  = array[0..16000] of Single;
  TQuantValue = {$IFDEF TINYMODERN}SmallInt{$ELSE}Integer{$ENDIF};
  TReadCount = {$IFDEF TINYMODERN}Longint{$ELSE}Word{$ENDIF};
  PI16Arr  = ^TI16Arr;
  TI16Arr  = array[0..32000] of TQuantValue;
  PLongArr = ^TLongArr;
  TLongArr = array[0..16000] of Longint;

  TTable = record
    Scale: PSglArr;
    W: PS8Arr;
    Rows, Cols: Integer;
  end;

  TFailProc   = procedure(const Msg: String);
  TLoadProc   = procedure(Done, Total: Integer);
  TStepProc   = procedure(I, N: Integer);
  TLetterProc = procedure(C: Integer);
  TClockFunc  = function: Longint;          { milliseconds }
  TIdleProc   = procedure;

var
  D, L, H, HD, HID: Integer;
  LayerAct: array[0..MAXL - 1] of Single;   { how busy each layer was }
  Score: array[0..VOCAB - 1] of Single;
  Creativity: Integer;                      { 0 surest .. 9 wild }
  LastConf: Single;                         { how sure of the last letter }
  UseInt: Boolean;                          { integer engine? }
  AbortThink: Boolean;                      { set to stop think() early }
  OnFail: TFailProc;                        { nil: write to Output, Halt }
  OnLoad: TLoadProc;                        { loading progress, may be nil }
  ClockMs: TClockFunc;                      { may be nil (times are 0) }
  {$IFDEF TINYMODERN}OnAnswer: procedure(const Answer: String);{$ENDIF}
  OnIdle: TIdleProc;                        { called once per letter }

const
  BenchQ: array[1..NBENCH] of String[40] = (
    'what is the capital of peru', 'is a whale a fish', 'what is 7 times 8',
    'which countries border estonia', 'spell elephant');

procedure Fail(const Msg: String);
procedure LoadModel(const Name: String);
procedure AllocMemory;
function Think(const Q: String; var Answer: String; var Tenths: Longint;
  OnStep: TStepProc; OnLetter: TLetterProc): Integer;
function Clean(const Line: String; var Q: String): Integer;
function IsWord(const Q, W: String): Boolean;
function NumStr(N: Longint): String;
function TenthsStr(T: Longint): String;
procedure PlainRun(var Fin, Fout: Text);
procedure RunBench(var Fout: Text; const Build: String; Fpu: Integer);

implementation

var
  AttDiv: Single;
  Emb, PosT: TTable;
  WQ, WK, WV, WO, F1, F2: array[0..MAXL - 1] of TTable;
  G1, G2: array[0..MAXL - 1] of PSglArr;
  GF: PSglArr;
  TablesDone, TablesTotal: Integer;
  ModelFile: file;

  (* Memory of earlier letters: for every layer and position, the key and
     value lists of D numbers, kept as bytes with one scale per list. *)
  KC, VC: array[0..MAXL - 1] of PS8Arr;
  KS, VS: array[0..MAXL - 1] of PSglArr;

  { work buffers }
  BX, BH, BQ, BT, BA: array[0..MAXD - 1] of Single;
  BM: array[0..MAXHID - 1] of Single;
  BS: array[0..CTX - 1] of Single;

  { integer engine }
  XQ: array[0..MAXHID - 1] of TQuantValue;      { input vector as 16-bit }
  QQ: array[0..MAXD - 1] of TQuantValue;        { query as 16-bit }
  WW: array[0..CTX - 1] of TQuantValue;         { attention weights, 16-bit }
  EE: array[0..CTX - 1] of Longint;
  ACC: array[0..MAXD - 1] of Longint;
  ExpTab: array[0..1535] of Integer;        { exp(-k/128) * 32767 }

{ ---- errors and loading ------------------------------------------- }

procedure Fail(const Msg: String);
begin
  if Assigned(OnFail) then
    OnFail(Msg);
  WriteLn;
  WriteLn('TINY: ', Msg);
  Halt(1);
end;

procedure Damaged;
begin
  Fail('TINY.BIN is too short or damaged.');
end;

function GetMemory(N: Word): Pointer;
var
  P: Pointer;
begin
  GetMem(P, N);
  if P = nil then
    Fail('not enough memory.');
  GetMemory := P;
end;

procedure ReadBytes(var Buf; N: Word);
var
  Got: TReadCount;
begin
  {$I-}
  BlockRead(ModelFile, Buf, N, Got);
  {$I+}
  if (IOResult <> 0) or (Got <> N) then
    Damaged;
end;

function Read16: Integer;
var
  B: array[0..1] of Byte;
begin
  ReadBytes(B, 2);
  Read16 := Integer(Word(B[0]) or (Word(B[1]) shl 8));
end;

procedure LoadTable(var T: TTable; Rows, Cols: Integer);
var
  R: Integer;
begin
  T.Rows := Rows;
  T.Cols := Cols;
  if Longint(Rows) * Cols > 65000 then
    Fail('a table in TINY.BIN is too big.');
  T.Scale := GetMemory(Word(Rows) * 4);
  T.W := GetMemory(Word(Longint(Rows) * Cols));
  for R := 0 to Rows - 1 do
  begin
    ReadBytes(T.Scale^[R], 4);
    ReadBytes(T.W^[Word(Longint(R) * Cols)], Cols);
  end;
  Inc(TablesDone);
  if Assigned(OnLoad) then
    OnLoad(TablesDone, TablesTotal);
end;

function LoadGains: PSglArr;
var
  G: PSglArr;
begin
  G := GetMemory(Word(D) * 4);
  ReadBytes(G^, Word(D) * 4);
  LoadGains := G;
end;

procedure InitExpTab;
var
  K: Integer;
begin
  for K := 0 to 1535 do
    ExpTab[K] := Trunc(Exp(-K / 128.0) * 32767.0 + 0.5);
end;

procedure LoadModel(const Name: String);
var
  Magic: array[0..3] of Byte;
  I, Code: Integer;
  B: Byte;
  Got: TReadCount;
begin
  if SizeOf(Single) <> 4 then
    Fail('this compiler has an unusual Single size.');
  InitExpTab;
  {$IFDEF TINYMODERN}AssignFile{$ELSE}Assign{$ENDIF}(ModelFile, Name);
  FileMode := 0;
  {$I-}
  Reset(ModelFile, 1);
  {$I+}
  if IOResult <> 0 then
    Fail('cannot open TINY.BIN. Keep it in the same directory as TINY.EXE.');
  {$I-}
  BlockRead(ModelFile, Magic, 4, Got);
  {$I+}
  Code := IOResult;
  if (Code <> 0) or (Got <> 4) or (Magic[0] <> Ord('T')) or (Magic[1] <> Ord('N')) or
     (Magic[2] <> Ord('Y')) or (Magic[3] <> Ord('2')) then
    Fail('TINY.BIN is not a version 2 network file.');
  D := Read16; L := Read16; H := Read16; HID := Read16;
  if (D < 8) or (D > MAXD) or (L < 1) or (L > MAXL) or (H < 1) or
     (D mod H <> 0) or (HID < 8) or (HID > MAXHID) then
    Fail('TINY.BIN has a network size this program cannot handle.');
  HD := D div H;
  TablesDone := 0;
  TablesTotal := 2 + 6 * L;
  AttDiv := Sqrt(HD);
  LoadTable(Emb, VOCAB, D);
  LoadTable(PosT, CTX, D);
  for I := 0 to L - 1 do
  begin
    G1[I] := LoadGains;
    LoadTable(WQ[I], D, D);
    LoadTable(WK[I], D, D);
    LoadTable(WV[I], D, D);
    LoadTable(WO[I], D, D);
    G2[I] := LoadGains;
    LoadTable(F1[I], HID, D);
    LoadTable(F2[I], D, HID);
  end;
  GF := LoadGains;
  {$I-}
  BlockRead(ModelFile, B, 1, Got);
  {$I+}
  Code := IOResult;
  if (Code <> 0) or (Got <> 0) then
    Fail('TINY.BIN has the wrong size.');
  {$IFDEF TINYMODERN}CloseFile{$ELSE}Close{$ENDIF}(ModelFile);
end;

procedure AllocMemory;
var
  I: Integer;
begin
  for I := 0 to L - 1 do
  begin
    KC[I] := GetMemory(Word(CTX) * Word(D));
    VC[I] := GetMemory(Word(CTX) * Word(D));
    KS[I] := GetMemory(CTX * 4);
    VS[I] := GetMemory(CTX * 4);
  end;
end;

{ ---- integer kernels -------------------------------------------------- }

{$IFDEF VER80}
{$DEFINE TINYASM}
{$ENDIF}
{$IFDEF NOASM}
{$UNDEF TINYASM}
{$ENDIF}

{$IFDEF TINYASM}

(* Sum of W[i] * X[i] for i = 0..N-1: 8-bit times 16-bit, 32-bit sum.
   8086 code: IMUL gives the 32-bit product in DX:AX. *)
function DotS8I16(W, X: Pointer; N: Integer): Longint; assembler;
asm
        push  ds
        mov   cx, N
        lds   si, W
        les   di, X
        push  bp
        xor   bx, bx
        xor   bp, bp
        jcxz  @done
@again:
        lodsb
        cbw
        imul  word ptr es:[di]
        add   bx, ax
        adc   bp, dx
        add   di, 2
        loop  @again
@done:
        mov   ax, bx
        mov   dx, bp
        pop   bp
        pop   ds
end;

{ A[i] := A[i] + Wt * V[i] for i = 0..N-1  (32-bit A, 8-bit V) }
procedure AxpyS8(A, V: Pointer; Wt, N: Integer); assembler;
asm
        push  ds
        mov   cx, N
        mov   bx, Wt
        lds   si, V
        les   di, A
        jcxz  @done
@again:
        lodsb
        cbw
        imul  bx
        add   word ptr es:[di], ax
        adc   word ptr es:[di+2], dx
        add   di, 4
        loop  @again
@done:
        pop   ds
end;

{$ELSE}

function DotS8I16(W, X: Pointer; N: Integer): Longint;
var
  I: Integer;
  S: Longint;
begin
  S := 0;
  for I := 0 to N - 1 do
    S := S + Longint(PS8Arr(W)^[I]) * PI16Arr(X)^[I];
  DotS8I16 := S;
end;

procedure AxpyS8(A, V: Pointer; Wt, N: Integer);
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    PLongArr(A)^[I] := PLongArr(A)^[I] + Longint(Wt) * PS8Arr(V)^[I];
end;

{$ENDIF}

{ ---- the network ------------------------------------------------------ }

(* Quantise X[0..N-1] to 16-bit Q (rounded half away from zero) and return
   the scale, so that X[i] = Q[i] * scale. *)
function Quant16(X: PSglArr; N: Integer; Q: PI16Arr): Single;
var
  I: Integer;
  M, V, K: Single;
begin
  M := 0;
  for I := 0 to N - 1 do
  begin
    V := Abs(X^[I]);
    if V > M then M := V;
  end;
  if M < 1E-20 then
  begin
    for I := 0 to N - 1 do Q^[I] := 0;
    Quant16 := 0;
    Exit;
  end;
  K := 32767.0 / M;
  for I := 0 to N - 1 do
  begin
    V := X^[I] * K;
    if V < 0 then V := V - 0.5 else V := V + 0.5;
    if V > 32767 then V := 32767;
    if V < -32767 then V := -32767;
    Q^[I] := Trunc(V);
  end;
  M := M / 32767.0;
  Quant16 := M;
end;

{ Y = table * X }
procedure MatVec(const T: TTable; X, Y: PSglArr);
var
  R, C, Cols: Integer;
  Off: Word;
  S, SX: Single;
  A: Longint;
begin
  Cols := T.Cols;
  if UseInt then
  begin
    SX := Quant16(X, Cols, @XQ);
    for R := 0 to T.Rows - 1 do
    begin
      Off := Word(Longint(R) * Cols);
      A := DotS8I16(@T.W^[Off], @XQ, Cols);
      S := A;
      S := S * T.Scale^[R];
      Y^[R] := S * SX;
    end;
  end
  else
    for R := 0 to T.Rows - 1 do
    begin
      Off := Word(Longint(R) * Cols);
      S := 0;
      for C := 0 to Cols - 1 do
        S := S + T.W^[Off + Word(C)] * X^[C];
      Y^[R] := S * T.Scale^[R];
    end;
end;

{ Y = X scaled to a standard size, times the gains G }
procedure Norm(X, G, Y: PSglArr);
var
  I: Integer;
  S: Single;
begin
  S := 0;
  for I := 0 to D - 1 do
    S := S + X^[I] * X^[I];
  S := 1.0 / Sqrt(S / D + 1E-5);
  for I := 0 to D - 1 do
    Y^[I] := X^[I] * S * G^[I];
end;

{ e to the power X, quietly 0 for very negative X }
function SafeExp(X: Single): Single;
begin
  if X < -60.0 then
    SafeExp := 0
  else
    SafeExp := Exp(X);
end;

{ keep a list of D numbers as bytes, returning the scale }
function Store(Dst: PS8Arr; Src: PSglArr): Single;
var
  I: Integer;
  Big, V, K: Single;
begin
  Big := 0;
  for I := 0 to D - 1 do
  begin
    V := Abs(Src^[I]);
    if V > Big then Big := V;
  end;
  if Big < 1E-20 then
    Big := 1E-20;
  K := 127.0 / Big;
  for I := 0 to D - 1 do
  begin
    V := Src^[I] * K;
    if V < 0 then V := V - 0.5 else V := V + 0.5;
    Dst^[I] := Trunc(V);
  end;
  V := Big / 127.0;
  Store := V;
end;

{ attention for one layer at position P, float engine }
procedure AttendFloat(Lr, P: Integer);
var
  Hh, I, J, HOff: Integer;
  Off: Word;
  S, Big, Sum: Single;
begin
  for Hh := 0 to H - 1 do
  begin
    HOff := Hh * HD;
    Big := -1E30;
    for J := 0 to P do
    begin
      Off := Word(J * D + HOff);
      S := 0;
      for I := 0 to HD - 1 do
        S := S + BQ[HOff + I] * KC[Lr]^[Off + Word(I)];
      S := S * KS[Lr]^[J] / AttDiv;
      BS[J] := S;
      if S > Big then Big := S;
    end;
    Sum := 0;
    for J := 0 to P do
    begin
      BS[J] := SafeExp(BS[J] - Big);
      Sum := Sum + BS[J];
    end;
    for I := 0 to HD - 1 do
      BA[HOff + I] := 0;
    for J := 0 to P do
    begin
      if BS[J] = 0 then Continue;
      Off := Word(J * D + HOff);
      S := BS[J] * VS[Lr]^[J] / Sum;
      for I := 0 to HD - 1 do
        BA[HOff + I] := BA[HOff + I] + S * VC[Lr]^[Off + Word(I)];
    end;
  end;
end;

{ attention for one layer at position P, integer engine }
procedure AttendInt(Lr, P: Integer);
var
  Hh, I, J, HOff: Integer;
  Off: Word;
  S, Big, QS, WM, WSc, T: Single;
  ESum, Dt: Longint;
begin
  QS := Quant16(@BQ, D, @QQ);
  for Hh := 0 to H - 1 do
  begin
    HOff := Hh * HD;
    Big := -1E30;
    for J := 0 to P do
    begin
      Off := Word(J * D + HOff);
      Dt := DotS8I16(@KC[Lr]^[Off], @QQ[HOff], HD);
      S := Dt;
      S := S * QS;
      S := S * KS[Lr]^[J];
      S := S / AttDiv;
      BS[J] := S;
      if S > Big then Big := S;
    end;
    ESum := 0;
    for J := 0 to P do
    begin
      T := (Big - BS[J]) * 128.0 + 0.5;
      if T < 1536.0 then EE[J] := ExpTab[Trunc(T)] else EE[J] := 0;
      ESum := ESum + EE[J];
    end;
    WM := 0;
    for J := 0 to P do
    begin
      S := EE[J];
      S := S * VS[Lr]^[J];
      BS[J] := S;
      if S > WM then WM := S;
    end;
    if WM > 0 then WSc := WM / 32767.0 else WSc := 0;
    for J := 0 to P do
      if WSc > 0 then
      begin
        T := BS[J] / WSc + 0.5;
        if T > 32767 then T := 32767;
        WW[J] := Trunc(T);
      end
      else
        WW[J] := 0;
    for I := 0 to HD - 1 do
      ACC[I] := 0;
    for J := 0 to P do
      if WW[J] <> 0 then
        AxpyS8(@ACC, @VC[Lr]^[Word(J * D + HOff)], WW[J], HD);
    for I := 0 to HD - 1 do
    begin
      S := ACC[I];
      S := S * WSc;
      BA[HOff + I] := S / ESum;
    end;
  end;
end;

(* Feed letter number Tok at position P (0, 1, 2, ...).
   Fills Score[0..VOCAB-1]: how well each letter fits as the next one. *)
procedure Step(Tok, P: Integer);
var
  I, Lr: Integer;
  EOff, POff: Word;
  S, ES, PS: Single;
begin
  EOff := Word(Tok * D);
  POff := Word(P * D);
  ES := Emb.Scale^[Tok];
  PS := PosT.Scale^[P];
  for I := 0 to D - 1 do
    BX[I] := Emb.W^[EOff + Word(I)] * ES + PosT.W^[POff + Word(I)] * PS;

  for Lr := 0 to L - 1 do
  begin
    { look back at the earlier letters }
    Norm(@BX, G1[Lr], @BH);
    MatVec(WK[Lr], @BH, @BT);
    KS[Lr]^[P] := Store(@KC[Lr]^[Word(P * D)], @BT);
    MatVec(WV[Lr], @BH, @BT);
    VS[Lr]^[P] := Store(@VC[Lr]^[Word(P * D)], @BT);
    MatVec(WQ[Lr], @BH, @BQ);
    if UseInt then AttendInt(Lr, P) else AttendFloat(Lr, P);
    MatVec(WO[Lr], @BA, @BT);
    for I := 0 to D - 1 do
      BX[I] := BX[I] + BT[I];

    { think about it }
    Norm(@BX, G2[Lr], @BH);
    MatVec(F1[Lr], @BH, @BM);
    S := 0;
    for I := 0 to HID - 1 do
      if BM[I] < 0 then BM[I] := 0
      else S := S + BM[I];
    LayerAct[Lr] := S / HID;
    MatVec(F2[Lr], @BM, @BT);
    for I := 0 to D - 1 do
      BX[I] := BX[I] + BT[I];
  end;
  Norm(@BX, GF, @BH);
  MatVec(Emb, @BH, @Score);
end;

{ ---- choosing letters ------------------------------------------------- }

function Chosen(Tok: Integer): Integer;
var
  I: Integer;
  Sum: Single;
begin
  Sum := 0;
  for I := 0 to VOCAB - 1 do
    Sum := Sum + SafeExp(Score[I] - Score[Tok]);
  LastConf := 1.0 / Sum;
  Chosen := Tok;
end;

(* Pick the next letter. With creativity 0 it is always the best one.
   Otherwise choose at random among the letters that fit nearly as well. *)
function Pick: Integer;
var
  I, Best: Integer;
  T, Sum, R: Single;
begin
  Best := 0;
  for I := 1 to VOCAB - 1 do
    if Score[I] > Score[Best] then Best := I;
  if Creativity <= 0 then
  begin
    Pick := Chosen(Best);
    Exit;
  end;
  T := Creativity / 5.0;
  Sum := 0;
  for I := 0 to VOCAB - 1 do
  begin
    BS[I] := SafeExp((Score[I] - Score[Best]) / T);
    if BS[I] < 0.15 then BS[I] := 0;
    Sum := Sum + BS[I];
  end;
  R := Sum * Random(10000) / 10000.0;
  for I := 0 to VOCAB - 1 do
  begin
    R := R - BS[I];
    if (R < 0) and (BS[I] > 0) then
    begin
      Pick := Chosen(I);
      Exit;
    end;
  end;
  Pick := Chosen(Best);
end;

function NowMs: Longint;
begin
  if Assigned(ClockMs) then NowMs := ClockMs() else NowMs := 0;
end;

(* Answer question Q into Answer. The callbacks (may be nil) hear about
   progress through the question and about every new letter.
   Returns the number of letters; Tenths gets the time taken. *)
function Think(const Q: String; var Answer: String; var Tenths: Longint;
  OnStep: TStepProc; OnLetter: TLetterProc): Integer;
var
  P, N, Tok: Integer;
  T0: Longint;
begin
  T0 := NowMs;
  Answer := '';
  N := Length(Q);
  AbortThink := False;
  P := 0;
  while P < N do
  begin
    if Assigned(OnStep) then OnStep(P, N);
    if Assigned(OnIdle) then OnIdle;
    if AbortThink then Break;
    Step(Ord(Q[P + 1]) - 30, P);
    Inc(P);
  end;
  if not AbortThink then
  begin
    Step(1, P);                              { end of the question }
    Inc(P);
    while P < CTX do
    begin
      Tok := Pick;
      if Tok <= 1 then Break;                { end of the answer }
      Answer := Answer + Chr(Tok + 30);
      if Assigned(OnLetter) then OnLetter(Tok + 30);
      if Assigned(OnIdle) then OnIdle;
      if AbortThink then Break;
      Step(Tok, P);
      Inc(P);
    end;
  end;
  Tenths := (NowMs - T0) div 100;
  Think := Length(Answer);
end;

(* Clean up a typed line: printable letters only, no trailing spaces,
   and CAPS LOCK text turned into lower case. *)
function Clean(const Line: String; var Q: String): Integer;
var
  I, Lower, Upper: Integer;
begin
  Q := '';
  Lower := 0;
  Upper := 0;
  I := 1;
  while (I <= Length(Line)) and (Length(Q) < MAXQ) do
  begin
    if (Line[I] >= ' ') and (Line[I] <= '~') then
      Q := Q + Line[I];
    Inc(I);
  end;
  while (Length(Q) > 0) and (Q[Length(Q)] = ' ') do
    Delete(Q, Length(Q), 1);
  for I := 1 to Length(Q) do
  begin
    if (Q[I] >= 'a') and (Q[I] <= 'z') then Inc(Lower);
    if (Q[I] >= 'A') and (Q[I] <= 'Z') then Inc(Upper);
  end;
  if (Upper > 0) and (Lower = 0) then
    for I := 1 to Length(Q) do
      if (Q[I] >= 'A') and (Q[I] <= 'Z') then
        Q[I] := Chr(Ord(Q[I]) + 32);
  Clean := Length(Q);
end;

{ is Q the word W (W in lower case), ignoring case? }
function IsWord(const Q, W: String): Boolean;
var
  I: Integer;
begin
  IsWord := False;
  if Length(Q) <> Length(W) then Exit;
  for I := 1 to Length(Q) do
    if (Ord(Q[I]) or 32) <> Ord(W[I]) then Exit;
  IsWord := True;
end;

function NumStr(N: Longint): String;
var
  S: String[12];
begin
  Str(N, S);
  NumStr := String(S);
end;

function TenthsStr(T: Longint): String;
begin
  TenthsStr := NumStr(T div 10) + '.' + NumStr(T mod 10);
end;

{ ---- plain text: questions from a file, answers to a file --------------- }

procedure PlainRun(var Fin, Fout: Text);
var
  Line, Q, Answer: String;
  Letters: Integer;
  Tenths: Longint;
begin
  WriteLn(Fout, 'TINY 2 - a neural network that answers questions.');
  WriteLn(Fout, 'Loading TINY.BIN ...');
  WriteLn(Fout, 'Ready: ', L, ' layers, ', D, ' wide. Creativity ', Creativity,
    ' (TINY 0 to TINY 9).');
  WriteLn(Fout, 'Ask about countries, animals, space, the body, nature, science, food,');
  WriteLn(Fout, 'sums, numbers, spelling, words, shapes, history, music or computers.');
  WriteLn(Fout, 'Type QUIT to stop.');
  while True do
  begin
    WriteLn(Fout);
    Write(Fout, '> ');
    if Eof(Fin) then Break;
    ReadLn(Fin, Line);
    if Clean(Line, Q) = 0 then Continue;
    if IsWord(Q, 'quit') or IsWord(Q, 'exit') then Break;
    Letters := Think(Q, Answer, Tenths, nil, nil);
    WriteLn(Fout, '  ', Answer);
    {$IFDEF TINYMODERN}if Assigned(OnAnswer) then begin Flush(Fout); OnAnswer(Answer) end;{$ENDIF}
    WriteLn(Fout, '   [', Letters, ' letters in ', TenthsStr(Tenths), ' seconds]');
  end;
  WriteLn(Fout, 'Goodbye!');
end;

{ ---- /BENCH ------------------------------------------------------------- }

procedure RunBench(var Fout: Text; const Build: String; Fpu: Integer);
var
  I, Letters, Old: Integer;
  Answer: String;
  Tenths, T0, T1, Ms, Tokens, AllMs, AllTokens: Longint;
begin
  Old := Creativity;
  Creativity := 0;
  AllMs := 0;
  AllTokens := 0;
  WriteLn(Fout, 'TINY 2.1 benchmark');
  Write(Fout, 'build: ', Build, '   engine: ');
  if UseInt then Write(Fout, 'INTEGER') else Write(Fout, 'FLOAT');
  {$IFDEF TINYASM}
  Write(Fout, ' + ASM');
  {$ELSE}
  Write(Fout, ' (Pascal)');
  {$ENDIF}
  Write(Fout, '   coprocessor: ');
  if Fpu > 0 then WriteLn(Fout, 'yes')
  else if Fpu = 0 then WriteLn(Fout, 'no (emulated)')
  else WriteLn(Fout, 'unknown');
  WriteLn(Fout);
  for I := 1 to NBENCH do
  begin
    T0 := NowMs;
    Letters := Think(String(BenchQ[I]), Answer, Tenths, nil, nil);
    T1 := NowMs;
    if AbortThink then Break;
    Ms := T1 - T0;
    Tokens := Length(BenchQ[I]) + 1 + Letters;
    AllMs := AllMs + Ms;
    AllTokens := AllTokens + Tokens;
    WriteLn(Fout, BenchQ[I]);
    WriteLn(Fout, '  ', Answer);
    {$IFDEF TINYMODERN}
    WriteLn(Fout, '  ', Tokens, ' tokens in ', Ms, ' ms');
    {$ELSE}
    WriteLn(Fout, '  ', Tokens, ' letters in ', TenthsStr(Ms div 100), ' s');
    {$ENDIF}
  end;
  WriteLn(Fout);
  {$IFDEF TINYMODERN}
  WriteLn(Fout, 'total: ', AllTokens, ' tokens in ', AllMs, ' ms');
  if AllMs > 0 then
    WriteLn(Fout, 'speed: ', (AllTokens * 1000.0 / AllMs):0:1,
      ' tokens/s   average answer: ', (AllMs / NBENCH):0:1, ' ms');
  {$ELSE}
  WriteLn(Fout, 'total: ', AllTokens, ' letters in ', TenthsStr(AllMs div 100), ' s');
  if AllMs > 0 then
    WriteLn(Fout, 'speed: ', TenthsStr(AllTokens * 10000 div AllMs),
      ' letters/s   average answer: ', TenthsStr(AllMs div (NBENCH * 100)), ' s');
  {$ENDIF}
  Creativity := Old;
end;

begin
  Creativity := 5;
  UseInt := True;
  OnFail := nil;
  OnLoad := nil;
  ClockMs := nil;
  OnIdle := nil;
end.
