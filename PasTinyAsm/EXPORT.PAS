program ExportSource;
(* PasTinyAsm: write a program kept as NAME.SRC as Turbo Pascal or QBasic.

     EXPORT name PAS      writes NAME.PAS
     EXPORT name BAS      writes NAME.BAS

   The lines of the PasTinyAsm language are turned into the other
   language by fixed rules; no model takes part.  The result is meant to
   be read and changed by a person, and to do what NAME.COM does.

   Turbo Pascal: the program uses the Crt unit for sound, delays and the
   cursor, but writes through DOS, so that text keeps the colours already
   on the screen, as it does in the .COM file.  Numbers are Words (0 to
   65535) with range and overflow checks off, and results are cut to a
   Word where they are printed or compared, which is how the .COM file
   counts.

   QBasic: numbers are long integers, which do not wrap round at 65535,
   and waits use the TIMER clock.  This side has not been run in QBasic.

   The source is read twice: once to see which variables and helper
   routines are needed, once to write the program. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$M 16384,0,0}{$ENDIF}
const MAXDEPTH=16;
 NHELP=11;
 HFlash=1; HPaint=2; HInk=3; HBorder=4; HCursor=5; HBeep=6; HSiren=7; HScale=8; HKey=9; HAsk=10; HPause=11;
var
 Pascal:Boolean;                 (* the target: Turbo Pascal, or QBasic *)
 Pass:Integer; Src,Dst:Text; Name:String;
 VarUsed:array['A'..'Z'] of Boolean; Need:array[1..NHELP] of Boolean;
 MaxTimes,Depth,TimesDepth,Indent,LineNo:Integer; Loops:Word;
 Stack:array[1..MAXDEPTH] of Char; StackT:array[1..MAXDEPTH] of Integer; StackV:array[1..MAXDEPTH] of Char;
 Failed:Boolean;

procedure Fail(Msg:String);
begin
 if not Failed then WriteLn('line ',LineNo,': ',Msg);
 Failed:=True
end;

function Upper(S:String):String;
var I:Integer; Q:Boolean;
begin
 Q:=False;
 for I:=1 to Length(S) do begin
  if S[I]=#39 then Q:=not Q else if not Q then S[I]:=UpCase(S[I])
 end;
 Upper:=S
end;

function Trim(S:String):String;
begin
 while (S<>'') and (S[1]=' ') do Delete(S,1,1);
 while (S<>'') and (S[Length(S)]=' ') do Delete(S,Length(S),1);
 Trim:=S
end;

function NumStr(N:Longint):String;
var S:String;
begin Str(N,S); NumStr:=S end;

procedure Emit(S:String);
var I:Integer;
begin
 if Pass<>2 then Exit;
 for I:=1 to Indent do Write(Dst,'  ');
 WriteLn(Dst,S)
end;

