program MakeCom;
(* PasTinyAsm: turn a plain request into a small DOS program.

     > make screen flash, play sound
     1 make screen flash -> FLASH 3
     2 play sound -> BEEP 440 300
     wrote OUT.COM 153 bytes, OUT.ASM

     > count down from 10 and beep each time then say liftoff
     1 count down from 10 and beep each time then say liftoff
       -> FOR I=10 DOWNTO 1:OUT I:BEEP:NEXT:ECHO liftoff

   The work is shared like this:

     code    splits the request into sentences, and those into steps
     code    picks the expert for each step by its words
     model   turns the step into one line of the PasTinyAsm language
     code    checks the line: it must compile, and the numbers typed
             must be in it; anything else is refused
     code    compiles all the lines into the .COM file (unit TBC)

   So the model never writes an instruction.  The language and its
   compiler are in TBC.PAS, the routines in LIB.ASM.

   A step that is already a line of the language is used as it is, and
   a step with text in double quotes prints that text exactly; neither
   asks a model.

   The program is built up over a session, and the .COM file is written
   again after every change.  Words before a colon open a block ("repeat
   3 times:"); what is typed next goes inside it.

   At the keyboard it is a screen editor: the program is always shown,
   and the line being typed stands in the listing where the new code will
   go.  Up and Down move it, into and out of blocks.  With input from a
   file the same moves are commands (UP, DOWN, TAB, GO n ...) and the
   output is plain text.  MAKECOM file starts from the lines of a file. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$M 16384,0,655360}{$ENDIF}
{$N+}{$E+}
uses {$IFDEF VER70}Dos,{$ENDIF}TNYNET,TNYSYS,EXPCAT,TBC;
const
 MAXSTEPS=40; MAXPEND=16;
 XSCREEN=1; XSOUND=2; XTEXT=3; XTASKS=4;    (* catalog ids of the experts *)
type TLine=String[120];
var
 Active:Integer; Interactive:Boolean;
 (* The program: its lines, and for each line whether it opens a block
    (O), closes one (C), is an ELSE (E) or is ordinary (space).  New
    lines go in before line Cur. *)
 Plan:array[1..MAXSTEPS] of TLine; Kind:array[1..MAXSTEPS] of Char; Steps,Cur:Integer;
 (* Lines of the request being planned.  They join the program only if
    every one of them is accepted. *)
 Pend:array[1..MAXPEND] of TLine; PKind:array[1..MAXPEND] of Char; NPend:Integer;
 Closers:array[1..4] of TLine; NClose:Integer;
 OutName:String[8]; Line:String;

(* Called while an expert works: Escape cancels.  Other keys are left
   in the keyboard buffer, so what is typed ahead is not lost. *)
procedure PollEscape(I,N:Integer);
{$IFDEF VER70}
var R:Registers;
begin
 if not Interactive then Exit;
 R.AH:=1; Intr($16,R);                      (* look at the next key without taking it *)
 if ((R.Flags and $40)=0) and (R.AL=27) then begin
  R.AH:=0; Intr($16,R); Cancelled:=True
 end
end;
{$ELSE}
begin
 if Interactive then if KeyPressed then if ReadKey=27 then Cancelled:=True
end;
{$ENDIF}

function Switch(Id:Integer):Boolean;
var J:Integer;
begin
 Switch:=True;
 if Id=Active then Exit;
 J:=FindId(Id); Active:=0;
 if J<>0 then if TryModel(Items[J].Name,Items[J].Check) then Active:=Id;
 if Active=0 then begin WriteLn('cannot load expert ',Id,': ',LoadError); Switch:=False end
end;

(* Small letters, digits and single spaces only. *)
function Tidy(S:String):String;
var I:Integer; C:Char; R:String;
begin
 R:='';
 for I:=1 to Length(S) do begin
  C:=S[I];
  if (C>='A') and (C<='Z') then C:=Chr(Ord(C)+32);
  if not (C in ['a'..'z','0'..'9']) then C:=' ';
  if (C<>' ') or ((R<>'') and (R[Length(R)]<>' ')) then R:=R+C
 end;
 while (R<>'') and (R[Length(R)]=' ') do Delete(R,Length(R),1);
 Tidy:=R
end;

function HasWord(S,W:String):Boolean;
begin HasWord:=Pos(' '+W+' ',' '+S+' ')>0 end;

function FirstWord(S:String):String;
var K:Integer;
begin K:=Pos(' ',S); if K=0 then FirstWord:=S else FirstWord:=Copy(S,1,K-1) end;

(* The router: which expert knows this step?  0 = none. *)
function Expert(S:String):Integer;
const
 NS=9; ScreenWords:array[1..NS] of String[10]=
  ('cursor','border','background','cls','flash','blink','row','column','col');
 NA=34; SoundWords:array[1..NA] of String[12]=
  ('beep','sound','tone','note','notes','noise','siren','alarm','scale','tune','music','melody',
   'song','speaker','hertz','hz','wait','pause','sleep','delay','hold','rest','key','keypress',
   'repeat','times','twice','again','loop','ms','milliseconds','second','seconds','moment');
 NT=10; TextVerbs:array[1..NT] of String[10]=
  ('number','new','next','newline','skip','begin','start','go','move','line');
 NC=11; ScreenNouns:array[1..NC] of String[10]=
  ('screen','display','text','letters','writing','color','colour','clear','wipe','erase','everything');
var I:Integer; F:String;
begin
 if Copy(S,1,7)='please ' then Delete(S,1,7);
 F:=FirstWord(S); Expert:=XTEXT;
 if (F='say') or (F='print') or (F='write') or (F='type') or (F='output') then Exit;
 Expert:=XSCREEN;
 for I:=1 to NS do if HasWord(S,ScreenWords[I]) then Exit;
 Expert:=XTEXT;
 if (F='show') or (F='display') or (F='put') then Exit;
 Expert:=XSOUND;
 for I:=1 to NA do if HasWord(S,SoundWords[I]) then Exit;
 Expert:=XSCREEN;
 for I:=1 to NC do if HasWord(S,ScreenNouns[I]) then
  if not HasWord(S,'line') then Exit;
 Expert:=XTEXT;
 for I:=1 to NT do if (F=TextVerbs[I]) or HasWord(S,'line') or HasWord(S,'number') then Exit;
 Expert:=0
end;

(* Cut the next word off the front of S. *)
function NextWord(var S:String):String;
var K:Integer;
begin
 while (S<>'') and (S[1]=' ') do Delete(S,1,1);
 K:=Pos(' ',S);
 if K=0 then begin NextWord:=S; S:='' end
 else begin NextWord:=Copy(S,1,K-1); Delete(S,1,K) end
end;

function Number(S:String; var V:Longint):Boolean;
var I,Code:Integer;
begin
 Number:=False;
 if (S='') or (Length(S)>5) then Exit;
 for I:=1 to Length(S) do if not (S[I] in ['0'..'9']) then Exit;
 Val(S,V,Code); Number:=Code=0
end;

(* Does the number V stand in the line L, as it is or times 1000
   (seconds written as milliseconds)? *)
function LineHas(L:String; V:Longint):Boolean;
var I:Integer; X:Longint; In_:Boolean;
begin
 LineHas:=True; X:=0; In_:=False; L:=L+' ';
 for I:=1 to Length(L) do
  if L[I] in ['0'..'9'] then begin
   if X<100000000 then X:=X*10+Ord(L[I])-48;
   In_:=True
  end else begin
   if In_ and ((X=V) or (X=V*1000)) then Exit;
   X:=0; In_:=False
  end;
 LineHas:=False
end;

(* A model can copy a number wrongly and still give a valid line.  So
   every number typed as digits in the step must be in the line. *)
function NumbersAgree(Step,L:String):Boolean;
var W:String; V:Longint;
begin
 NumbersAgree:=False;
 while Step<>'' do begin
  W:=NextWord(Step);
  if Number(W,V) then if not LineHas(L,V) then Exit
 end;
 NumbersAgree:=True
end;

(* Every text the line prints must be words of the step. *)
function TextsAgree(Step,L:String):Boolean;
var K:Integer; Part,Key:String;
begin
 TextsAgree:=False; L:=L+':';
 while L<>'' do begin
  K:=Pos(':',L); Part:=Copy(L,1,K-1); Delete(L,1,K);
  Key:=NextWord(Part);
  for K:=1 to Length(Key) do Key[K]:=UpCase(Key[K]);
  if (Key='PRINT') or (Key='ECHO') then begin
   while (Part<>'') and (Part[1]=' ') do Delete(Part,1,1);
   if Pos(' '+Part+' ',' '+Step+' ')=0 then Exit
  end
 end;
 TextsAgree:=True
end;

(* Is U (in capitals) a line of the language as it stands?  A lone PRINT
   or ECHO does not count ("print the number 42" is for an expert), nor
   does a lone beep, flash, siren or wait, which are ordinary requests. *)
function IsCode(U:String):Boolean;
var Why,K:String;
begin
 K:=U; K:=NextWord(K);
 IsCode:=CheckLine(U,Why) and not (((K='PRINT') or (K='ECHO')) and (Pos(':',U)=0))
  and (U<>'BEEP') and (U<>'FLASH') and (U<>'SIREN') and (U<>'WAIT')
end;

(* Put a line with the request's other lines, and say so. *)
function Accept(Shown,L:String; K:Char; Note:String):Boolean;
begin
 Accept:=False;
 if (NPend=MAXPEND) or (Steps+NPend+NClose>=MAXSTEPS) then begin WriteLn('too many lines'); Exit end;
 if Length(L)>120 then begin WriteLn(Shown,': line too long'); Exit end;
 Inc(NPend); Pend[NPend]:=L; PKind[NPend]:=K;
 if L[1]=#255 then L:='PRINT '+Copy(L,2,255);
 WriteLn(Cur+NPend-1,' ',Shown,' -> ',L,Note);
 Accept:=True
end;

(* One step of the request, as typed.  Force is the expert to ask, or 0
   to let the router choose. *)
function AddStep(Raw:String; Force:Integer):Boolean;
var S,A,Why,Up:String; Id,K,K2:Integer; Tokens:Longint;
begin
 AddStep:=False; A:='';
 while (Raw<>'') and (Raw[1]=' ') do Delete(Raw,1,1);
 while (Raw<>'') and (Raw[Length(Raw)]=' ') do Delete(Raw,Length(Raw),1);
 Up:=Raw; for K:=1 to Length(Up) do Up[K]:=UpCase(Up[K]);
 K:=Pos('"',Raw);
 if K>0 then begin
  (* quoted text is printed exactly as typed *)
  A:=Copy(Raw,K+1,255); K2:=Pos('"',A); if K2>0 then A:=Copy(A,1,K2-1);
  S:=Tidy(Copy(Raw,1,K-1))+' "'+A+'"';
  if (A='') or (Length(A)>60) then begin WriteLn(Cur+NPend,' ',S,': no text'); Exit end;
  AddStep:=Accept(S,#255+A,' ','   (no model)'); Exit
 end;
 S:=Tidy(Raw);
 if Copy(S,1,5)='then ' then Delete(S,1,5);
 if Copy(S,1,5)='also ' then Delete(S,1,5);
 if S='' then begin AddStep:=True; Exit end;
 if IsCode(Up) then begin
  (* typed as a line of the language *)
  A:=Raw; if (Pos('PRINT',Up)=0) and (Pos('ECHO',Up)=0) then A:=Up;
  AddStep:=Accept(Raw,A,' ','   (no model)'); Exit
 end;
 Id:=Force; if Id=0 then Id:=Expert(S);
 if Id=0 then begin WriteLn(Cur+NPend,' ',S,': not understood'); Exit end;
 if not Switch(Id) then Exit;
 Cancelled:=False; Think(S,A,Tokens,PollEscape,nil);
 if Cancelled then begin WriteLn('cancelled'); Exit end;
 if not CheckLine(A,Why) then begin
  WriteLn(Cur+NPend,' ',S,': refused "',A,'" (',Why,')'); Exit end;
 if not TextsAgree(S,A) then begin
  WriteLn(Cur+NPend,' ',S,': refused "',A,'" (text was not in the request)'); Exit end;
 if not NumbersAgree(S,A) then begin
  WriteLn(Cur+NPend,' ',S,': refused "',A,'" (numbers do not match the request)'); Exit end;
 AddStep:=Accept(S,A,' ','')
end;

(* Is this sentence a request for a small program with a loop, a
   question or a test in it?  Those go whole to the tasks expert. *)
function IsTask(S:String):Boolean;
const NK=18; TaskWords:array[1..NK] of String[10]=
 ('count','countdown','numbers','ask','table','squares','even','odd','each','every','higher','lower',
  'cycle','if','many','rounds','add','otherwise');
var I:Integer;
begin
 IsTask:=False;
 if FindId(XTASKS)=0 then Exit;
 for I:=1 to NK do if HasWord(S,TaskWords[I]) then IsTask:=True
end;

(* Split one sentence into steps at commas and at the words "and" and
   "then", but never inside double quotes. *)
function SplitSteps(R:String):Boolean;
var I:Integer; Part:String; Quote,Ok:Boolean;
 function WordAt(W:String):Boolean;
 begin WordAt:=(not Quote) and (Copy(R,I,Length(W))=W) end;
begin
 Part:=''; Quote:=False; Ok:=True; I:=1; R:=R+',';
 while (I<=Length(R)) and Ok do begin
  if R[I]='"' then Quote:=not Quote;
  if (not Quote) and (R[I]=',') then begin Ok:=AddStep(Part,0); Part:=''; Inc(I) end
  else if WordAt(' and then ') then begin Ok:=AddStep(Part,0); Part:=''; Inc(I,10) end
  else if WordAt(' and ') or WordAt(' AND ') then begin Ok:=AddStep(Part,0); Part:=''; Inc(I,5) end
  else if WordAt(' then ') or WordAt(' THEN ') then begin Ok:=AddStep(Part,0); Part:=''; Inc(I,6) end
  else begin Part:=Part+R[I]; Inc(I) end
 end;
 SplitSteps:=Ok
end;

(* ---------------------------------------------------------- blocks *)

(* A number written in digits or as a word up to twenty. *)
function WordNumber(W:String; var V:Longint):Boolean;
const Names:array[0..20] of String[9]=('zero','one','two','three','four','five','six','seven',
 'eight','nine','ten','eleven','twelve','thirteen','fourteen','fifteen','sixteen','seventeen',
 'eighteen','nineteen','twenty');
var I:Integer;
begin
 WordNumber:=Number(W,V);
 for I:=0 to 20 do if W=Names[I] then begin V:=I; WordNumber:=True end
end;

(* The counter of the count loop the new line will stand in (X, Y or
   Z), or #0 outside any; Depth is how many such loops there are. *)
function Counter(var Depth:Integer):Char;
var Stack:array[1..MAXSTEPS] of Char; N,I:Integer;
 procedure See(L:TLine; K:Char);
 begin
  if K='O' then begin
   Inc(N); Stack[N]:=#0;
   if (Copy(L,1,4)='FOR ') and (L[5] in ['X','Y','Z']) then Stack[N]:=L[5]
  end else if (K='C') and (N>0) then Dec(N)
 end;
begin
 N:=0;
 for I:=1 to Cur-1 do See(Plan[I],Kind[I]);
 for I:=1 to NPend do See(Pend[I],PKind[I]);
 Counter:=#0; Depth:=0;
 for I:=1 to N do if Stack[I]<>#0 then begin Counter:=Stack[I]; Inc(Depth) end
end;

(* The words before a colon that open a block: "repeat 3 times",
   "count from 1 to 10", "forever", "if the key is q", "if it is bigger
   than 5".  Open and Shut are the lines that start and end it. *)
function Opener(S:String; var Open,Shut:TLine):Boolean;
var W:array[1..16] of String[12]; N,I,D,Nums:Integer; V,A,B:Longint; T,F:String; Op:String[2]; Down:Boolean; C:Char;
begin
 Opener:=False; N:=0; T:=S;
 while (T<>'') and (N<16) do begin Inc(N); W[N]:=NextWord(T) end;
 if N=0 then Exit;
 F:=W[1]; Nums:=0; A:=0; B:=0; Shut:='END';
 for I:=1 to N do if WordNumber(W[I],V) then begin
  Inc(Nums); if Nums=1 then A:=V else B:=V
 end;
 if HasWord(S,'forever') or (S='keep going') then begin Open:='FOREVER'; Opener:=True end
 else if (W[N]='times') and (Nums=1) then begin
  Str(A,T); Open:='TIMES '+T; Opener:=True
 end
 else if ((F='count') or (F='for')) and (Nums>=1) then begin
  Down:=HasWord(S,'down') or HasWord(S,'backwards');
  if Nums=1 then if Down then B:=1 else begin B:=A; A:=1 end;
  C:=Counter(D);
  if D>=3 then Exit;
  C:=Chr(Ord('X')+D);
  Str(A,T); Open:='FOR '+C+'='+T;
  if A<=B then Open:=Open+' TO ' else Open:=Open+' DOWNTO ';
  Str(B,T); Open:=Open+T; Shut:='NEXT'; Opener:=True
 end
 else if (F='if') or (F='when') then begin
  if HasWord(S,'key') or HasWord(S,'press') or HasWord(S,'pressed') then begin
   T:=W[N];
   if (T='space') then Open:='IF K=32'
   else if (T='escape') or (T='esc') then Open:='IF K=27'
   else if (T='enter') or (T='return') then Open:='IF K=13'
   else if Length(T)=1 then Open:='IF K='+#39+T+#39
   else Exit;
   Opener:=True
  end else if Nums>=1 then begin
   if Nums>1 then A:=B;
   Op:='=';
   if HasWord(S,'bigger') or HasWord(S,'more') or HasWord(S,'greater') or HasWord(S,'above') or HasWord(S,'over') then Op:='>';
   if HasWord(S,'smaller') or HasWord(S,'less') or HasWord(S,'below') or HasWord(S,'under') then Op:='<';
   if HasWord(S,'least') then Op:='>=';
   if HasWord(S,'most') then Op:='<=';
   if HasWord(S,'not') and (Op='=') then Op:='<>';
   Str(A,T); Open:='IF A'+Op+T; Opener:=True
  end
 end
end;

(* A few sentences that code answers itself, because they depend on
   where in the program they stand. *)
function Special(S:String; var Ok:Boolean):Boolean;
var C:Char; D:Integer; F:String;
begin
 Special:=True; F:=FirstWord(S);
 if (S='else') or (S='otherwise') then Ok:=Accept(S,'ELSE','E','   (no model)')
 else if (S='stop') or (S='stop the program') or (S='end the program') or (S='exit the program') then
  Ok:=Accept(S,'STOP',' ','   (no model)')
 else if ((F='print') or (F='say') or (F='show')) and (HasWord(S,'count') or HasWord(S,'counter')) then begin
  C:=Counter(D);
  if C=#0 then begin WriteLn(Cur+NPend,' ',S,': there is no count here'); Ok:=False end
  else Ok:=Accept(S,'OUT '+C,' ','   (no model)')
 end
 else Special:=False
end;

function Sentence(P:String):Boolean;
var U,Head,Why:String; K,Delta:Integer; Open,Shut:TLine; Ok,Found:Boolean;
begin
 U:=P; for K:=1 to Length(U) do U[K]:=UpCase(U[K]);
 if Tidy(P)='' then Sentence:=True
 else if (Pos('"',P)=0) and IsCode(U) then Sentence:=AddStep(P,0)
 else begin
  K:=Pos(':',P); Found:=False;
  if (Pos('"',P)>0) and (Pos('"',P)<K) then K:=0;     (* a colon inside quoted text *)
  if K>0 then begin
   (* the words before a colon may open a block *)
   Head:=Copy(U,1,K-1);
   while (Head<>'') and (Head[1]=' ') do Delete(Head,1,1);
   if CheckPart(Head,Delta,Why) and (Delta=1) then begin
    Open:=Head; Shut:='END'; if Copy(Head,1,4)='FOR ' then Shut:='NEXT'; Found:=True
   end else Found:=Opener(Tidy(Copy(P,1,K-1)),Open,Shut);
   if Found and (NClose=4) then begin WriteLn('blocks too deep'); Sentence:=False; Exit end
  end;
  if Found then begin
   Ok:=Accept(Tidy(Copy(P,1,K-1))+':',Open,'O','   (no model)');
   if Ok then begin
    Inc(NClose); Closers[NClose]:=Shut;
    Ok:=Sentence(Copy(P,K+1,255))
   end;
   Sentence:=Ok
  end
  else if Pos('"',P)>0 then Sentence:=SplitSteps(P)
  else if Special(Tidy(P),Ok) then Sentence:=Ok
  else if IsTask(Tidy(P)) then Sentence:=AddStep(P,XTASKS)
  else Sentence:=SplitSteps(P)
 end
end;

(* Compile the whole program; ListName as for BeginProgram. *)
function Build(ListName:String):Boolean;
var I:Integer; Loops:Word;
begin
 Loops:=0;
 for I:=1 to Steps do if RepeatCount(Plan[I])>0 then Loops:=RepeatCount(Plan[I]);
 BeginProgram(Loops,ListName); AllowOpen:=True;
 for I:=1 to Steps do if CompileLine(Plan[I]) then ;
 Build:=EndProgram; AllowOpen:=False
end;

procedure Remove(From,Count:Integer);
var I:Integer;
begin
 for I:=From to Steps-Count do begin Plan[I]:=Plan[I+Count]; Kind[I]:=Kind[I+Count] end;
 Dec(Steps,Count)
end;

(* Plan a request: split it into sentences at . and ; and put the lines
   they give into the program before line Cur, all or none. *)
function MakePlan(R:String):Boolean;
var I,Body:Integer; Part:String; Quote,Ok:Boolean;
begin
 MakePlan:=False;
 NPend:=0; NClose:=0; Part:=''; Quote:=False; Ok:=True; R:=R+'.';
 for I:=1 to Length(R) do if Ok then begin
  if R[I]='"' then Quote:=not Quote;
  if (not Quote) and (R[I] in ['.',';']) then begin Ok:=Sentence(Part); Part:='' end
  else Part:=Part+R[I]
 end;
 if not Ok or (NPend=0) then Exit;
 Body:=NPend;
 while NClose>0 do begin      (* blocks opened by this request end after its lines *)
  if NPend=MAXPEND then begin WriteLn('too many lines'); Exit end;
  Inc(NPend); Pend[NPend]:=Closers[NClose]; PKind[NPend]:='C'; Dec(NClose)
 end;
 if Steps+NPend>MAXSTEPS then begin WriteLn('too many lines'); Exit end;
 for I:=Steps downto Cur do begin Plan[I+NPend]:=Plan[I]; Kind[I+NPend]:=Kind[I] end;
 for I:=1 to NPend do begin Plan[Cur+I-1]:=Pend[I]; Kind[Cur+I-1]:=PKind[I] end;
 Inc(Steps,NPend);
 if not Build('') then begin
  WriteLn('does not fit here: ',CompErr); Remove(Cur,NPend); Exit
 end;
 Inc(Cur,Body);      (* stay inside a block that was opened *)
 MakePlan:=True
end;

procedure Outline;
var I,D,K:Integer;
 procedure Marker;
 var J:Integer;
 begin Write('   >'); for J:=1 to D do Write('  '); WriteLn end;
begin
 D:=0;
 if Steps=0 then WriteLn('   (empty program)');
 for I:=1 to Steps do begin
  if (Kind[I]='C') and (D>0) then Dec(D);
  if I=Cur then begin
   if Kind[I]='C' then begin Inc(D); Marker; Dec(D) end else Marker
  end;
  Write(I:3,' ');
  if Kind[I]='E' then K:=D-1 else K:=D;
  while K>0 do begin Write('  '); Dec(K) end;
  if Plan[I][1]=#255 then WriteLn('PRINT "',Copy(Plan[I],2,255),'"') else WriteLn(Plan[I]);
  if Kind[I]='O' then Inc(D)
 end;
 if Cur>Steps then begin D:=0; if Steps>0 then Marker end
end;

procedure Save;
var F:File;
begin
 if Steps=0 then begin WriteLn('empty program'); Exit end;
 if not Build(OutName+'.ASM') then begin WriteLn('cannot compile: ',CompErr); Exit end;
 Assign(F,OutName+'.COM'); Rewrite(F,1); BlockWrite(F,Code^,Size); Close(F);
 WriteLn('wrote ',OutName,'.COM ',Size,' bytes, ',OutName,'.ASM')
end;

(* Move the place where lines go in.  END leaves the block, TAB and
   BACK go to the end of the next or the last block. *)
procedure Move(Cmd:String; N:Longint);
var I,D:Integer; Found:Boolean;
begin
 if Cmd='UP' then begin if Cur>1 then Dec(Cur) end
 else if Cmd='DOWN' then begin if Cur<=Steps then Inc(Cur) end
 else if Cmd='TOP' then Cur:=1
 else if Cmd='BOTTOM' then Cur:=Steps+1
 else if Cmd='GO' then begin if (N>=1) and (N<=Steps+1) then Cur:=N else WriteLn('there is no line ',N) end
 else if Cmd='TAB' then begin
  I:=Cur+1; while (I<=Steps) and (Kind[I]<>'C') do Inc(I);
  Cur:=I; if Cur>Steps+1 then Cur:=Steps+1
 end
 else if Cmd='BACK' then begin
  I:=Cur-1; while (I>=1) and (Kind[I]<>'C') do Dec(I);
  if I<1 then Cur:=1 else Cur:=I
 end
 else begin    (* END *)
  D:=0; Found:=False;
  for I:=Cur to Steps do if not Found then begin
   if Kind[I]='O' then Inc(D)
   else if Kind[I]='C' then begin
    if D=0 then begin Cur:=I+1; Found:=True end else Dec(D)
   end
  end;
  if not Found then WriteLn('not inside a block')
 end
end;

(* Delete line T, or the whole block if T opens one. *)
function DeleteAt(T:Integer):Boolean;
var I,D,Last:Integer; Found:Boolean;
begin
 DeleteAt:=False;
 if (T<1) or (T>Steps) then begin WriteLn('there is no line there'); Exit end;
 if Kind[T]='C' then begin WriteLn('delete the first line of the block instead'); Exit end;
 Last:=T;
 if Kind[T]='O' then begin
  D:=0; Found:=False;
  for I:=T+1 to Steps do if not Found then begin
   if Kind[I]='O' then Inc(D)
   else if Kind[I]='C' then begin
    if D=0 then begin Last:=I; Found:=True end else Dec(D)
   end
  end
 end;
 Remove(T,Last-T+1);
 if Cur>Last then Dec(Cur,Last-T+1) else if Cur>T then Cur:=T;
 if not Build('') then WriteLn('note: ',CompErr);
 DeleteAt:=True
end;

(* The text to show when line E is taken up for changing. *)
function LineText(E:Integer):String;
begin
 if Plan[E][1]=#255 then LineText:='print "'+Copy(Plan[E],2,255)+'"' else LineText:=Plan[E]
end;

(* Change line E to what T gives: a line of the language, or a sentence
   for the experts.  The first line of a block may only become another
   first line of a block; the lines that close blocks cannot be changed.
   If the new text is refused, the old line stays. *)
function ReplaceLine(E:Integer; T:String):Boolean;
var Old,OldShut,Open,Shut:TLine; U,Why:String; I,D,M,Delta,SaveCur:Integer; Found:Boolean;
begin
 ReplaceLine:=False;
 if (E<1) or (E>Steps) then begin WriteLn('there is no line there'); Exit end;
 if Kind[E] in ['C','E'] then begin WriteLn('this line cannot be changed; change the first line of its block'); Exit end;
 while (T<>'') and (T[Length(T)]=' ') do Delete(T,Length(T),1);
 Old:=Plan[E]; SaveCur:=Cur; NPend:=0; NClose:=0;
 if Kind[E]='O' then begin
  if (T<>'') and (T[Length(T)]=':') then Delete(T,Length(T),1);
  U:=T; for I:=1 to Length(U) do U[I]:=UpCase(U[I]);
  while (U<>'') and (U[1]=' ') do Delete(U,1,1);
  Cur:=E; Found:=False;
  if CheckPart(U,Delta,Why) and (Delta=1) then begin
   Open:=U; Shut:='END'; if Copy(U,1,4)='FOR ' then Shut:='NEXT'; Found:=True
  end else Found:=Opener(Tidy(T),Open,Shut);
  Cur:=SaveCur;
  if not Found then begin WriteLn('that does not open a block'); Exit end;
  D:=0; M:=0;
  for I:=E+1 to Steps do if M=0 then begin
   if Kind[I]='O' then Inc(D)
   else if Kind[I]='C' then begin if D=0 then M:=I else Dec(D) end
  end;
  if M=0 then Exit;
  OldShut:=Plan[M]; Plan[E]:=Open; Plan[M]:=Shut;
  if not Build('') then begin
   WriteLn('does not fit here: ',CompErr); Plan[E]:=Old; Plan[M]:=OldShut; Exit
  end;
  WriteLn(E,' ',T,' -> ',Open); ReplaceLine:=True
 end else begin
  Remove(E,1); Cur:=E;
  if MakePlan(T) then ReplaceLine:=True
  else begin
   for I:=Steps downto E do begin Plan[I+1]:=Plan[I]; Kind[I+1]:=Kind[I] end;
   Plan[E]:=Old; Kind[E]:=' '; Inc(Steps); Cur:=SaveCur;
   WriteLn('nothing changed')
  end
 end
end;

procedure Handle(L:String);
var Cmd,Rest,W:String; I:Integer; V:Longint; Changed:Boolean;
begin
 Rest:=L; Cmd:=NextWord(Rest); Changed:=False;
 for I:=1 to Length(Cmd) do Cmd[I]:=UpCase(Cmd[I]);
 while (Rest<>'') and (Rest[Length(Rest)]=' ') do Delete(Rest,Length(Rest),1);
 V:=0;
 if (Cmd='LIST') and (Rest='') then begin
  for I:=1 to LIBCOUNT do if Lib[I].Kind<4 then begin
   Write(Lib[I].Name);
   case Lib[I].Kind of
    1:Write(' n   (',Lib[I].Lo1,' to ',Lib[I].Hi1,')');
    2:Write(' n m   (',Lib[I].Lo1,' to ',Lib[I].Hi1,', ',Lib[I].Lo2,' to ',Lib[I].Hi2,')');
    3:Write(' text')
   end;
   WriteLn
  end;
  WriteLn('OUT n   ECHO text   LET v=n   INPUT v   STOP');
  WriteLn('FOR v=n TO n ... NEXT   FOR v=n DOWNTO n ... NEXT');
  WriteLn('TIMES n ... END   FOREVER ... END   IF n<n ... ELSE ... END   REPEAT n');
  Exit
 end
 else if (Cmd='HELP') and (Rest='') then begin
  WriteLn('Say what the program should do, a sentence at a time:');
  WriteLn('  make screen flash, play sound');
  WriteLn('  count down from 10 and beep each time then say liftoff');
  WriteLn('A colon opens a block; the next sentences go inside it:');
  WriteLn('  repeat 3 times:      count from 1 to 5:      forever:');
  WriteLn('  if it is bigger than 5:      if the key is q:      else');
  WriteLn('The blue line is where new code goes.  Up and Down move it, into and');
  WriteLn('out of blocks; Tab and Shift-Tab jump from block to block; Home and End');
  WriteLn('go to the top and bottom.  Del on an empty line deletes the line below.');
  WriteLn('Typed commands: END leaves a block, NEW empties the program, NAME file');
  WriteLn('names it (now ',OutName,'), LIST shows the language, QUIT ends.');
  WriteLn('F2, or Enter on an empty line, takes up the line below for changing.');
  WriteLn('In what you type: Left, Right, Home, End, Del, Ctrl-Left, Ctrl-Right.');
  WriteLn('In a script: UP DOWN TOP BOTTOM TAB BACK GO n DEL n EDIT n text SHOW.');
  Exit
 end
 else if (Cmd='MEM') and (Rest='') then begin
  {$IFDEF VER70}WriteLn('heap=',MemAvail,' largest=',MaxAvail,' stack=',Sptr);{$ENDIF}
  Exit
 end
 else if Cmd='NAME' then begin
  Rest:=Tidy(Rest);
  for I:=1 to Length(Rest) do Rest[I]:=UpCase(Rest[I]);
  if (Rest='') or (Length(Rest)>8) or (Pos(' ',Rest)>0) then WriteLn('a name has 1 to 8 letters or digits')
  else begin OutName:=Rest; WriteLn('name ',OutName) end;
  Exit
 end
 else if (Cmd='SHOW') and (Rest='') then begin Outline; Exit end
 else if (Cmd='NEW') and (Rest='') then begin Steps:=0; Cur:=1; WriteLn('new program') end
 else if ((Cmd='UP') or (Cmd='DOWN') or (Cmd='TOP') or (Cmd='BOTTOM') or (Cmd='TAB') or (Cmd='BACK') or
          (Cmd='END')) and (Rest='') then begin
  Move(Cmd,0); if not Interactive then WriteLn('at ',Cur)
 end
 else if (Cmd='GO') and Number(Rest,V) then begin
  Move(Cmd,V); if not Interactive then WriteLn('at ',Cur)
 end
 else if ((Cmd='DEL') or (Cmd='DELETE')) and ((Rest='') or Number(Rest,V)) then begin
  if Rest='' then V:=Cur;
  Changed:=DeleteAt(V)
 end
 else if (Cmd='EDIT') and (Rest<>'') then begin
  (* EDIT n text: change line n *)
  W:=NextWord(Rest);
  if Number(W,V) and (Rest<>'') then Changed:=ReplaceLine(V,Rest) else WriteLn('EDIT n text')
 end
 else if MakePlan(L) then Changed:=True
 else WriteLn('nothing added');
 if Changed then Save
end;

(* One key straight from the BIOS: its character, or 256 + the scan
   code for a key without one.  (The key routine of TNYSYS repaints the
   screen from its own buffer, which would wipe what is shown here.) *)
function GetKey:Integer;
{$IFDEF VER70}
var R:Registers;
begin
 R.AH:=0; Intr($16,R);
 if (R.AL=0) or (R.AL=$E0) then GetKey:=256+R.AH else GetKey:=R.AL
end;
{$ELSE}
begin GetKey:=ReadKey end;
{$ENDIF}

{$IFDEF VER70}
(* ------------------------------------------------- the screen editor

   At the keyboard the program is shown all the time, like a text editor.
   One line of the listing is the line being typed; it stands where the
   new code will go, indented like the block it is in.  Up and Down move
   it through the program, into and out of blocks.  Enter adds what was
   typed.  Everything the planner prints goes to a message area. *)
const MAXMSG=18; LISTTOP=3; LISTROWS=17;
var Msg:array[1..MAXMSG] of String[78]; NMsg:Integer; MsgPart:String[78];
 Field:String[200]; TopItem:Integer;
 FPos:Integer;          (* how many letters of Field stand before the cursor *)
 EditLine:Integer;      (* the line being changed, or 0 *)
 MsgBuf:array[0..127] of Char; SavedOut:TextRec;

procedure MsgLine;
var I:Integer;
begin
 if NMsg=MAXMSG then begin for I:=1 to MAXMSG-1 do Msg[I]:=Msg[I+1]; Dec(NMsg) end;
 Inc(NMsg); Msg[NMsg]:=MsgPart; MsgPart:=''
end;

(* Standard output while the editor runs: collect the text as lines. *)
function MsgOut(var F:TextRec):Integer; far;
var I:Word; C:Char;
begin
 I:=0;
 while I<F.BufPos do begin
  C:=F.BufPtr^[I]; Inc(I);
  if C=#10 then MsgLine
  else if C>=' ' then begin
   if Length(MsgPart)=78 then MsgLine;
   MsgPart:=MsgPart+C
  end
 end;
 F.BufPos:=0; MsgOut:=0
end;
function MsgNone(var F:TextRec):Integer; far;
begin MsgNone:=0 end;
function MsgOpen(var F:TextRec):Integer; far;
begin
 F.Mode:=fmOutput; F.InOutFunc:=@MsgOut; F.FlushFunc:=@MsgOut; F.CloseFunc:=@MsgNone; MsgOpen:=0
end;

procedure Row(Y:Integer; S:String; Attr:Byte);
var X:Integer;
begin
 for X:=1 to 80 do
  if X<=Length(S) then Screen[(Y-1)*80+X-1]:=Ord(S[X])+Word(Attr)*256
  else Screen[(Y-1)*80+X-1]:=32+Word(Attr)*256
end;

function Spaces(N:Integer):String;
var S:String;
begin S:=''; while (N>0) and (Length(S)<60) do begin S:=S+' '; Dec(N) end; Spaces:=S end;

(* Put the typed line after S, as much of it as fits with the cursor in
   view, and say in which column the cursor is. *)
procedure ShowField(var S:String; var CurX:Integer);
var Room,From:Integer;
begin
 Room:=76-Length(S);
 if FPos>Length(Field) then FPos:=Length(Field);
 From:=0; if FPos>=Room then From:=FPos-Room+1;
 CurX:=Length(S)+FPos-From+1;
 S:=S+Copy(Field,From+1,Room)
end;

procedure Draw(Status:String);
var I,D,Item,Y,CurX,CurY,First:Integer; S,N:String;
begin
 Str(Steps,N);
 S:=' PasTinyAsm   '+OutName+'.COM   '+N+' lines';
 if Steps=1 then Delete(S,Length(S),1);
 if Steps>0 then begin Str(Size,N); S:=S+', '+N+' bytes' end;
 Row(1,S,$70); Row(2,'',7);
 (* The listing has Steps+1 items: the lines, and the line being typed
    standing before line Cur.  Keep that one on the screen. *)
 if Cur<TopItem then TopItem:=Cur;
 if Cur>TopItem+LISTROWS-1 then TopItem:=Cur-LISTROWS+1;
 if TopItem<1 then TopItem:=1;
 D:=0; Y:=LISTTOP; CurX:=1; CurY:=LISTTOP; Item:=0;
 for I:=1 to Steps+1 do begin
  if (I<=Steps) and (Kind[I]='C') and (D>0) then Dec(D);
  if (I=Cur) and (EditLine=0) then begin
   Inc(Item);
   if (Item>=TopItem) and (Y<LISTTOP+LISTROWS) then begin
    First:=D; if (I<=Steps) and (Kind[I]='C') then Inc(First);
    S:='  > '+Spaces(First*2);
    CurX:=Length(S)+1;
    ShowField(S,CurX); CurY:=Y;
    Row(Y,S,$1F); Inc(Y)
   end
  end;
  if I<=Steps then begin
   Inc(Item);
   if (Item>=TopItem) and (Y<LISTTOP+LISTROWS) then begin
    Str(I:3,N);
    if Kind[I]='E' then S:=N+' '+Spaces((D-1)*2) else S:=N+' '+Spaces(D*2);
    if I=EditLine then begin
     (* the line being changed: what is typed stands in its place *)
     ShowField(S,CurX); CurY:=Y; Row(Y,S,$1F)
    end else begin
     if Plan[I][1]=#255 then S:=S+'PRINT "'+Copy(Plan[I],2,255)+'"' else S:=S+Plan[I];
     if Kind[I]=' ' then Row(Y,S,7) else Row(Y,S,$0B)
    end;
    Inc(Y)
   end;
   if Kind[I]='O' then Inc(D)
  end
 end;
 while Y<LISTTOP+LISTROWS do begin Row(Y,'',7); Inc(Y) end;
 Row(20,'',7);
 if Status<>'' then begin Row(21,' '+Status,$0E); Row(22,'',7); Row(23,'',7); Row(24,'',7) end
 else for I:=1 to 4 do
  if NMsg-4+I>=1 then Row(20+I,' '+Msg[NMsg-4+I],$0E) else Row(20+I,'',7);
 if NMsg>4 then begin
  (* too much to show below: a page over the listing, until a key *)
  for I:=1 to MAXMSG do if I<=NMsg then Row(2+I,' '+Msg[I],$0E) else Row(2+I,'',7);
  for I:=21 to 24 do Row(I,'',7);
  Row(24,' press a key',$0E)
 end;
 Row(25,' Up/Down move  Tab block  Enter add  F2 change  Del delete  F1 help  Alt-X quit',$70);
 Window(1,1,80,25); GotoXY(CurX,CurY); Flush
end;

procedure Editor;
var K,I:Integer; L:String; Done:Boolean; F:File;
begin
 System.Move(Output,SavedOut,SizeOf(TextRec));
 with TextRec(Output) do begin
  Handle:=$FFFF; Mode:=fmClosed; BufSize:=SizeOf(MsgBuf); BufPtr:=@MsgBuf; OpenFunc:=@MsgOpen; Name[0]:=#0
 end;
 Rewrite(Output);
 NMsg:=0; MsgPart:=''; Field:=''; FPos:=0; TopItem:=1; Done:=False; EditLine:=0;
 WriteLn('Say what the program should do and press Enter.  F1 shows more.');
 while not Done do begin
  Draw('');
  K:=GetKey;
  if K=256+67 then begin
   (* F9: save a picture of the screen, as tests/snap.asm does *)
   Assign(F,'SNAP.SCR'); Rewrite(F,1); BlockWrite(F,Screen,4000); Close(F)
  end
  else if NMsg>4 then NMsg:=0       (* a page was showing: any key puts it away *)
  else if (K>=32) and (K<=126) then begin
   if Length(Field)<200 then begin Insert(Chr(K),Field,FPos+1); Inc(FPos) end
  end
  else if K=8 then begin
   if FPos>0 then begin Delete(Field,FPos,1); Dec(FPos) end
  end
  else if K=27 then begin Field:=''; FPos:=0; EditLine:=0 end
  (* keys that work inside the typed line, while there is one *)
  else if (K=256+75) and (Field<>'') then begin if FPos>0 then Dec(FPos) end
  else if (K=256+77) and (Field<>'') then begin if FPos<Length(Field) then Inc(FPos) end
  else if (K=256+115) and (Field<>'') then begin      (* Ctrl-Left: back one word *)
   while (FPos>0) and (Field[FPos]=' ') do Dec(FPos);
   while (FPos>0) and (Field[FPos]<>' ') do Dec(FPos)
  end
  else if (K=256+116) and (Field<>'') then begin      (* Ctrl-Right: on one word *)
   while (FPos<Length(Field)) and (Field[FPos+1]<>' ') do Inc(FPos);
   while (FPos<Length(Field)) and (Field[FPos+1]=' ') do Inc(FPos)
  end
  else if (K=256+71) and (Field<>'') then FPos:=0
  else if (K=256+79) and (Field<>'') then FPos:=Length(Field)
  else if (K=256+83) and (Field<>'') then begin
   if FPos<Length(Field) then Delete(Field,FPos+1,1)
  end
  else if (K=256+60) or ((K=13) and (Field='') and (EditLine=0)) then begin
   (* F2, or Enter on an empty line: take up the line below for changing *)
   NMsg:=0;
   if Cur>Steps then WriteLn('there is no line below to change')
   else if Kind[Cur] in ['C','E'] then WriteLn('this line cannot be changed; change the first line of its block')
   else begin EditLine:=Cur; Field:=LineText(Cur); FPos:=Length(Field) end
  end
  else if (K=13) and (EditLine>0) then begin
   NMsg:=0; I:=EditLine; EditLine:=0; L:=Field; Field:=''; FPos:=0;
   if L<>'' then begin
    Draw('working...');
    if ReplaceLine(I,L) then Save
   end
  end
  else if (K>256) and (EditLine>0) and (K<>256+59) then begin EditLine:=0; Field:=''; FPos:=0 end
  else if K=256+72 then Move('UP',0) else if K=256+80 then Move('DOWN',0)
  else if K=9 then Move('TAB',0) else if K=256+15 then Move('BACK',0)
  else if K=256+71 then Move('TOP',0) else if K=256+79 then Move('BOTTOM',0)
  else if K=256+73 then begin for I:=1 to 10 do Move('UP',0) end
  else if K=256+81 then begin for I:=1 to 10 do Move('DOWN',0) end
  else if (K=256+45) or (K=256+68) then Done:=True
  else if K=256+59 then begin NMsg:=0; Handle('HELP') end
  else if (K=256+83) and (Field='') then begin NMsg:=0; Handle('DEL') end
  else if (K=13) and (Field<>'') then begin
   L:=Field; Field:=''; FPos:=0; NMsg:=0;
   if Tidy(L)='quit' then Done:=True
   else begin Draw('working...'); Handle(L) end
  end
 end;
 Close(Output);
 System.Move(SavedOut,Output,SizeOf(TextRec));
 TextAttr:=7; Window(1,1,80,25); ClrScr; GotoXY(1,1); Flush
end;
{$ENDIF}

(* Lines of a file, taken as if they had been typed. *)
procedure Script(Name:String);
var T:Text; L:String;
begin
 Assign(T,Name); {$I-}Reset(T);{$I+}
 if IOResult<>0 then begin WriteLn('cannot read ',Name); Exit end;
 while not Eof(T) do begin
  ReadLn(T,L);
  while (L<>'') and (L[1]=' ') do Delete(L,1,1);
  if (L<>'') and (Tidy(L)<>'quit') then begin WriteLn('> ',L); Handle(L) end
 end;
 Close(T)
end;

begin
 Interactive:=ConsoleIO; Active:=0; OutName:='OUT'; Steps:=0; Cur:=1;
 if not ReadCatalog then begin WriteLn('Invalid EXPERTS.CAT'); Halt(1) end;
 Creativity:=0; WriteLn('PasTinyAsm 1.2  FPU ',FPUName);
 {$IFDEF VER70}WriteLn('heap=',MemAvail);{$ENDIF}
 if not Switch(XSCREEN) then Halt(1);
 AllocMemory;
 (* MAKECOM file: start from the lines of that file *)
 if ParamCount>0 then Script(ParamStr(1));
 {$IFDEF VER70}
 if Interactive then begin
  Editor;
  if Steps>0 then WriteLn('The program is ',OutName,'.COM, its listing ',OutName,'.ASM.');
  ReleaseMemory; Halt(0)
 end;
 {$ENDIF}
 while not Eof(Input) do begin
  ReadLn(Line); WriteLn('> ',Line);      (* show what was read *)
  while (Line<>'') and (Line[1]=' ') do Delete(Line,1,1);
  if (Tidy(Line)='quit') then Break;
  if Line<>'' then Handle(Line);
  System.Flush(Output)
 end;
 ReleaseMemory
end.
