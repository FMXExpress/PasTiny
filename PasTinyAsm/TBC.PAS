unit TBC;
(* The PasTinyAsm language and its compiler.

   A program is a list of lines.  A line holds statements separated by
   colons, and must close every block it opens:

     FOR I=10 DOWNTO 1:OUT I:BEEP:NEXT:ECHO liftoff

   Statements
     CLS  FLASH n  COLOR n  INK n  BORDER n  GOTO row col  HIDE  SHOW
     BEEP hertz ms  SIREN n  SCALE  WAIT ms  KEY
     PRINT text  NEWLINE (or NL)  NUMBER n
                           the library routines of LIB.ASM.  BEEP, FLASH,
                           SIREN and WAIT may stand alone and then mean
                           BEEP 440 300, FLASH 1, SIREN 1 and WAIT 1000
     OUT n                 NUMBER n and a new line
     ECHO text             PRINT text and a new line
     LET v=n               give a variable a value
     INPUT v               read a number from the keyboard
     FOR v=n TO n ... NEXT       count up by one
     FOR v=n DOWNTO n ... NEXT   count down by one; with plain numbers
                                 the direction must fit them
     TIMES n ... END             do the block n times
     FOREVER ... END             do the block again and again
     STOP                        end the program at once
     IF n<n ... ELSE ... END     tests: = <> < > <= >=
     REPEAT n              on a line of its own: run the whole program n
                           times (1 to 100)

   KEY waits for a key and keeps its code in K, so IF K='q' tests it.
   A character in single quotes is its code.

   Variables are the letters A to Z, whole numbers from 0 to 65535.  A
   number n may be an expression of numbers and variables with + - * /
   and no spaces: I*100+200.  * and / are done before + and -.

   The compiler writes 8086 code directly and, when asked, the same code
   as an assembly listing, instruction by instruction.  NASM assembles
   that listing (with the routines of LIB.ASM put in) to the same bytes;
   tests/test_asm.py checks it.

   Layout of the .COM file: a jump over 26 variable words, the main part,
   the library routines that were used, then the texts. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$ENDIF}
interface
type TCall=record Name:String[7]; Kind:Byte; Lo1,Hi1,Lo2,Hi2,Ofs,Len:Word end;
{$I LIB.INC}
const MAXCODE=3072; ORIGIN=$100; VARBASE=$103;
type TCode=array[0..MAXCODE-1] of Byte;
(* The program being built.  The big tables live on the heap: the data
   segment of the DOS program is nearly full. *)
var Code:^TCode; Size:Word; CompErr:String[60];
 AllowOpen:Boolean;   (* may a line leave a block open for a later line to close? *)

(* Loops is 0, or how often the whole program runs.  ListName is the
   file for the listing, or '' for none. *)
procedure BeginProgram(Loops:Word; ListName:String);
(* Compile one line.  A line that starts with #255 prints the rest of
   itself exactly.  False, with CompErr set, if it is not valid. *)
function CompileLine(S:String):Boolean;
function EndProgram:Boolean;
(* Is S one valid line?  Changes nothing that lasts. *)
function CheckLine(S:String; var Why:String):Boolean;
(* Is S valid as part of a program, where it may open a block or close
   one?  Delta is how many blocks deeper the program is after it. *)
function CheckPart(S:String; var Delta:Integer; var Why:String):Boolean;
(* If the line is "REPEAT n", n; otherwise 0. *)
function RepeatCount(S:String):Word;
function FindCall(S:String):Integer;

implementation
const MAXLAB=220; MAXFIX=300; MAXTEXT=24; MAXDEPTH=12;
type TBlock=record Kind:Char; L1,L2,V:Integer end;
 TFix=record Pos:Word; Kind:Byte; Id:Integer end;
 TFixes=array[1..MAXFIX] of TFix;
 TTexts=array[1..MAXTEXT] of String[60];
var Lst:Text; Listing,Failed:Boolean;
 NLab,NFix,NText,Depth,TopLab:Integer; LoopN:Word;
 LabAddr:array[1..MAXLAB] of Word;
 Fix:^TFixes;
 Used:array[1..LIBCOUNT] of Boolean;
 Texts:^TTexts;
 Blocks:array[1..MAXDEPTH] of TBlock;
 St,RawSt:String; P:Integer;    (* the statement being read (in capitals, and as typed), and the place in it *)

