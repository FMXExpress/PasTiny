program MakeCom;
(* PasTinyAsm: turn a plain request into a small DOS program.

     > make screen flash, play sound
     1 make screen flash -> FLASH 3
     2 play sound -> BEEP 440 300
     wrote OUT.COM 153 bytes, OUT.ASM

   The work is shared like this:

     code    splits the request into steps (at commas, "and", "then")
     code    picks the expert for each step by its words
     model   turns the step into one library call, such as FLASH 3
     code    checks the call: known name, numbers in range and matching
             the numbers typed; anything else is refused
     code    writes the .COM file: load the arguments, call each routine,
             exit, then the library routines that were used

   So the model never writes an instruction.  The routines are in LIB.ASM
   and reach this program as bytes in LIB.INC.

   A step that is already a call (FLASH 3) is used as it is, and a step
   with text in double quotes prints that text exactly; neither asks a
   model.  Commands: NAME file, LIST, HELP, MEM, QUIT. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$M 16384,0,655360}{$ENDIF}
{$N+}{$E+}
uses TNYNET,TNYSYS,EXPCAT;
type TCall=record Name:String[7]; Kind:Byte; Lo1,Hi1,Lo2,Hi2,Ofs,Len:Word end;
{$I LIB.INC}
const
 MAXSTEPS=40;
 REPEATCALL=0;      (* REPEAT n is not a routine: it loops the whole program *)
 ORIGIN=$100;
 XSCREEN=1; XSOUND=2; XTEXT=3;    (* catalog ids of the experts *)
type TStep=record Call:Integer; A,B:Longint; Txt:String[60] end;
var
 Active:Integer; Interactive:Boolean;
 Plan:array[1..MAXSTEPS] of TStep; Steps:Integer;
 OutName:String[8]; Line:String;
 Code:array[0..4095] of Byte; Size:Word;

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
 NA=26; SoundWords:array[1..NA] of String[10]=
  ('beep','sound','tone','note','notes','noise','siren','alarm','scale','tune','music','melody',
   'speaker','hertz','hz','wait','pause','sleep','delay','hold','key','keypress','repeat','times',
   'twice','ms');
 NT=10; TextVerbs:array[1..NT] of String[10]=
  ('number','new','next','newline','skip','begin','start','go','move','line');
 NC=8; ScreenNouns:array[1..NC] of String[10]=
  ('screen','display','text','letters','color','colour','clear','wipe');
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
 for I:=1 to NT do if (F=TextVerbs[I]) or HasWord(S,'line') then Exit;
 Expert:=0
end;

function FindCall(S:String):Integer;
var I:Integer;
begin
 for I:=1 to Length(S) do S[I]:=UpCase(S[I]);
 FindCall:=-1;
 if S='REPEAT' then FindCall:=REPEATCALL;
 for I:=1 to LIBCOUNT do if Lib[I].Name=S then FindCall:=I
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

(* Read "NAME", "NAME n", "NAME n m" or "PRINT text" into St.  Why is the
   reason when it is refused. *)
function ParseCall(S:String; var St:TStep; var Why:String):Boolean;
var Name,W:String; Kind:Integer; Lo1,Hi1,Lo2,Hi2:Longint;
begin
 ParseCall:=False; St.A:=0; St.B:=0; St.Txt:='';
 Name:=NextWord(S); St.Call:=FindCall(Name);
 Why:='no such call';
 if St.Call<0 then Exit;
 if St.Call=REPEATCALL then begin Kind:=1; Lo1:=1; Hi1:=100; Lo2:=0; Hi2:=0 end
 else begin
  Kind:=Lib[St.Call].Kind; Lo1:=Lib[St.Call].Lo1; Hi1:=Lib[St.Call].Hi1;
  Lo2:=Lib[St.Call].Lo2; Hi2:=Lib[St.Call].Hi2
 end;
 if Kind=3 then begin
  while (S<>'') and (S[1]=' ') do Delete(S,1,1);
  Why:='no text';
  if (S='') or (Length(S)>60) then Exit;
  St.Txt:=S; ParseCall:=True; Exit
 end;
 Why:='wrong arguments';
 if Kind>=1 then begin
  W:=NextWord(S); if not Number(W,St.A) then Exit;
  Why:='number out of range';
  if (St.A<Lo1) or (St.A>Hi1) then Exit;
  Why:='wrong arguments'
 end;
 if Kind=2 then begin
  W:=NextWord(S); if not Number(W,St.B) then Exit;
  Why:='number out of range';
  if (St.B<Lo2) or (St.B>Hi2) then Exit;
  Why:='wrong arguments'
 end;
 if S<>'' then Exit;
 ParseCall:=True
end;

(* A model can copy a number wrongly and still stay in range.  So every
   number typed as digits in the step must be an argument of the call,
   as it stands or as seconds turned into milliseconds. *)
