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
   asks a model.  Commands: NAME file, LIST, HELP, MEM, QUIT. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$M 16384,0,655360}{$ENDIF}
{$N+}{$E+}
uses TNYNET,TNYSYS,EXPCAT,TBC;
const
 MAXSTEPS=40;
 XSCREEN=1; XSOUND=2; XTEXT=3; XTASKS=4;    (* catalog ids of the experts *)
type TLine=String[120];
var
 Active:Integer; Interactive:Boolean;
 Plan:array[1..MAXSTEPS] of TLine; Steps:Integer;
 OutName:String[8]; Line:String;

procedure PollEscape(I,N:Integer);
begin
 if Interactive then if KeyPressed then if ReadKey=27 then Cancelled:=True
end;

function Switch(Id:Integer):Boolean;
var J:Integer;
begin
 Switch:=True;
 if Id=Active then Exit;
 J:=FindId(Id); Active:=0;
 if J<>0 then if TryModel(Items[J].Name,Items[J].Check) then Active:=Id;
 if Active=0 then begin WriteLn('cannot load expert ',Id); Switch:=False end
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

(* One step of the request, as typed, into the plan.  Force is the
   expert to ask, or 0 to let the router choose. *)
function AddStep(Raw:String; Force:Integer):Boolean;
var S,A,Why,Up:String; Id,K,K2:Integer; Tokens:Longint; Direct:Boolean;
begin
 AddStep:=False; A:=''; Direct:=True;
 while (Raw<>'') and (Raw[1]=' ') do Delete(Raw,1,1);
 while (Raw<>'') and (Raw[Length(Raw)]=' ') do Delete(Raw,Length(Raw),1);
 Up:=Raw; for K:=1 to Length(Up) do Up[K]:=UpCase(Up[K]);
 K:=Pos('"',Raw);
 if K>0 then begin
  (* quoted text is printed exactly as typed *)
  A:=Copy(Raw,K+1,255); K2:=Pos('"',A); if K2>0 then A:=Copy(A,1,K2-1);
  S:=Tidy(Copy(Raw,1,K-1))+' "'+A+'"';
  if (A='') or (Length(A)>60) then begin WriteLn(Steps+1,' ',S,': no text'); Exit end;
  A:=#255+A
 end else begin
  S:=Tidy(Raw);
  if Copy(S,1,5)='then ' then Delete(S,1,5);
  if Copy(S,1,5)='also ' then Delete(S,1,5);
  if S='' then begin AddStep:=True; Exit end;
  if IsCode(Up) then begin
   A:=Raw; S:=Raw;    (* typed as a line of the language *)
   if (Pos('PRINT',Up)=0) and (Pos('ECHO',Up)=0) then A:=Up
  end else begin
   Direct:=False; Id:=Force; if Id=0 then Id:=Expert(S);
   if Id=0 then begin WriteLn(Steps+1,' ',S,': not understood'); Exit end;
   if not Switch(Id) then Exit;
   Cancelled:=False; Think(S,A,Tokens,PollEscape,nil);
   if Cancelled then begin WriteLn('cancelled'); Exit end;
   if not CheckLine(A,Why) then begin
    WriteLn(Steps+1,' ',S,': refused "',A,'" (',Why,')'); Exit end;
   if not TextsAgree(S,A) then begin
    WriteLn(Steps+1,' ',S,': refused "',A,'" (text was not in the request)'); Exit end;
   if not NumbersAgree(S,A) then begin
    WriteLn(Steps+1,' ',S,': refused "',A,'" (numbers do not match the request)'); Exit end
  end
 end;
 if Steps=MAXSTEPS then begin WriteLn('too many steps'); Exit end;
 if Length(A)>120 then begin WriteLn(Steps+1,' ',S,': line too long'); Exit end;
 Inc(Steps); Plan[Steps]:=A;
 if A[1]=#255 then A:='PRINT '+Copy(A,2,255);
 Write(Steps,' ',S,' -> ',A); if Direct then Write('   (no model)');
 WriteLn;
 AddStep:=True
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