procedure Error(Msg:String);
begin if not Failed then CompErr:=Msg; Failed:=True end;

function NumStr(V:Longint):String;
var S:String;
begin Str(V,S); NumStr:=S end;

function HexStr(W:Word):String;
const H:array[0..15] of Char='0123456789ABCDEF';
begin HexStr:='0'+H[W shr 12]+H[(W shr 8) and 15]+H[(W shr 4) and 15]+H[W and 15]+'h' end;

procedure B(X:Byte);
begin
 if Size<MAXCODE then begin Code^[Size]:=X; Inc(Size) end else Error('program too long')
end;
procedure W(X:Word);
begin B(Lo(X)); B(Hi(X)) end;
(* One line of the listing. *)
procedure T(S:String);
begin if Listing then WriteLn(Lst,'        ',S) end;

function NewLabel:Integer;
begin
 if NLab<MAXLAB then Inc(NLab) else Error('program too long');
 LabAddr[NLab]:=0; NewLabel:=NLab
end;
procedure Place(L:Integer);
begin LabAddr[L]:=Size; if Listing then WriteLn(Lst,'L',L,':') end;
procedure AddFix(Kind:Byte; Id:Integer);
begin
 if NFix<MAXFIX then begin
  Inc(NFix); Fix^[NFix].Pos:=Size; Fix^[NFix].Kind:=Kind; Fix^[NFix].Id:=Id
 end else Error('program too long');
 W(0)
end;
procedure JmpNear(L:Integer);
begin B($E9); AddFix(1,L); T('jmp     near L'+NumStr(L)) end;
procedure CallLib(I:Integer);
begin Used[I]:=True; B($E8); AddFix(2,I); T('call    L_'+Lib[I].Name) end;
(* Jump over the next (3-byte) near jump when the condition holds. *)
procedure Skip(Op:Byte; Name:String);
begin B(Op); B(3); T(Name+' short $+5') end;

function FindCall(S:String):Integer;
var I:Integer;
begin
 FindCall:=0;
 for I:=1 to LIBCOUNT do if Lib[I].Name=S then FindCall:=I
end;

function VarAddr(V:Integer):Word;
begin VarAddr:=VARBASE+2*V end;
procedure LoadVar(V:Integer);
begin B($A1); W(VarAddr(V)); T('mov     ax,['+HexStr(VarAddr(V))+']        ; '+Chr(65+V)) end;
procedure StoreVar(V:Integer);
begin B($A3); W(VarAddr(V)); T('mov     ['+HexStr(VarAddr(V))+'],ax        ; '+Chr(65+V)) end;

function Cur:Char;
begin if P<=Length(St) then Cur:=St[P] else Cur:=#0 end;
procedure Blanks;
begin while Cur=' ' do Inc(P) end;
function IsLetter(C:Char):Boolean;
begin IsLetter:=(C>='A') and (C<='Z') end;
function IsDigit(C:Char):Boolean;
begin IsDigit:=(C>='0') and (C<='9') end;

(* A variable name at the place: one letter not followed by another. *)
function ReadVar(var V:Integer):Boolean;
begin
 ReadVar:=False;
 if IsLetter(Cur) and not ((P<Length(St)) and IsLetter(St[P+1])) then begin
  V:=Ord(Cur)-65; Inc(P); ReadVar:=True
 end
end;