(* Is S a plain number or a single variable? *)
function Simple(S:String):Boolean;
var I:Integer;
begin
 Simple:=False;
 if S='' then Exit;
 if (Length(S)=1) and (S[1]>='A') and (S[1]<='Z') then begin Simple:=True; Exit end;
 if (Length(S)=3) and (S[1]=#39) and (S[3]=#39) then begin Simple:=True; Exit end;
 for I:=1 to Length(S) do if not (S[I] in ['0'..'9']) then Exit;
 Simple:=True
end;

(* An expression of the language in the target language. *)
function Expr(S:String):String;
var I:Integer; R:String;
begin
 R:=''; I:=1; S:=Trim(S);
 if S='' then Fail('a number is missing');
 while I<=Length(S) do begin
  if (S[I]=#39) and (I+2<=Length(S)) and (S[I+2]=#39) then begin
   if Pascal then R:=R+'Ord('#39+S[I+1]+#39')' else R:=R+'ASC("'+S[I+1]+'")';
   Inc(I,2)
  end
  else if S[I] in ['A'..'Z'] then begin VarUsed[S[I]]:=True; R:=R+S[I] end
  else if S[I] in ['0'..'9'] then R:=R+S[I]
  else if S[I]='/' then begin if Pascal then R:=R+' div ' else R:=R+' \ ' end
  else if S[I] in ['+','-','*'] then R:=R+' '+S[I]+' '
  else Fail('cannot read the number '+S);
  Inc(I)
 end;
 Expr:=R
end;

(* The same, cut to a Word where Pascal would otherwise count further. *)
function WordOf(S:String):String;
begin
 if Pascal and not Simple(Trim(S)) then WordOf:='Word('+Expr(S)+')' else WordOf:=Expr(S)
end;

(* A text as a string of the target language. *)
function Quoted(S:String):String;
var I:Integer; R:String;
begin
 R:='';
 for I:=1 to Length(S) do
  if Pascal then begin if S[I]=#39 then R:=R+#39#39 else R:=R+S[I] end
  else begin if S[I]='"' then R:=R+#39 else R:=R+S[I] end;
 if Pascal then Quoted:=#39+R+#39 else Quoted:='"'+R+'"'
end;

(* A number for PRINT in QBasic, without the space it puts in front. *)
function BasNum(S:String):String;
begin BasNum:='LTRIM$(STR$('+Expr(S)+'))' end;

procedure Push(K:Char; T:Integer; V:Char);
begin
 if Depth=MAXDEPTH then begin Fail('blocks too deep'); Exit end;
 Inc(Depth); Stack[Depth]:=K; StackT[Depth]:=T; StackV[Depth]:=V; Inc(Indent)
end;

(* Cut the first word off S. *)
function Word1(var S:String):String;
var K:Integer;
begin
 S:=Trim(S); K:=Pos(' ',S);
 if K=0 then begin Word1:=S; S:='' end
 else begin Word1:=Copy(S,1,K-1); S:=Trim(Copy(S,K+1,255)) end
end;

procedure Call1(H:Integer; PasName,BasName,Arg:String);
begin
 Need[H]:=True;
 if Pascal then Emit(PasName+'('+WordOf(Arg)+');') else Emit('CALL '+BasName+'('+Expr(Arg)+')')
end;

(* One statement; Raw is as written, for texts. *)
procedure Statement(Raw:String);
var U,Key,Rest,A,B,Op:String; I,K:Integer; V:Char; Down:Boolean;
begin
 Raw:=Trim(Raw); U:=Upper(Raw); Rest:=U; Key:=Word1(Rest);
 if Key='' then Exit;
 if (Key='PRINT') or (Key='ECHO') then begin
  A:=Trim(Copy(Raw,Length(Key)+1,255));
  if Pascal then begin
   if Key='ECHO' then Emit('WriteLn('+Quoted(A)+');') else Emit('Write('+Quoted(A)+');')
  end else begin
   if Key='ECHO' then Emit('PRINT '+Quoted(A)) else Emit('PRINT '+Quoted(A)+';')
  end
 end
 else if Key='CLS' then begin if Pascal then Emit('ClrScr;') else Emit('CLS') end
 else if (Key='NEWLINE') or (Key='NL') then begin if Pascal then Emit('WriteLn;') else Emit('PRINT') end
 else if Key='NUMBER' then begin
  if Pascal then Emit('Write('+WordOf(Rest)+');') else Emit('PRINT '+BasNum(Rest)+';')
 end
 else if Key='OUT' then begin
  if Pascal then Emit('WriteLn('+WordOf(Rest)+');') else Emit('PRINT '+BasNum(Rest))
 end
 else if Key='FLASH' then begin if Rest='' then Rest:='1'; Need[HPause]:=True; Call1(HFlash,'Flash','Flash',Rest) end
 else if Key='COLOR' then Call1(HPaint,'Paint','Paint',Rest)
 else if Key='INK' then Call1(HInk,'Ink','Ink',Rest)
 else if Key='BORDER' then begin
  if Pascal then Call1(HBorder,'Border','',Rest) else Emit('COLOR , , '+Expr(Rest))
 end
 else if Key='GOTO' then begin
  A:=Word1(Rest);
  if Pascal then Emit('GotoXY('+WordOf(Rest)+', '+WordOf(A)+');') else Emit('LOCATE '+Expr(A)+', '+Expr(Rest))
 end
 else if (Key='HIDE') or (Key='SHOW') then begin
  if Pascal then begin
   Need[HCursor]:=True;
   if Key='HIDE' then Emit('Cursor($2000);') else Emit('Cursor($0607);')
  end
  else if Key='HIDE' then Emit('LOCATE , , 0') else Emit('LOCATE , , 1')
 end
 else if Key='BEEP' then begin
  if Rest='' then Rest:='440 300';
  A:=Word1(Rest); Need[HBeep]:=True;
  if Pascal then Emit('Beep('+WordOf(A)+', '+WordOf(Rest)+');') else Emit('CALL Tone('+Expr(A)+', '+Expr(Rest)+')')
 end
 else if Key='SIREN' then begin if Rest='' then Rest:='1'; Call1(HSiren,'Siren','Siren',Rest) end
 else if Key='SCALE' then begin
  Need[HScale]:=True; if Pascal then Emit('Scale;') else Emit('CALL Scale')
 end
 else if Key='WAIT' then begin
  if Rest='' then Rest:='1000';
  if Pascal then Emit('Delay('+WordOf(Rest)+');') else begin Need[HPause]:=True; Emit('CALL Pause('+Expr(Rest)+')') end
 end
 else if Key='KEY' then begin
  VarUsed['K']:=True;
  if Pascal then begin Need[HKey]:=True; Emit('K := GetKey;') end else Emit('K = ASC(INPUT$(1))')
 end
 else if Key='STOP' then begin if Pascal then Emit('Halt;') else Emit('END') end
 else if Key='INPUT' then begin
  if (Length(Rest)<>1) or not (Rest[1] in ['A'..'Z']) then begin Fail('INPUT v expected'); Exit end;
  VarUsed[Rest[1]]:=True;
  if Pascal then begin Need[HAsk]:=True; Emit('Ask('+Rest+');') end else Emit('INPUT "", '+Rest)
 end
 else if Key='LET' then begin
  K:=Pos('=',Rest);
  if (K<>2) or not (Rest[1] in ['A'..'Z']) then begin Fail('LET v=n expected'); Exit end;
  VarUsed[Rest[1]]:=True;
  if Pascal then Emit(Rest[1]+' := '+Expr(Copy(Rest,3,255))+';') else Emit(Rest[1]+' = '+Expr(Copy(Rest,3,255)))
 end
 else if Key='FOR' then begin
  K:=Pos('=',Rest); I:=Pos(' DOWNTO ',Rest); Down:=I>0;
  if not Down then I:=Pos(' TO ',Rest);
  if (K<>2) or (I=0) or not (Rest[1] in ['A'..'Z']) then begin Fail('FOR v=n TO n expected'); Exit end;
  V:=Rest[1]; VarUsed[V]:=True;
  A:=Copy(Rest,3,I-3);
  if Down then B:=Copy(Rest,I+8,255) else B:=Copy(Rest,I+4,255);
  if Pascal then begin
   if Down then Emit('for '+V+' := '+Expr(A)+' downto '+Expr(B)+' do begin')
   else Emit('for '+V+' := '+Expr(A)+' to '+Expr(B)+' do begin')
  end else begin
   if Down then Emit('FOR '+V+' = '+Expr(A)+' TO '+Expr(B)+' STEP -1')
   else Emit('FOR '+V+' = '+Expr(A)+' TO '+Expr(B))
  end;
  Push('F',0,V)
 end
 else if Key='NEXT' then begin
  if (Depth=0) or (Stack[Depth]<>'F') then begin Fail('NEXT without FOR'); Exit end;
  Dec(Indent);
  if Pascal then Emit('end;') else Emit('NEXT '+StackV[Depth]);
  Dec(Depth)
 end
 else if Key='TIMES' then begin
  Inc(TimesDepth); if TimesDepth>MaxTimes then MaxTimes:=TimesDepth;
  if Pascal then Emit('for T'+NumStr(TimesDepth)+' := 1 to '+Expr(Rest)+' do begin')
  else Emit('FOR T'+NumStr(TimesDepth)+' = 1 TO '+Expr(Rest));
  Push('T',TimesDepth,' ')
 end
 else if Key='FOREVER' then begin
  if Pascal then Emit('repeat') else Emit('DO');
  Push('V',0,' ')
 end
 else if Key='IF' then begin
  (* the test: the first of < > = that is not inside quotes *)
  I:=1; K:=0;
  while (I<=Length(Rest)) and (K=0) do begin
   if Rest[I]=#39 then Inc(I,2) else if Rest[I] in ['<','>','='] then K:=I;
   Inc(I)
  end;
  if K=0 then begin Fail('test expected'); Exit end;
  Op:=Rest[K];
  if (K<Length(Rest)) and (Rest[K+1] in ['<','>','=']) then Op:=Op+Rest[K+1];
  A:=Copy(Rest,1,K-1); B:=Copy(Rest,K+Length(Op),255);
  if Pascal then Emit('if '+WordOf(A)+' '+Op+' '+WordOf(B)+' then begin')
  else Emit('IF '+Expr(A)+' '+Op+' '+Expr(B)+' THEN');
  Push('I',0,' ')
 end
 else if Key='ELSE' then begin
  if (Depth=0) or (Stack[Depth]<>'I') then begin Fail('ELSE without IF'); Exit end;
  Dec(Indent);
  if Pascal then Emit('end else begin') else Emit('ELSE');
  Inc(Indent)
 end
 else if Key='END' then begin
  if (Depth=0) or (Stack[Depth]='F') then begin Fail('END without TIMES, IF or FOREVER'); Exit end;
  Dec(Indent);
  case Stack[Depth] of
   'T':begin if Pascal then Emit('end;') else Emit('NEXT T'+NumStr(StackT[Depth])); Dec(TimesDepth) end;
   'V':if Pascal then Emit('until False;') else Emit('LOOP');
   'I':if Pascal then Emit('end;') else Emit('END IF')
  end;
  Dec(Depth)
 end
 else if Key='REPEAT' then begin
  Val(Rest,I,K); if (K=0) and (I>=1) and (I<=100) then Loops:=I else Fail('REPEAT n expected')
 end
 else Fail('unknown word '+Key)
end;

procedure Line(L:String);
var K:Integer; U:String;
begin
 L:=Trim(L); U:=Upper(L);
 if L='' then Exit;
 if (Copy(U,1,7)='PRINT "') and (L[Length(L)]='"') and (Length(L)>8) then begin
  (* a text kept exactly: PRINT "..." *)
  U:=Quoted(Copy(L,8,Length(L)-8));
  if Pascal then Emit('Write('+U+');') else Emit('PRINT '+U+';');
  Exit
 end;
 (* a line of several statements is kept as a remark above what it became *)
 if (Pass=2) and (Pos(':',L)>0) then if Pascal then Emit('(* '+L+' *)') else Emit(#39' '+L);
 L:=L+':';
 while (L<>'') and not Failed do begin
  K:=Pos(':',L); Statement(Copy(L,1,K-1)); Delete(L,1,K)
 end
end;

procedure W(S:String);
begin WriteLn(Dst,S) end;

procedure PascalHead;
var C:Char; S:String; I:Integer;
begin
 W('program '+Name+';');
 W('(* '+Name+'.PAS, written by PasTinyAsm EXPORT from '+Name+'.SRC.');
 W('   Compile with Turbo Pascal 7: TPC '+Name+' *)');
 W('{$R-,Q-}');
 W('uses Crt;');
 S:='';
 for C:='A' to 'Z' do if VarUsed[C] then begin if S<>'' then S:=S+', '; S:=S+C end;
 for I:=1 to MaxTimes do begin if S<>'' then S:=S+', '; S:=S+'T'+NumStr(I) end;
 if Loops>0 then begin if S<>'' then S:=S+', '; S:=S+'R0' end;
 if S<>'' then W('var '+S+': Word;');
 W('');
 if Need[HFlash] then begin
  W('(* Flash the screen N times, keeping what is on it. *)');
  W('procedure Flash(N: Word);'); W('var I, J: Word;'); W('begin');
  W('  for I := 1 to N * 2 do begin');
  W('    for J := 0 to 1999 do Mem[$B800:J * 2 + 1] := Mem[$B800:J * 2 + 1] xor $7F;');
  W('    Delay(120)'); W('  end'); W('end;'); W('')
 end;
 if Need[HPaint] then begin
  W('(* Paint the whole screen background in colour N, with bright white text. *)');
  W('procedure Paint(N: Word);'); W('var J: Word;'); W('begin');
  W('  for J := 0 to 1999 do Mem[$B800:J * 2 + 1] := (N shl 4) or 15'); W('end;'); W('')
 end;
 if Need[HInk] then begin
  W('(* Change the colour of all text on the screen to N. *)');
  W('procedure Ink(N: Word);'); W('var J: Word;'); W('begin');
  W('  for J := 0 to 1999 do Mem[$B800:J * 2 + 1] := (Mem[$B800:J * 2 + 1] and $F0) or N'); W('end;'); W('')
 end;
 if Need[HBorder] then begin
  W('procedure Border(N: Word); assembler;'); W('asm'); W('  mov ah,0Bh'); W('  mov bh,0');
  W('  mov bl,byte ptr N');
  W('  int 10h'); W('end;'); W('')
 end;
 if Need[HCursor] then begin
  W('(* $2000 hides the cursor, $0607 shows it. *)');
  W('procedure Cursor(Shape: Word); assembler;'); W('asm'); W('  mov ah,1'); W('  mov cx,Shape');
  W('  int 10h'); W('end;'); W('')
 end;
 if Need[HBeep] then begin
  W('procedure Beep(Hz, Ms: Word);'); W('begin');
  W('  if Hz >= 19 then begin Sound(Hz); Delay(Ms); NoSound end'); W('end;'); W('')
 end;
 if Need[HSiren] then begin
  W('procedure Siren(N: Word);'); W('var I, F: Word;'); W('begin');
  W('  for I := 1 to N do begin');
  W('    F := 400;');
  W('    while F < 1200 do begin Sound(F); Delay(8); Inc(F, 16) end;');
  W('    while F > 400 do begin Sound(F); Delay(8); Dec(F, 16) end');
  W('  end;'); W('  NoSound'); W('end;'); W('')
 end;
 if Need[HScale] then begin
  W('procedure Scale;'); W('const Notes: array[1..8] of Word = (262, 294, 330, 349, 392, 440, 494, 523);');
  W('var I: Word;'); W('begin');
  W('  for I := 1 to 8 do begin Sound(Notes[I]); Delay(200) end;'); W('  NoSound'); W('end;'); W('')
 end;
 if Need[HKey] then begin
  W('(* Wait for a key and give its code, read through DOS. *)');
  W('function GetKey: Word; assembler;'); W('asm'); W('  mov ah,8'); W('  int 21h'); W('  xor ah,ah');
  W('end;'); W('')
 end;
 if Need[HAsk] then begin
  W('(* Read a whole number; anything else counts as 0. *)');
  W('procedure Ask(var V: Word);'); W('var S: String; L: Longint; Code: Integer;'); W('begin');
  W('  ReadLn(S); Val(S, L, Code);'); W('  if Code <> 0 then L := 0;'); W('  V := L'); W('end;'); W('')
 end;
 W('begin');
 W('  (* write and read through DOS, so that text keeps the colours on the screen *)');
 W('  Assign(Output, '#39#39'); Rewrite(Output); Assign(Input, '#39#39'); Reset(Input);')
end;

procedure BasicHead;
begin
 W(#39' '+Name+'.BAS, written by PasTinyAsm EXPORT from '+Name+'.SRC.');
 W(#39' Run with QBasic: QBASIC /RUN '+Name);
 W('DEFLNG A-Z')
end;

procedure BasicTail;
begin
 W('END');
 if Need[HPause] then begin
  W(''); W('DEFLNG A-Z'); W('SUB Pause (Ms)'); W('  T! = TIMER'); W('  DO');
  W('  LOOP UNTIL TIMER - T! >= Ms / 1000 OR TIMER < T!'); W('END SUB')
 end;
 if Need[HFlash] then begin
  W(''); W('DEFLNG A-Z'); W('SUB Flash (N)'); W('  DEF SEG = &HB800'); W('  FOR I = 1 TO N * 2');
  W('    FOR J = 1 TO 3999 STEP 2'); W('      POKE J, PEEK(J) XOR &H7F'); W('    NEXT J');
  W('    CALL Pause(120)'); W('  NEXT I'); W('  DEF SEG'); W('END SUB')
 end;
 if Need[HPaint] then begin
  W(''); W('DEFLNG A-Z'); W('SUB Paint (N)'); W('  DEF SEG = &HB800'); W('  FOR J = 1 TO 3999 STEP 2');
  W('    POKE J, N * 16 + 15'); W('  NEXT J'); W('  DEF SEG'); W('END SUB')
 end;
 if Need[HInk] then begin
  W(''); W('DEFLNG A-Z'); W('SUB Ink (N)'); W('  DEF SEG = &HB800'); W('  FOR J = 1 TO 3999 STEP 2');
  W('    POKE J, (PEEK(J) AND &HF0) OR N'); W('  NEXT J'); W('  DEF SEG'); W('END SUB')
 end;
 if Need[HBeep] then begin
  W(''); W('DEFLNG A-Z'); W('SUB Tone (Hz, Ms)'); W('  IF Hz >= 37 THEN SOUND Hz, Ms * 18.2 / 1000');
  W('END SUB')
 end;
 if Need[HSiren] then begin
  W(''); W('DEFLNG A-Z'); W('SUB Siren (N)'); W('  FOR I = 1 TO N');
  W('    FOR F = 400 TO 1200 STEP 16: SOUND F, .15: NEXT F');
  W('    FOR F = 1200 TO 400 STEP -16: SOUND F, .15: NEXT F'); W('  NEXT I'); W('END SUB')
 end;
 if Need[HScale] then begin
  W(''); W('DEFLNG A-Z'); W('SUB Scale'); W('  PLAY "T150 O3 L8 C D E F G A B > C"'); W('END SUB')
 end
end;

var L,Kind:String; C:Char; I:Integer;
begin
 if ParamCount<>2 then begin
  WriteLn('EXPORT name PAS     writes NAME.PAS (Turbo Pascal) from NAME.SRC');
  WriteLn('EXPORT name BAS     writes NAME.BAS (QBasic)');
  Halt(1)
 end;
 Name:=ParamStr(1); Kind:=ParamStr(2);
 for I:=1 to Length(Name) do Name[I]:=UpCase(Name[I]);
 for I:=1 to Length(Kind) do Kind[I]:=UpCase(Kind[I]);
 I:=Pos('.',Name); if I>0 then Name:=Copy(Name,1,I-1);
 if (Kind<>'PAS') and (Kind<>'BAS') then begin WriteLn('the kind is PAS or BAS'); Halt(1) end;
 Pascal:=Kind='PAS'; Failed:=False;
 for C:='A' to 'Z' do VarUsed[C]:=False;
 for I:=1 to NHELP do Need[I]:=False;
 MaxTimes:=0; Loops:=0;
 for Pass:=1 to 2 do if not Failed then begin
  Assign(Src,Name+'.SRC'); {$I-}Reset(Src);{$I+}
  if IOResult<>0 then begin WriteLn('cannot read ',Name,'.SRC'); Halt(1) end;
  Depth:=0; TimesDepth:=0; LineNo:=0; Indent:=1;
  if Pass=2 then begin
   Assign(Dst,Name+'.'+Kind); Rewrite(Dst);
   if Pascal then PascalHead else BasicHead;
   if not Pascal then Indent:=0;
   if Loops>0 then begin
    if Pascal then Emit('for R0 := 1 to '+NumStr(Loops)+' do begin') else Emit('FOR R0 = 1 TO '+NumStr(Loops));
    Inc(Indent)
   end
  end;
  while not Eof(Src) and not Failed do begin ReadLn(Src,L); Inc(LineNo); Line(L) end;
  Close(Src);
  if (Depth<>0) and not Failed then Fail('a block is not closed');
  if Pass=2 then begin
   if Loops>0 then begin Dec(Indent); if Pascal then Emit('end;') else Emit('NEXT R0') end;
   if Pascal then W('end.') else BasicTail;
   Close(Dst)
  end
 end;
 if Failed then begin
  {$I-}Assign(Dst,Name+'.'+Kind); Erase(Dst);{$I+} if IOResult<>0 then ;
  Halt(1)
 end;
 WriteLn('wrote ',Name,'.',Kind)
end.