(* Split the request into sentences at . and ; and plan each one. *)
function MakePlan(R:String):Boolean;
var I:Integer; Part:String; Quote,Ok:Boolean;
 function Sentence(P:String):Boolean;
 var U:String; K:Integer;
 begin
  U:=P; for K:=1 to Length(U) do U[K]:=UpCase(U[K]);
  if Tidy(P)='' then Sentence:=True
  else if Pos('"',P)>0 then Sentence:=SplitSteps(P)
  else if IsCode(U) then Sentence:=AddStep(P,0)
  else if IsTask(Tidy(P)) then Sentence:=AddStep(P,XTASKS)
  else Sentence:=SplitSteps(P)
 end;
begin
 Steps:=0; Part:=''; Quote:=False; Ok:=True; R:=R+'.';
 for I:=1 to Length(R) do if Ok then begin
  if R[I]='"' then Quote:=not Quote;
  if (not Quote) and (R[I] in ['.',';']) then begin Ok:=Sentence(Part); Part:='' end
  else Part:=Part+R[I]
 end;
 MakePlan:=Ok and (Steps>0)
end;

procedure Save;
var F:File; I:Integer; Loops:Word;
begin
 Loops:=0;
 for I:=1 to Steps do if RepeatCount(Plan[I])>0 then Loops:=RepeatCount(Plan[I]);
 BeginProgram(Loops,OutName+'.ASM');
 for I:=1 to Steps do if CompileLine(Plan[I]) then ;
 if not EndProgram then begin WriteLn('cannot compile: ',CompErr); Exit end;
 Assign(F,OutName+'.COM'); Rewrite(F,1); BlockWrite(F,Code^,Size); Close(F);
 WriteLn('wrote ',OutName,'.COM ',Size,' bytes, ',OutName,'.ASM')
end;

procedure Handle(L:String);
var Cmd,Rest:String; I:Integer;
begin
 Rest:=L; Cmd:=NextWord(Rest);
 for I:=1 to Length(Cmd) do Cmd[I]:=UpCase(Cmd[I]);
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
  WriteLn('OUT n   ECHO text   LET v=n   INPUT v');
  WriteLn('FOR v=n TO n ... NEXT   FOR v=n DOWNTO n ... NEXT');
  WriteLn('TIMES n ... END   IF n<n ... ELSE ... END   REPEAT n')
 end
 else if (Cmd='HELP') and (Rest='') then begin
  WriteLn('Say what the program should do, for example:');
  WriteLn('  make screen flash, play sound');
  WriteLn('  clear the screen, say "Hello!", wait two seconds, beep');
  WriteLn('  count down from 10 and beep each time then say liftoff');
  WriteLn('  FOR I=1 TO 5:OUT I*I:NEXT');
  WriteLn('NAME file   name of the program to write (now ',OutName,')');
  WriteLn('LIST        the library calls.  QUIT ends.')
 end
 else if (Cmd='MEM') and (Rest='') then begin
  {$IFDEF VER70}WriteLn('heap=',MemAvail,' largest=',MaxAvail,' stack=',Sptr);{$ENDIF}
 end
 else if Cmd='NAME' then begin
  Rest:=Tidy(Rest);
  for I:=1 to Length(Rest) do Rest[I]:=UpCase(Rest[I]);
  if (Rest='') or (Length(Rest)>8) or (Pos(' ',Rest)>0) then WriteLn('a name has 1 to 8 letters or digits')
  else begin OutName:=Rest; WriteLn('name ',OutName) end
 end
 else if MakePlan(L) then Save
 else WriteLn('nothing written')
end;

begin
 Interactive:=ConsoleIO; Active:=0; OutName:='OUT';
 if not ReadCatalog then begin WriteLn('Invalid EXPERTS.CAT'); Halt(1) end;
 Creativity:=0; WriteLn('PasTinyAsm 1.0  FPU ',FPUName);
 if not Switch(XSCREEN) then Halt(1);
 AllocMemory;
 if Interactive then WriteLn('Say what the program should do.  HELP, LIST, NAME file, QUIT.');
 while True do begin
  if Interactive then begin Write('> '); System.Flush(Output) end;
  if Eof(Input) then Break;
  ReadLn(Line);
  while (Line<>'') and (Line[1]=' ') do Delete(Line,1,1);
  if (Tidy(Line)='quit') then Break;
  if Line<>'' then Handle(Line);
  System.Flush(Output)
 end;
 ReleaseMemory
end.