procedure Factor;
var V:Longint; K:Integer;
begin
 if IsDigit(Cur) then begin
  V:=0;
  while IsDigit(Cur) do begin
   if V<=65535 then V:=V*10+Ord(Cur)-48;
   Inc(P)
  end;
  if V>65535 then Error('number too big');
  B($B8); W(Word(V)); T('mov     ax,'+NumStr(V))
 end
 else if (Cur=#39) and (P+2<=Length(St)) and (St[P+2]=#39) then begin
  (* a character in quotes is its code: 'q' is 113 *)
  V:=Ord(RawSt[P+1]); Inc(P,3);
  B($B8); W(Word(V)); T('mov     ax,'+NumStr(V))
 end
 else if ReadVar(K) then LoadVar(K)
 else Error('number or variable expected')
end;

procedure Term;
var Op:Char;
begin
 Factor;
 while (Cur='*') or (Cur='/') do begin
  Op:=Cur; Inc(P);
  B($50); T('push    ax');
  Factor;
  B($89); B($C3); T('mov     bx,ax');
  B($58); T('pop     ax');
  if Op='*' then begin B($F7); B($E3); T('mul     bx') end
  else begin B($31); B($D2); T('xor     dx,dx'); B($F7); B($F3); T('div     bx') end
 end
end;

procedure Expr;
var Op:Char;
begin
 Term;
 while (Cur='+') or (Cur='-') do begin
  Op:=Cur; Inc(P);
  B($50); T('push    ax');
  Term;
  B($89); B($C3); T('mov     bx,ax');
  B($58); T('pop     ax');
  if Op='+' then begin B($01); B($D8); T('add     ax,bx') end
  else begin B($29); B($D8); T('sub     ax,bx') end
 end
end;

(* If a plain number stands at the place, its value; otherwise -1. *)
function PlainNumber:Longint;
var I:Integer; V:Longint;
begin
 PlainNumber:=-1; I:=P; V:=0;
 if not IsDigit(Cur) then Exit;
 while (I<=Length(St)) and IsDigit(St[I]) do begin
  if V<=65535 then V:=V*10+Ord(St[I])-48;
  Inc(I)
 end;
 if (I<=Length(St)) and (St[I]<>' ') then Exit;
 PlainNumber:=V
end;

(* An argument: an expression into AX.  A plain number must be in range. *)
procedure Argument(Lo,Hi:Word);
var V:Longint;
begin
 Blanks; V:=PlainNumber;
 if (V>=0) and ((V<Lo) or (V>Hi)) then Error('number out of range');
 Expr
end;

procedure Push(Kind:Char; L1,L2,V:Integer);
begin
 if Depth=MAXDEPTH then begin Error('blocks too deep'); Exit end;
 Inc(Depth); Blocks[Depth].Kind:=Kind; Blocks[Depth].L1:=L1; Blocks[Depth].L2:=L2; Blocks[Depth].V:=V
end;

function AddText(S:String):Integer;
var I:Integer;
begin
 AddText:=1;
 while (S<>'') and (S[1]=' ') do Delete(S,1,1);
 while (S<>'') and (S[Length(S)]=' ') do Delete(S,Length(S),1);
 for I:=1 to Length(S) do if (S[I]='$') or (S[I]='"') or (S[I]<' ') or (S[I]>'~') then S[I]:='?';
 if (S='') or (Length(S)>60) then begin Error('no text'); Exit end;
 if NText=MAXTEXT then begin Error('too many texts'); Exit end;
 Inc(NText); Texts^[NText]:=S; AddText:=NText
end;

procedure PrintText(S:String; Line:Boolean);
var N:Integer;
begin
 N:=AddText(S);
 B($BA); AddFix(3,N); T('mov     dx,text'+NumStr(N));
 CallLib(FindCall('PRINT'));
 if Line then CallLib(FindCall('NEWLINE'))
end;

procedure TwoSides(var Op:String);
(* a test: left side on the stack, right side in BX, left back in AX *)
begin
 Blanks; Expr; Blanks; Op:='';
 while (Cur='<') or (Cur='>') or (Cur='=') do begin Op:=Op+Cur; Inc(P) end;
 B($50); T('push    ax');
 Blanks; Expr;
 B($89); B($C3); T('mov     bx,ax');
 B($58); T('pop     ax');
 B($39); B($D8); T('cmp     ax,bx')
end;

(* One statement.  Up is the statement in capitals, Raw as it was typed
   (for texts). *)
procedure Statement(Up,Raw:String);
var Key,Op:String; I,V,L1,L2:Integer; Down:Boolean; Bl:TBlock; First,Last:Longint;
begin
 St:=Up; RawSt:=Raw; P:=1; Blanks; Key:='';
 while IsLetter(Cur) do begin Key:=Key+Cur; Inc(P) end;
 if Key='' then begin Error('statement expected'); Exit end;
 I:=FindCall(Key);
 if Key='NL' then I:=FindCall('NEWLINE');
 if (Key='PRINT') or (Key='ECHO') then begin PrintText(Copy(Raw,P,255),Key='ECHO'); Exit end
 else if (I>0) and (Lib[I].Kind<4) then begin
  Blanks;
  if (Cur=#0) and (Lib[I].Kind>0) then begin
   (* a call with nothing after it: the usual values *)
   if Key='BEEP' then begin B($B8); W(440); T('mov     ax,440'); B($BB); W(300); T('mov     bx,300') end
   else if Key='WAIT' then begin B($B8); W(1000); T('mov     ax,1000') end
   else if (Key='FLASH') or (Key='SIREN') then begin B($B8); W(1); T('mov     ax,1') end
   else Error('wrong arguments')
  end else if Lib[I].Kind=1 then Argument(Lib[I].Lo1,Lib[I].Hi1)
  else if Lib[I].Kind=2 then begin
   Argument(Lib[I].Lo1,Lib[I].Hi1);
   B($50); T('push    ax');
   Argument(Lib[I].Lo2,Lib[I].Hi2);
   B($89); B($C3); T('mov     bx,ax');
   B($58); T('pop     ax')
  end;
  CallLib(I);
  if Key='KEY' then begin
   (* the key that was pressed is kept in K *)
   B($30); B($E4); T('xor     ah,ah'); StoreVar(Ord('K')-65)
  end
 end
 else if Key='STOP' then begin
  B($B8); W($4C00); T('mov     ax,4C00h'); B($CD); B($21); T('int     21h')
 end
 else if Key='FOREVER' then begin
  L1:=NewLabel; Place(L1); Push('V',L1,0,0)
 end
 else if Key='OUT' then begin
  Argument(0,65535); CallLib(FindCall('NUMBER')); CallLib(FindCall('NEWLINE'))
 end
 else if Key='LET' then begin
  Blanks;
  if not ReadVar(V) or (Cur<>'=') then begin Error('LET v=n expected'); Exit end;
  Inc(P); Expr; StoreVar(V)
 end
 else if Key='INPUT' then begin
  Blanks;
  if not ReadVar(V) then begin Error('INPUT v expected'); Exit end;
  CallLib(FindCall('INPUT')); StoreVar(V)
 end
 else if Key='FOR' then begin
  Blanks;
  if not ReadVar(V) or (Cur<>'=') then begin Error('FOR v=n TO n expected'); Exit end;
  Inc(P); First:=PlainNumber; Expr; StoreVar(V); Blanks;
  Key:=''; while IsLetter(Cur) do begin Key:=Key+Cur; Inc(P) end;
  if (Key<>'TO') and (Key<>'DOWNTO') then begin Error('TO or DOWNTO expected'); Exit end;
  Down:=Key='DOWNTO'; Blanks; Last:=PlainNumber; Expr;
  (* with plain numbers a loop the wrong way round is surely a mistake *)
  if (First>=0) and (Last>=0) then
   if (Down and (First<Last)) or ((not Down) and (First>Last)) then begin
    Error('this loop would not run: check TO and DOWNTO'); Exit end;
  B($50); T('push    ax              ; the last value');
  L1:=NewLabel; L2:=NewLabel; Place(L1);
  LoadVar(V); B($5B); T('pop     bx'); B($53); T('push    bx'); B($39); B($D8); T('cmp     ax,bx');
  if Down then Skip($73,'jae    ') else Skip($76,'jbe    ');
  JmpNear(L2);
  if Down then Push('D',L1,L2,V) else Push('F',L1,L2,V)
 end
 else if Key='NEXT' then begin
  if (Depth=0) or not (Blocks[Depth].Kind in ['F','D']) then begin Error('NEXT without FOR'); Exit end;
  Bl:=Blocks[Depth]; Dec(Depth);
  LoadVar(Bl.V); B($5B); T('pop     bx'); B($53); T('push    bx'); B($39); B($D8); T('cmp     ax,bx');
  Skip($75,'jne    '); JmpNear(Bl.L2);
  if Bl.Kind='D' then begin B($FF); B($0E); W(VarAddr(Bl.V)); T('dec     word ['+HexStr(VarAddr(Bl.V))+']') end
  else begin B($FF); B($06); W(VarAddr(Bl.V)); T('inc     word ['+HexStr(VarAddr(Bl.V))+']') end;
  JmpNear(Bl.L1); Place(Bl.L2);
  B($5B); T('pop     bx              ; drop the last value');
  Blanks; if ReadVar(V) then ;
 end
 else if Key='TIMES' then begin
  Argument(0,65535);
  B($89); B($C1); T('mov     cx,ax');
  L1:=NewLabel; L2:=NewLabel; Place(L1);
  B($09); B($C9); T('or      cx,cx');
  Skip($75,'jnz    '); JmpNear(L2);
  B($51); T('push    cx');
  Push('T',L1,L2,0)
 end
 else if Key='IF' then begin
  TwoSides(Op);
  if Op='=' then Skip($74,'je     ') else if Op='<>' then Skip($75,'jne    ')
  else if Op='<' then Skip($72,'jb     ') else if Op='>' then Skip($77,'ja     ')
  else if Op='<=' then Skip($76,'jbe    ') else if Op='>=' then Skip($73,'jae    ')
  else begin Error('test expected'); Exit end;
  L1:=NewLabel; JmpNear(L1); Push('I',L1,0,0)
 end
 else if Key='ELSE' then begin
  if (Depth=0) or (Blocks[Depth].Kind<>'I') then begin Error('ELSE without IF'); Exit end;
  L2:=NewLabel; JmpNear(L2); Place(Blocks[Depth].L1);
  Blocks[Depth].Kind:='E'; Blocks[Depth].L1:=L2; Blocks[Depth].V:=Size
 end
 else if Key='END' then begin
  if (Depth=0) or not (Blocks[Depth].Kind in ['T','I','E','V']) then begin Error('END without TIMES, IF or FOREVER'); Exit end;
  Bl:=Blocks[Depth]; Dec(Depth);
  if Bl.Kind='T' then begin
   B($59); T('pop     cx'); B($49); T('dec     cx'); JmpNear(Bl.L1); Place(Bl.L2)
  end
  else if Bl.Kind='V' then JmpNear(Bl.L1)
  else begin
   (* in one line an ELSE with nothing after it is a mistake; in a block
      being built it is only not filled in yet *)
   if (Bl.Kind='E') and (Size=Word(Bl.V)) and not AllowOpen then begin Error('ELSE with nothing after it'); Exit end;
   Place(Bl.L1)
  end
 end
 else begin Error('unknown word '+Key); Exit end;
 Blanks;
 if (Cur<>#0) and not Failed then Error('unexpected '+Copy(St,P,12))
end;

function Upper(S:String):String;
var I:Integer;
begin for I:=1 to Length(S) do S[I]:=UpCase(S[I]); Upper:=S end;

function RepeatCount(S:String):Word;
var V:Longint; Code:Integer;
begin
 RepeatCount:=0; S:=Upper(S);
 while (S<>'') and (S[1]=' ') do Delete(S,1,1);
 if Copy(S,1,7)<>'REPEAT ' then Exit;
 Delete(S,1,7);
 while (S<>'') and (S[Length(S)]=' ') do Delete(S,Length(S),1);
 if (S='') or (Length(S)>3) then Exit;
 Val(S,V,Code);
 if (Code=0) and (V>=1) and (V<=100) then RepeatCount:=V
end;

procedure BeginProgram(Loops:Word; ListName:String);
var I:Integer;
begin
 Size:=0; NLab:=0; NFix:=0; NText:=0; Depth:=0; Failed:=False; CompErr:=''; LoopN:=Loops;
 for I:=1 to LIBCOUNT do Used[I]:=False;
 Listing:=ListName<>'';
 if Listing then begin
  Assign(Lst,ListName); Rewrite(Lst);
  WriteLn(Lst,'; ',ListName,', written by PasTinyAsm.  The routines are in LIB.ASM.');
  WriteLn(Lst,'        org     100h')
 end;
 B($E9); W(52); T('jmp     near start');
 for I:=1 to 52 do B(0); T('times 26 dw 0           ; the variables A to Z');
 if Listing then WriteLn(Lst,'start:');
 if LoopN>0 then begin
  B($B9); W(LoopN); T('mov     cx,'+NumStr(LoopN));
  TopLab:=NewLabel; Place(TopLab); B($51); T('push    cx')
 end
end;

function CompileLine(S:String):Boolean;
var K,Before:Integer; Part:String;
begin
 CompileLine:=False; Before:=Depth;
 if Failed then Exit;
 if (S<>'') and (S[1]=#255) then PrintText(Copy(S,2,255),False)
 else if RepeatCount(S)=0 then begin
  if Listing then WriteLn(Lst,'                                ; ',S);
  S:=S+':';
  while (S<>'') and not Failed do begin
   K:=Pos(':',S); Part:=Copy(S,1,K-1); Delete(S,1,K);
   Statement(Upper(Part),Part)
  end;
  if (Depth<>Before) and not AllowOpen and not Failed then Error('a block is not closed on its line')
 end;
 CompileLine:=not Failed
end;

function EndProgram:Boolean;
var I,J:Integer; Target:Word; Addr:array[1..LIBCOUNT] of Word; TextAt:array[1..MAXTEXT] of Word;
begin
 if (Depth<>0) and not Failed then Error('a block is not closed');
 if LoopN>0 then begin
  B($59); T('pop     cx'); B($49); T('dec     cx'); Skip($74,'jz     '); JmpNear(TopLab)
 end;
 B($B8); W($4C00); T('mov     ax,4C00h'); B($CD); B($21); T('int     21h');
 for I:=1 to LIBCOUNT do if Used[I] then begin
  Addr[I]:=Size;
  for J:=0 to Lib[I].Len-1 do B(LibCode[Lib[I].Ofs+J]);
  if Listing then WriteLn(Lst,'; routine ',Lib[I].Name,' from LIB.ASM goes here')
 end;
 for I:=1 to NText do begin
  TextAt[I]:=Size;
  for J:=1 to Length(Texts^[I]) do B(Ord(Texts^[I][J]));
  B(Ord('$'));
  if Listing then WriteLn(Lst,'text',I,':  db      "',Texts^[I],'$"')
 end;
 if not Failed then for I:=1 to NFix do begin
  case Fix^[I].Kind of
   1:Target:=LabAddr[Fix^[I].Id]-(Fix^[I].Pos+2);
   2:Target:=Addr[Fix^[I].Id]-(Fix^[I].Pos+2);
   else Target:=ORIGIN+TextAt[Fix^[I].Id]
  end;
  Code^[Fix^[I].Pos]:=Lo(Target); Code^[Fix^[I].Pos+1]:=Hi(Target)
 end;
 if Listing then Close(Lst);
 Listing:=False;
 EndProgram:=not Failed
end;

function CheckLine(S:String; var Why:String):Boolean;
begin
 BeginProgram(0,''); AllowOpen:=False;
 if RepeatCount(S)>0 then CheckLine:=True
 else if Copy(Upper(S),1,6)='REPEAT' then begin CompErr:='REPEAT n, 1 to 100, on a line of its own'; CheckLine:=False end
 else CheckLine:=CompileLine(S) and EndProgram;
 Why:=CompErr
end;

function CheckPart(S:String; var Delta:Integer; var Why:String):Boolean;
var U:String; Ok:Boolean;
begin
 U:=Upper(S);
 while (U<>'') and (U[1]=' ') do Delete(U,1,1);
 while (U<>'') and (U[Length(U)]=' ') do Delete(U,Length(U),1);
 Delta:=0;
 (* a closing word alone cannot be compiled alone; the whole program
    is checked when it is saved *)
 if (U='END') or (U='NEXT') then begin Delta:=-1; CheckPart:=True; Why:=''; Exit end;
 if U='ELSE' then begin CheckPart:=True; Why:=''; Exit end;
 BeginProgram(0,''); AllowOpen:=True;
 Ok:=CompileLine(S); Delta:=Depth; AllowOpen:=False;
 CheckPart:=Ok; Why:=CompErr
end;

begin
 New(Code); New(Fix); New(Texts); AllowOpen:=False
end.