function NumbersAgree(Step:String; var St:TStep):Boolean;
var W:String; V:Longint;
begin
 NumbersAgree:=False;
 while Step<>'' do begin
  W:=NextWord(Step);
  if Number(W,V) then
   if (V<>St.A) and (V<>St.B) and (V*1000<>St.A) and (V*1000<>St.B) then Exit
 end;
 NumbersAgree:=True
end;

(* One step of the request, as typed, into the plan. *)
function AddStep(Raw:String):Boolean;
var S,A,Why:String; St:TStep; Id,K,K2:Integer; Tokens:Longint; Direct:Boolean;
begin
 AddStep:=False; A:=''; Direct:=True;
 K:=Pos('"',Raw);
 if K>0 then begin
  (* quoted text is printed exactly as typed *)
  A:=Copy(Raw,K+1,255); K2:=Pos('"',A); if K2>0 then A:=Copy(A,1,K2-1);
  for K2:=1 to Length(A) do if A[K2]='$' then A[K2]:='S';
  S:=Tidy(Copy(Raw,1,K-1))+' "'+A+'"'; A:='PRINT '+A;
  if not ParseCall(A,St,Why) then begin WriteLn(Steps+1,' ',S,': ',Why); Exit end
 end else begin
  S:=Tidy(Raw);
  if Copy(S,1,5)='then ' then Delete(S,1,5);
  if Copy(S,1,5)='also ' then Delete(S,1,5);
  if S='' then begin AddStep:=True; Exit end;
  if not ParseCall(S,St,Why) or (St.Call>0) and (Lib[St.Call].Kind=3) then begin
   Direct:=False; Id:=Expert(S);
   if Id=0 then begin WriteLn(Steps+1,' ',S,': not understood'); Exit end;
   if not Switch(Id) then Exit;
   Cancelled:=False; Think(S,A,Tokens,PollEscape,nil);
   if Cancelled then begin WriteLn('cancelled'); Exit end;
   if not ParseCall(A,St,Why) then begin
    WriteLn(Steps+1,' ',S,': refused "',A,'" (',Why,')'); Exit end;
   if (St.Call>0) and (Lib[St.Call].Kind=3) then begin
    if Pos(St.Txt,S)=0 then begin
     WriteLn(Steps+1,' ',S,': refused "',A,'" (text was not in the request)'); Exit end
   end else if not NumbersAgree(S,St) then begin
    WriteLn(Steps+1,' ',S,': refused "',A,'" (numbers do not match the request)'); Exit end
  end else begin
   A:=S; K:=Pos(' ',A+' ');
   for K2:=1 to K do if K2<=Length(A) then A[K2]:=UpCase(A[K2])
  end
 end;
 if Steps=MAXSTEPS then begin WriteLn('too many steps'); Exit end;
 Inc(Steps); Plan[Steps]:=St;
 Write(Steps,' ',S,' -> ',A); if Direct then Write('   (no model)');
 WriteLn;
 AddStep:=True
end;

(* Split the request into steps: at , ; . and at the words "and" and
   "then", but never inside double quotes. *)
function MakePlan(R:String):Boolean;
var I:Integer; Part:String; Quote,Ok:Boolean;
 function WordAt(W:String):Boolean;
 begin WordAt:=(not Quote) and (Copy(R,I,Length(W))=W) end;
begin
 Steps:=0; Part:=''; Quote:=False; Ok:=True; I:=1; R:=R+',';
 while (I<=Length(R)) and Ok do begin
  if R[I]='"' then Quote:=not Quote;
  if (not Quote) and (R[I] in [',',';','.']) then begin Ok:=AddStep(Part); Part:=''; Inc(I) end
  else if WordAt(' and then ') then begin Ok:=AddStep(Part); Part:=''; Inc(I,10) end
  else if WordAt(' and ') or WordAt(' AND ') then begin Ok:=AddStep(Part); Part:=''; Inc(I,5) end
  else if WordAt(' then ') or WordAt(' THEN ') then begin Ok:=AddStep(Part); Part:=''; Inc(I,6) end
  else begin Part:=Part+R[I]; Inc(I) end
 end;
 MakePlan:=Ok and (Steps>0)
end;

procedure Put(B:Byte);
begin Code[Size]:=B; Inc(Size) end;
procedure PutWord(W:Word);
begin Put(Lo(W)); Put(Hi(W)) end;

(* Write the program for the plan into Code.  It is laid out as: the main
   part, the routines used (in library order), then the texts.  The first
   pass only measures, so that the second knows every address. *)
procedure Assemble;
var Pass,I,J,Loops:Integer; Used:array[1..LIBCOUNT] of Boolean; Addr:array[1..LIBCOUNT] of Word;
 TextAddr:array[1..MAXSTEPS] of Word; Top,P:Word;
