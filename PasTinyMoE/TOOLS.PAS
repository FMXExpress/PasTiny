unit TOOLS;
(* Exact answers worked out in code, before any model is asked.

   ToolAnswer recognises these kinds of question and answers them itself:

     sums         "what is 458 plus 367", "7 x 8", "twenty add seventeen",
                  "subtract 3 from 10", "divide 17 by 5", "one more than 9"
     one number   "double 17", "half of 44", "13 squared", "square root
                  of 169", "what number comes after 842"
     counting     "count up from 48 to 52", "count down from 5 to 3"
     number words "write 100 in words", "write sixty-one in numbers"
     Roman        "write 49 in roman numerals", "what number is XIX"
     comparison   "is 842 bigger than 837", "which is smaller 100 or 99"
     words        "reverse jumped", "spell jumped backwards", "how do you
                  spell laugh", "make knives uppercase"
     letters      "how many letters in jumped", "first letter of tear",
                  "what letter does moon end with"
     alphabet     "what comes before r in the alphabet", "which letter of
                  the alphabet is c"

   Numbers are whole, written in digits or in words up to the thousands,
   and results must fit in 32 bits.  Anything it does not recognise for
   certain is left alone (the function returns False) and goes to a model
   as before. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$N+}{$E+}
interface
function ToolAnswer(Q:String; var A:String):Boolean;
implementation
const MaxW=28; Limit=2147483647.0;
type TWord=String[24];
var W,Raw:array[1..MaxW] of TWord; N:Integer;

function IsLetter(C:Char):Boolean;
begin IsLetter:=(UpCase(C)>='A') and (UpCase(C)<='Z') end;
function IsDigit(C:Char):Boolean;
begin IsDigit:=(C>='0') and (C<='9') end;

(* Split the question into words, numbers and the signs + - * /.  A hyphen
   between two letters joins a word such as twenty-one and is dropped. *)
procedure Split(Q:String);
var I,J:Integer; T:TWord;
 procedure Add(S:TWord);
 var K:Integer;
 begin
  if (N>=MaxW) or (S='') then Exit;
  Inc(N); Raw[N]:=S;
  for K:=1 to Length(S) do if (S[K]>='A') and (S[K]<='Z') then S[K]:=Chr(Ord(S[K])+32);
  W[N]:=S
 end;
