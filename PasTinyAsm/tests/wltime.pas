program WLTIME;
(* WLTIME ROUTER.TXT [rounds]: how long the word lists that routed requests
   before the router took.  The three routines are the ones MAKECOM had
   (is it a recipe, is it a small program, which expert), run on every
   request as MAKECOM ran them, timed as RTTIME times the router. *)
const XSCREEN=1; XSOUND=2; XTEXT=3; XTASKS=4; XRECIPES=5; MAXREQ=300;
type PStr=^String;
var T:Text; L:String; Req:array[1..MAXREQ] of PStr; N,I,R,Rounds,Code:Integer; Letters,T0,T1,Sum:Longint; Ms:Real;
 Ticks:Longint absolute $40:$6C;
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

function IsTask(S:String):Boolean;
const NK=31; TaskWords:array[1..NK] of String[10]=
 ('count','countdown','numbers','ask','table','squares','even','odd','each','every','higher','lower',
  'cycle','if','many','rounds','add','otherwise','multiples','cubes','powers','asking','timer','stars',
  'triangle','rising','falling','multiply','fast','slowly','backwards');
var I:Integer; F:String;
begin
 IsTask:=False;
 for I:=1 to NK do if HasWord(S,TaskWords[I]) then IsTask:=True;
 (* "print hello 5 times" *)
 F:=FirstWord(S);
 if ((F='print') or (F='say')) and (Copy(S,Length(S)-5,6)=' times') then IsTask:=True
end;

function IsRecipe(S:String):Boolean;
var F:String;
begin
 F:=FirstWord(S);
 (* "build a ...", "create a ...", "write a ... program", "i want a ... program";
    not "repeat the program 3 times", which is about the program in hand *)
 IsRecipe:=  ((F='build') or (F='create') or
   (HasWord(S,'program') and ((F='write') or (Copy(S,1,7)='i want '))))
end;

begin
 Rounds:=1; if ParamCount>1 then Val(ParamStr(2),Rounds,Code);
 Assign(T,ParamStr(1)); Reset(T); N:=0; Letters:=0;
 while not Eof(T) and (N<MAXREQ) do begin
  ReadLn(T,L); Delete(L,1,Pos(' ',L));
  Inc(N); GetMem(Req[N],Length(L)+1); Req[N]^:=L; Inc(Letters,Length(L))
 end;
 Close(T); Sum:=0;
 T0:=Ticks; repeat until Ticks<>T0; T0:=Ticks;
 for R:=1 to Rounds do for I:=1 to N do begin
  L:=Tidy(Req[I]^);
  if IsRecipe(L) then Inc(Sum,5) else if IsTask(L) then Inc(Sum,4) else Inc(Sum,Expert(L))
 end;
 T1:=Ticks;
 Ms:=(T1-T0)*54.925;
 WriteLn(N,' requests x ',Rounds,', ',Letters,' letters a round, ',T1-T0,' ticks, sum ',Sum);
 Write(Ms/(N*1.0*Rounds):0:2,' ms a request (',Letters/N:0:0,' letters on average), ');
 WriteLn(Ms/(Letters*1.0*Rounds):0:3,' ms a letter')
end.