begin
 Loops:=0;
 for I:=1 to LIBCOUNT do begin Used[I]:=False; Addr[I]:=0 end;
 for I:=1 to Steps do begin
  TextAddr[I]:=0;
  if Plan[I].Call=REPEATCALL then Loops:=Plan[I].A else Used[Plan[I].Call]:=True
 end;
 for Pass:=1 to 2 do begin
  Size:=0;
  if Loops>0 then begin Put($B9); PutWord(Loops); Top:=Size; Put($51) end;      (* mov cx,n / push cx *)
  for I:=1 to Steps do with Plan[I] do if Call<>REPEATCALL then begin
   case Lib[Call].Kind of
    1:begin Put($B8); PutWord(A) end;                                          (* mov ax,a *)
    2:begin Put($B8); PutWord(A); Put($BB); PutWord(B) end;                    (* mov bx,b *)
    3:begin Put($BA); PutWord(ORIGIN+TextAddr[I]) end                          (* mov dx,text *)
   end;
   Put($E8); PutWord(Addr[Call]-(Size+2))                                      (* call routine *)
  end;
  if Loops>0 then begin
   Put($59); Put($49); Put($74); Put($03);                                     (* pop cx / dec cx / jz +3 *)
   Put($E9); PutWord(Top-(Size+2))                                             (* jmp top *)
  end;
  Put($B8); PutWord($4C00); Put($CD); Put($21);                                (* exit to DOS *)
  for I:=1 to LIBCOUNT do if Used[I] then begin
   Addr[I]:=Size;
   for J:=0 to Lib[I].Len-1 do Put(LibCode[Lib[I].Ofs+J])
  end;
  for I:=1 to Steps do if (Plan[I].Call<>REPEATCALL) and (Lib[Plan[I].Call].Kind=3) then begin
   TextAddr[I]:=Size;
   for J:=1 to Length(Plan[I].Txt) do Put(Ord(Plan[I].Txt[J]));
   Put(Ord('$'))
  end
 end
end;

procedure Save;
var F:File; T:Text; I,J,Loops:Integer; Used:Boolean;
begin
 Assemble;
 Assign(F,OutName+'.COM'); Rewrite(F,1); BlockWrite(F,Code,Size); Close(F);
 Loops:=0;
 for I:=1 to Steps do if Plan[I].Call=REPEATCALL then Loops:=Plan[I].A;
 Assign(T,OutName+'.ASM'); Rewrite(T);
 WriteLn(T,'; ',OutName,'.COM, written by PasTinyAsm.  The routines are in LIB.ASM.');
 WriteLn(T,'        org     100h');
 if Loops>0 then begin WriteLn(T,'        mov     cx,',Loops); WriteLn(T,'again:  push    cx') end;
 for I:=1 to Steps do with Plan[I] do if Call<>REPEATCALL then begin
  case Lib[Call].Kind of
   1:WriteLn(T,'        mov     ax,',A);
   2:begin WriteLn(T,'        mov     ax,',A); WriteLn(T,'        mov     bx,',B) end;
   3:WriteLn(T,'        mov     dx,text',I)
  end;
  WriteLn(T,'        call    L_',Lib[Call].Name)
 end;
 if Loops>0 then begin
  WriteLn(T,'        pop     cx'); WriteLn(T,'        dec     cx');
  WriteLn(T,'        jz      short done'); WriteLn(T,'        jmp     near again'); WriteLn(T,'done:')
 end;
 WriteLn(T,'        mov     ax,4C00h'); WriteLn(T,'        int     21h');
 for I:=1 to LIBCOUNT do begin
  Used:=False;
  for J:=1 to Steps do if Plan[J].Call=I then Used:=True;
  if Used then WriteLn(T,'; routine ',Lib[I].Name,' from LIB.ASM goes here')
 end;
 for I:=1 to Steps do if (Plan[I].Call<>REPEATCALL) and (Lib[Plan[I].Call].Kind=3) then
  WriteLn(T,'text',I,':  db      "',Plan[I].Txt,'$"');
 Close(T);
 WriteLn('wrote ',OutName,'.COM ',Size,' bytes, ',OutName,'.ASM')
end;

procedure Handle(L:String);
var Cmd,Rest:String; I:Integer;
begin
 Rest:=L; Cmd:=NextWord(Rest);
 for I:=1 to Length(Cmd) do Cmd[I]:=UpCase(Cmd[I]);
 if (Cmd='LIST') and (Rest='') then begin
  for I:=1 to LIBCOUNT do begin
   Write(Lib[I].Name);
   case Lib[I].Kind of
    1:Write(' n   (',Lib[I].Lo1,' to ',Lib[I].Hi1,')');
    2:Write(' n m   (',Lib[I].Lo1,' to ',Lib[I].Hi1,', ',Lib[I].Lo2,' to ',Lib[I].Hi2,')');
    3:Write(' text')
   end;
   WriteLn
  end;
  WriteLn('REPEAT n   (1 to 100)')
 end
 else if (Cmd='HELP') and (Rest='') then begin
  WriteLn('Say what the program should do, for example:');
  WriteLn('  make screen flash, play sound');
  WriteLn('  clear the screen, say "Hello!", wait two seconds, beep');
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