begin
 N:=0; I:=1;
 while I<=Length(Q) do begin
  if IsLetter(Q[I]) or IsDigit(Q[I]) then begin
   J:=I;
   if IsDigit(Q[I]) then while (J<=Length(Q)) and IsDigit(Q[J]) do Inc(J)
   else while (J<=Length(Q)) and (IsLetter(Q[J]) or (Q[J]='''')) do Inc(J);
   T:=Copy(Q,I,J-I); Add(T); I:=J
  end else begin
   if Q[I] in ['+','*','/'] then Add(Q[I])
   else if Q[I]='-' then
    if not ((I>1) and (I<Length(Q)) and IsLetter(Q[I-1]) and IsLetter(Q[I+1])) then Add('-');
   Inc(I)
  end
 end
end;

function Is(I:Integer; S:TWord):Boolean;
begin Is:=(I>=1) and (I<=N) and (W[I]=S) end;

(* The value of one number word, or -1. *)
function WordValue(S:TWord):Longint;
const Names:array[0..27] of String[9]=('zero','one','two','three','four','five','six','seven',
 'eight','nine','ten','eleven','twelve','thirteen','fourteen','fifteen','sixteen','seventeen',
 'eighteen','nineteen','twenty','thirty','forty','fifty','sixty','seventy','eighty','ninety');
var K:Integer;
begin
 WordValue:=-1;
 for K:=0 to 27 do if S=Names[K] then
  if K<=20 then WordValue:=K else WordValue:=(K-18)*10
end;

(* Read a whole number starting at word I: a run of digits, or number
   words such as "one hundred and five".  Next is the word after it. *)
function NumAt(I:Integer; var V:Extended; var Next:Integer):Boolean;
var Total,Cur:Extended; K,Code:Integer; D:Longint; Got:Boolean;
begin
 NumAt:=False;
 if (I<1) or (I>N) then Exit;
 if IsDigit(W[I][1]) then begin
  if Length(W[I])>9 then Exit;
  Val(W[I],D,Code); if Code<>0 then Exit;
  V:=D; Next:=I+1; NumAt:=True; Exit
 end;
 Total:=0; Cur:=0; Got:=False; K:=I;
 while K<=N do begin
  D:=WordValue(W[K]);
  if D>=0 then begin Cur:=Cur+D; Got:=True end
  else if (W[K]='hundred') and Got then Cur:=Cur*100
  else if (W[K]='thousand') and Got then begin Total:=Total+Cur*1000; Cur:=0 end
  else if (W[K]='and') and Got and (K<N) and (WordValue(W[K+1])>=0) and
          ((W[K-1]='hundred') or (W[K-1]='thousand')) then begin end
  else Break;
  Inc(K)
 end;
 if Got then begin V:=Total+Cur; Next:=K; NumAt:=True end
end;

function Show(V:Extended):String;
var S:String;
begin Str(V:0:0,S); Show:=S end;

(* Which sum is asked for at word I: + - * / as a letter, or a space.
   Next is the word after the operator. *)
function OpAt(I:Integer; var Next:Integer):Char;
begin
 OpAt:=' '; Next:=I+1;
 if (I<1) or (I>N) then Exit;
 if Is(I,'plus') or Is(I,'+') or Is(I,'add') then OpAt:='+'
 else if Is(I,'minus') or Is(I,'-') or Is(I,'subtract') then OpAt:='-'
 else if Is(I,'take') and Is(I+1,'away') then begin OpAt:='-'; Next:=I+2 end
 else if Is(I,'times') or Is(I,'x') or Is(I,'*') then OpAt:='*'
 else if Is(I,'multiplied') and Is(I+1,'by') then begin OpAt:='*'; Next:=I+2 end
 else if (Is(I,'lots') or Is(I,'groups')) and Is(I+1,'of') then begin OpAt:='*'; Next:=I+2 end
 else if Is(I,'divided') and Is(I+1,'by') then begin OpAt:='/'; Next:=I+2 end
 else if Is(I,'/') or Is(I,'over') then OpAt:='/'
end;

function Sum(X:Extended; Op:Char; Y:Extended; var A:String):Boolean;
var R:Extended; Name:String[14];
begin
 Sum:=True;
 case Op of
  '+':begin R:=X+Y; Name:='plus' end;
  '-':begin R:=X-Y; Name:='minus' end;
  '*':begin R:=X*Y; Name:='times' end;
  else begin
   Name:='divided by';
   if Y=0 then begin A:='You cannot divide by zero.'; Exit end;
   R:=Int(X/Y)
  end
 end;
 if Abs(R)>Limit then begin A:='That number is too big for me.'; Exit end;
 A:=Show(X)+' '+Name+' '+Show(Y)+' is '+Show(R);
 if (Op='/') and (X-R*Y<>0) then A:=A+' remainder '+Show(X-R*Y);
 A:=A+'.'
end;

function Arithmetic(var A:String):Boolean;
var I,J,K,E:Integer; X,Y:Extended; Op:Char;
begin
 Arithmetic:=True;
 (* "add 3 and 4", "sum of 3 and 4", "subtract 3 from 10", "multiply 3 by 4", "divide 17 by 5" *)
 for I:=1 to N do begin
  Op:=' '; J:=I+1;
  if Is(I,'add') then Op:='+'
  else if Is(I,'sum') and Is(I+1,'of') then begin Op:='+'; J:=I+2 end
  else if Is(I,'subtract') then Op:='s'
  else if Is(I,'multiply') then Op:='*'
  else if Is(I,'product') and Is(I+1,'of') then begin Op:='*'; J:=I+2 end
  else if Is(I,'divide') then Op:='/';
  if Op<>' ' then if NumAt(J,X,K) then
   if (Is(K,'and') or Is(K,'to') or Is(K,'by') or Is(K,'from') or Is(K,'with')) then
    if NumAt(K+1,Y,E) then begin
     if Op='s' then begin
      if Is(K,'from') then Arithmetic:=Sum(Y,'-',X,A) else Arithmetic:=Sum(X,'-',Y,A)
     end else Arithmetic:=Sum(X,Op,Y,A);
     Exit
    end
 end;
 (* "3 plus 4", "7 x 8", "twenty add seventeen" *)
 for I:=1 to N do if NumAt(I,X,J) then begin
  Op:=OpAt(J,K);
  if Op<>' ' then if NumAt(K,Y,E) then begin Arithmetic:=Sum(X,Op,Y,A); Exit end
 end;
 Arithmetic:=False
end;

function Compare(var A:String):Boolean;
var I,J,K,E:Integer; X,Y:Extended; Kind:Char; Name,Other:String[8];
 function KindOf(S:TWord):Char;
 begin
  if (S='bigger') or (S='larger') or (S='greater') or (S='more') or (S='higher') then KindOf:='>'
  else if (S='smaller') or (S='less') or (S='lower') or (S='fewer') then KindOf:='<'
  else KindOf:=' '
 end;
begin
 Compare:=True;
 for I:=1 to N do begin
  Kind:=KindOf(W[I]);
  if Kind<>' ' then begin
   Name:=W[I];
   if Kind='>' then Other:='smaller' else Other:='bigger';
   (* "is 842 bigger than 837" *)
   if Is(I+1,'than') then if NumAt(I+2,Y,E) then
    for J:=1 to I-1 do if NumAt(J,X,K) then if (K=I) and
      (((Name<>'more') and (Name<>'less')) or (Is(J-1,'is') and not Is(J-2,'what'))) then begin
     if X=Y then A:='No, '+Show(X)+' and '+Show(Y)+' are equal.'
     else if (X>Y)=(Kind='>') then A:='Yes, '+Show(X)+' is '+Name+' than '+Show(Y)+'.'
     else A:='No, '+Show(X)+' is '+Other+' than '+Show(Y)+'.';
     Exit
    end;
   (* "which is bigger 842 or 837" *)
   if NumAt(I+1,X,K) then if Is(K,'or') then if NumAt(K+1,Y,E) then begin
    if X=Y then A:='They are equal.'
    else begin
     if Name='more' then Name:='bigger';
     if (Name='less') or (Name='fewer') then Name:='smaller';
     if (X>Y)=(Kind='>') then A:=Show(X)+' is '+Name+'.' else A:=Show(Y)+' is '+Name+'.'
    end;
    Exit
   end
  end
 end;
 Compare:=False
end;

function Filler(S:TWord):Boolean;
begin
 Filler:=(S='the') or (S='word') or (S='in') or (S='does') or (S='have') or (S='has') or
  (S='are') or (S='there') or (S='is') or (S='letters') or (S='how') or (S='many') or
  (S='of') or (S='please') or (S='a') or (S='it')
end;

function Reverse(var A:String):Boolean;
var I,J,K:Integer;
begin
 Reverse:=False; K:=0;
 if (N>=2) and (Is(N,'backwards') or Is(N,'backward')) then K:=N-1
 else if (N>=3) and Is(N-1,'in') and Is(N,'reverse') then K:=N-2
 else for I:=1 to N-1 do if Is(I,'reverse') and (K=0) then begin
  J:=I+1; while (J<N) and Filler(W[J]) do Inc(J); K:=J
 end;
 if (K<1) or Filler(W[K]) or Is(K,'reverse') then Exit;
 A:=''; for I:=Length(Raw[K]) downto 1 do A:=A+Raw[K][I];
 Reverse:=True
end;

function Letters(var A:String):Boolean;
var I,K,C:Integer; S:String[6];
begin
 Letters:=False; K:=0;
 for I:=1 to N-1 do if Is(I,'many') and Is(I+1,'letters') then K:=I;
 if K=0 then Exit;
 I:=N; while (I>K+1) and Filler(W[I]) do Dec(I);
 if (I<=K+1) or not IsLetter(W[I][1]) then Exit;
 C:=0; for K:=1 to Length(Raw[I]) do if IsLetter(Raw[I][K]) then Inc(C);
 Str(C,S); A:=Raw[I]; A[1]:=UpCase(A[1]); A:=A+' has '+S+' letter'; if C<>1 then A:=A+'s'; A:=A+'.';
 Letters:=True
end;

function Cap(S:String):String;
begin if S<>'' then S[1]:=UpCase(S[1]); Cap:=S end;
function Upper(S:String):String;
var I:Integer;
begin for I:=1 to Length(S) do S[I]:=UpCase(S[I]); Upper:=S end;

(* The last word that carries meaning, at or before word Hi, skipping
   filler such as "the word"; 0 if there is none after word Lo. *)
function Content(Lo,Hi:Integer):Integer;
begin
 while (Hi>Lo) and (Filler(W[Hi]) or not IsLetter(W[Hi][1])) do Dec(Hi);
 if Hi>Lo then Content:=Hi else Content:=0
end;

function Has(S:TWord):Boolean;
var I:Integer;
begin Has:=False; for I:=1 to N do if W[I]=S then Has:=True end;

function InWords(V:Longint):String;
const Small:array[0..19] of String[9]=('zero','one','two','three','four','five','six','seven',
 'eight','nine','ten','eleven','twelve','thirteen','fourteen','fifteen','sixteen','seventeen',
 'eighteen','nineteen');
 Tens:array[2..9] of String[7]=('twenty','thirty','forty','fifty','sixty','seventy','eighty','ninety');
var S:String;
 function Below1000(X:Integer):String;
 var T:String;
 begin
  T:='';
  if X>=100 then begin
   T:=Small[X div 100]+' hundred'; X:=X mod 100;
   if X>0 then T:=T+' and '
  end;
  if X>=20 then begin
   T:=T+Tens[X div 10]; if X mod 10>0 then T:=T+'-'+Small[X mod 10]
  end else if (X>0) or (T='') then T:=T+Small[X];
  Below1000:=T
 end;
begin
 if V<1000 then S:=Below1000(V)
 else begin
  S:=Below1000(V div 1000)+' thousand';
  if V mod 1000>0 then begin
   if V mod 1000<100 then S:=S+' and ' else S:=S+' ';
   S:=S+Below1000(V mod 1000)
  end
 end;
 InWords:=S
end;

function ToRoman(V:Integer):String;
const Vals:array[1..13] of Integer=(1000,900,500,400,100,90,50,40,10,9,5,4,1);
 Syms:array[1..13] of String[2]=('M','CM','D','CD','C','XC','L','XL','X','IX','V','IV','I');
var S:String; K:Integer;
begin
 S:='';
 for K:=1 to 13 do while V>=Vals[K] do begin S:=S+Syms[K]; Dec(V,Vals[K]) end;
 ToRoman:=S
end;

(* The value of a Roman numeral, or 0 if S is not a properly written one. *)
function FromRoman(S:String):Integer;
var I,V,Prev,Cur,Total:Integer;
begin
 FromRoman:=0; Total:=0; Prev:=0; S:=Upper(S);
 if (S='') or (Length(S)>15) then Exit;
 for I:=Length(S) downto 1 do begin
  case S[I] of
   'I':Cur:=1; 'V':Cur:=5; 'X':Cur:=10; 'L':Cur:=50; 'C':Cur:=100; 'D':Cur:=500; 'M':Cur:=1000;
   else Exit
  end;
  if Cur<Prev then Dec(Total,Cur) else Inc(Total,Cur);
  Prev:=Cur
 end;
 V:=Total;
 if (V>=1) and (V<=3999) then if ToRoman(V)=S then FromRoman:=V
end;

function Roman(var A:String):Boolean;
var I,J,V:Integer; X:Extended;
begin
 Roman:=False;
 if Has('roman') then begin
  for I:=1 to N do if IsDigit(W[I][1]) then if NumAt(I,X,J) then if (X>=1) and (X<=3999) then begin
   A:=Show(X)+' is '+ToRoman(Trunc(X))+' in Roman numerals.'; Roman:=True; Exit
  end
 end;
 if Has('roman') or Has('number') or Has('numbers') then
  for I:=N downto 1 do if not Is(I,'i') and not Is(I,'mix') and not Is(I,'did') and not Is(I,'mild') then begin
   V:=FromRoman(W[I]);
   if (V>0) and (Has('roman') or (Length(W[I])>=2)) then begin
    A:=Upper(W[I])+' is '+Show(V)+'.'; Roman:=True; Exit
   end
  end
end;

function OneNumber(var A:String):Boolean;
var I,J,K:Integer; X,Y,R:Extended; L:Longint;
begin
 OneNumber:=True;
 for I:=1 to N do begin
  (* "double 17", "6 doubled", "half of 44", "96 halved" *)
  if (Is(I,'double') or Is(I,'twice')) and NumAt(I+1,X,J) then begin
   A:='Double '+Show(X)+' is '+Show(2*X)+'.'; Exit end;
  if Is(I,'half') then begin
   K:=I+1; if Is(K,'of') then Inc(K);
   if NumAt(K,X,J) then begin
    A:='Half of '+Show(X)+' is '+Show(Int(X/2));
    if X-2*Int(X/2)<>0 then A:=A+' and a half';
    A:=A+'.'; Exit
   end
  end;
  if NumAt(I,X,J) then begin
   if Is(J,'doubled') then begin A:='Double '+Show(X)+' is '+Show(2*X)+'.'; Exit end;
   if Is(J,'halved') then begin
    A:='Half of '+Show(X)+' is '+Show(Int(X/2));
    if X-2*Int(X/2)<>0 then A:=A+' and a half';
    A:=A+'.'; Exit
   end;
   (* "13 squared", "7 times itself" *)
   if Is(J,'squared') or (Is(J,'times') and Is(J+1,'itself')) then
    if X*X<=Limit then begin A:=Show(X)+' squared is '+Show(X*X)+'.'; Exit end
  end;
  if Is(I,'square') and Is(I+1,'of') and NumAt(I+2,X,J) then
   if X*X<=Limit then begin A:=Show(X)+' squared is '+Show(X*X)+'.'; Exit end;
  if Is(I,'square') and Is(I+1,'root') then begin
   K:=I+2; if Is(K,'of') then Inc(K);
   if NumAt(K,X,J) then begin
    R:=Int(Sqrt(X)+0.5);
    if R*R=X then begin A:='The square root of '+Show(X)+' is '+Show(R)+'.'; Exit end
   end
  end;
  (* "what number comes after 842", "one more than 9", "3 less than 10" *)
  if Is(I,'after') and not Has('alphabet') and not Has('letter') and NumAt(I+1,X,J) then begin
   A:=Show(X+1)+' comes after '+Show(X)+'.'; Exit end;
  if Is(I,'before') and not Has('alphabet') and not Has('letter') and NumAt(I+1,X,J) then begin
   A:=Show(X-1)+' comes before '+Show(X)+'.'; Exit end;
  if NumAt(I,X,J) then if (Is(J,'more') or Is(J,'less')) and Is(J+1,'than') then
   if (not Is(I-1,'is')) or Is(I-2,'what') then if NumAt(J+2,Y,K) then begin
    if Is(J,'more') then A:=Show(X)+' more than '+Show(Y)+' is '+Show(Y+X)+'.'
    else A:=Show(X)+' less than '+Show(Y)+' is '+Show(Y-X)+'.';
    Exit
   end;
  (* "count up from 48 to 52" *)
  if Is(I,'count') then
   for K:=I+1 to N-2 do if Is(K,'from') then if NumAt(K+1,X,J) then if Is(J,'to') then
    if NumAt(J+1,Y,J) then if Abs(Y-X)<=20 then begin
     A:=Show(X);
     while X<>Y do begin
      if Y>X then X:=X+1 else X:=X-1;
      A:=A+', '+Show(X)
     end;
     A:=A+'.'; Exit
    end;
  (* "write 100 in words", "how do you say 59"; "write sixty-one in numbers" *)
  if IsDigit(W[I][1]) then if NumAt(I,X,J) then
   if (Is(J,'in') and Is(J+1,'words')) or ((J>N) and (I>1) and Is(I-1,'say')) or
      ((J>N) and Has('spell') and Has('number')) then
    if X<=999999.0 then begin L:=Trunc(X); A:=Cap(InWords(L))+'.'; Exit end;
  if not IsDigit(W[I][1]) then if NumAt(I,X,J) then
   if Is(J,'in') and (Is(J+1,'numbers') or Is(J+1,'digits') or Is(J+1,'figures')) then begin
    A:=Show(X)+'.'; Exit end
 end;
 OneNumber:=False
end;

function WordTools(var A:String):Boolean;
var I,K:Integer; S:String;
 (* The word just before word I, as in "does IN end with". *)
 function Before(I:Integer):Integer;
 begin
  if (I>1) and IsLetter(W[I-1][1]) and not Is(I-1,'does') and not Is(I-1,'it') then Before:=I-1
  else Before:=0
 end;
begin
 WordTools:=True;
 for I:=1 to N do begin
  (* "first letter of tear", "which letter does rise begin with" *)
  if (Is(I,'first') and Is(I+1,'letter')) or
     ((Is(I,'begin') or Is(I,'start') or Is(I,'begins') or Is(I,'starts')) and Is(I+1,'with') and Has('letter')) then begin
   if Is(I,'first') then K:=Content(I+1,N) else K:=Before(I);
   if K>0 then begin A:=Cap(Raw[K])+' starts with '+UpCase(Raw[K][1])+'.'; Exit end
  end;
  if (Is(I,'last') and Is(I+1,'letter')) or
     ((Is(I,'end') or Is(I,'ends')) and Is(I+1,'with') and Has('letter')) then begin
   if Is(I,'last') then K:=Content(I+1,N) else K:=Before(I);
   if K>0 then begin A:=Cap(Raw[K])+' ends with '+UpCase(Raw[K][Length(Raw[K])])+'.'; Exit end
  end;
  (* "make knives uppercase" *)
  if Is(I,'uppercase') or (Is(I,'capitals') and Is(I-1,'in')) then begin
   K:=Content(0,I-1); if K=0 then K:=Content(I,N);
   if (K>0) and not Is(K,'make') and not Is(K,'write') then begin A:=Upper(Raw[K])+'.'; Exit end
  end;
  (* "how long is the word fought" *)
  if Is(I,'how') and Is(I+1,'long') and Has('word') then begin
   K:=Content(I+1,N);
   if K>0 then begin Str(Length(Raw[K]),S); A:=Cap(Raw[K])+' has '+S+' letters.'; Exit end
  end;
  (* "how do you spell laugh", "spell the word tripoli" *)
  if Is(I,'spell') and not Has('backwards') and not Has('backward') and not Has('spelling')
     and not Has('number') then begin
   K:=Content(I,N);
   if (K>0) and (Length(Raw[K])<=20) then begin
    A:='';
    for I:=1 to Length(Raw[K]) do begin
     if I>1 then A:=A+'-';
     A:=A+UpCase(Raw[K][I])
    end;
    A:=A+'.'; Exit
   end
  end
 end;
 WordTools:=False
end;

function Alphabet(var A:String):Boolean;
var I,K:Integer; C:Char; S:String[3];
begin
 Alphabet:=False;
 if not (Has('alphabet') or Has('letter')) then Exit;
 for I:=1 to N-1 do if (Is(I,'before') or Is(I,'after')) and (Length(W[I+1])=1) and IsLetter(W[I+1][1]) then begin
  C:=UpCase(W[I+1][1]);
  if Is(I,'before') and (C>'A') then begin A:=Chr(Ord(C)-1)+' comes before '+C+'.'; Alphabet:=True end;
  if Is(I,'after') and (C<'Z') then begin A:=Chr(Ord(C)+1)+' comes after '+C+'.'; Alphabet:=True end;
  Exit
 end;
 if Has('alphabet') or Has('number') then begin
  K:=0;
  if (Length(W[N])=1) and IsLetter(W[N][1]) then K:=N
  else for I:=1 to N-1 do if Is(I,'letter') and (Length(W[I+1])=1) and IsLetter(W[I+1][1]) then K:=I+1;
  if K>0 then begin
   C:=UpCase(W[K][1]); Str(Ord(C)-64,S);
   A:=C+' is letter number '+S+'.'; Alphabet:=True
  end
 end
end;

function ToolAnswer(Q:String; var A:String):Boolean;
begin
 Split(Q); A:='';
 ToolAnswer:=(N>0) and (Alphabet(A) or Letters(A) or Reverse(A) or WordTools(A) or Roman(A) or
  Compare(A) or OneNumber(A) or Arithmetic(A))
end;
end.
