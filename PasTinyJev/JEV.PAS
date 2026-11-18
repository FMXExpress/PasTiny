program Jev;
(* PasTinyJev: typed decisions from a TINY 2.1 network on a 386.

   Give it a state and typed questions.  It answers with probabilities
   read straight from the network; no text is generated, so an answer
   cannot be off-schema.

     STATE  text
     NOUL   id | instructions
     CHOICE id | instructions | name=description ; name=description ...
     SCORE  id | instructions | level ; level ; level ...
     ASK    question            (text answer from the general model)
     LIST, USE id, AUTO, MEM, QUIT

   One read is "state|instructions" (noul) or "state|instructions:option"
   (choice, score) followed by the end-of-question token.  The answer is
   the score of the letter y minus the letter n at that point.  A choice
   or score is one read per option, joined by a softmax.  The state stays
   in the key/value cache, so each question costs only its own letters. *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$M 16384,0,655360}{$ENDIF}
{$N+}{$E+}
uses TNYNET,TNYSYS,EXPCAT;
const
 STATEMAX=80;   (* letters of state kept *)
 HEADLEN=53;    (* a longer state keeps its first 53 ... *)
 TAILLEN=26;    (* ... and last 26 letters *)
 MAXLEN=127;    (* letters in one read, before the final token *)
 MAXOPT=24;
type TOpt=String[60];
var
 Active:Integer; Pinned,Interactive,Fed:Boolean;
 State,Line,Cmd:String;
 OptName,OptText:array[1..MAXOPT] of TOpt;
 Delta,Prob:array[1..MAXOPT] of Single;

procedure MemoryReport;
begin
 {$IFDEF VER70}WriteLn('heap=',MemAvail,' largest=',MaxAvail,' stack=',Sptr);{$ENDIF}
end;

procedure Switch(Target:Integer);
var Old:Integer; T:Longint;
begin
 if Target=Active then Exit;
 Old:=Active; Active:=0; Fed:=False; T:=NowMs;
 if TryModel(Items[Target].Name,Items[Target].Check) then Active:=Target
 else begin
  WriteLn('load failed ',Items[Target].Name,' ',LoadError);
  if Old<>0 then
   if TryModel(Items[Old].Name,Items[Old].Check) then Active:=Old
   else WriteLn('recovery failed ',LoadError)
 end;
 if Active<>0 then WriteLn('active ',Items[Active].Id,' ',Items[Active].Title,' ms=',NowMs-T)
 else WriteLn('unloaded')
end;

procedure PollEscape(I,N:Integer);
begin
 if Interactive then if KeyPressed then if ReadKey=27 then Cancelled:=True
end;

procedure Letter(C:Integer);
begin
 Write(Chr(C)); if Interactive then System.Flush(Output);
 PollEscape(0,0)
end;

(* Lower case, printable ASCII only, single spaces, no spaces at the ends.
   The bar is the field separator, so a bar in the text becomes a slash. *)
function Tidy(S:String):String;
var I:Integer; C:Char; R:String;
begin
 R:='';
 for I:=1 to Length(S) do begin
  C:=S[I];
  if (C>='A') and (C<='Z') then C:=Chr(Ord(C)+32);
  if (C<' ') or (C>'~') then C:=' ';
  if C='|' then C:='/';
  if (C<>' ') or ((R<>'') and (R[Length(R)]<>' ')) then R:=R+C
 end;
 while (R<>'') and (R[Length(R)]=' ') do Delete(R,Length(R),1);
 Tidy:=R
end;

(* Instructions and options: tidy, no colon, no final ? . or space. *)
function TidyText(S:String):String;
var I:Integer;
begin
 for I:=1 to Length(S) do if S[I]=':' then S[I]:=',';
 S:=Tidy(S);
 while (S<>'') and (S[Length(S)] in ['?','.',' ']) do Delete(S,Length(S),1);
 TidyText:=S
end;

(* Cut the text before the first Sep off the front of S and return it. *)
function Field(var S:String; Sep:Char):String;
var K:Integer;
begin
 K:=Pos(Sep,S);
 if K=0 then begin Field:=S; S:='' end
 else begin Field:=Copy(S,1,K-1); Delete(S,1,K) end
end;

procedure SetState(S:String);
begin
 S:=Tidy(S);
 if Length(S)>STATEMAX then
  S:=Copy(S,1,HEADLEN)+' '+Copy(S,Length(S)-TAILLEN+1,TAILLEN);
 State:=S; Fed:=False;
 WriteLn('state chars=',Length(State))
end;

(* Put the state into the key/value cache unless it is there already. *)
function StateReady:Boolean;
var P:Integer;
begin
 if not Fed then begin
  P:=0; Cancelled:=False; Feed(State,P,PollEscape);
  Fed:=(not Cancelled) and (P=Length(State))
 end;
 StateReady:=Fed
end;

function Sigmoid(X:Single):Single;
begin
 if X>30 then X:=30; if X< -30 then X:=-30;
 Sigmoid:=1.0/(1.0+Exp(-X))
end;

(* Softmax of Delta[1..N] into Prob[1..N]; returns 1 - entropy / ln N. *)
function Normalise(N:Integer):Single;
var I:Integer; Big,Sum,E:Single;
begin
 Big:=Delta[1]; for I:=2 to N do if Delta[I]>Big then Big:=Delta[I];
 Sum:=0;
 for I:=1 to N do begin
  E:=Delta[I]-Big; if E< -60 then Prob[I]:=0 else Prob[I]:=Exp(E);
  Sum:=Sum+Prob[I]
 end;
 E:=0;
 for I:=1 to N do begin
  Prob[I]:=Prob[I]/Sum;
  if Prob[I]>1e-12 then E:=E+Prob[I]*Ln(Prob[I])
 end;
 if N<2 then Normalise:=1 else Normalise:=1.0+E/Ln(N)
end;

(* Split "a=b ; c=d ; e" into names and option texts.  A score numbers
   its levels 0, 1, 2 ...; a choice names them. *)
function ParseOptions(var S:String; Numbered:Boolean):Integer;
var N,K:Integer; Item,Name:String;
begin
 N:=0;
 while (S<>'') and (N<MAXOPT) do begin
  Item:=Field(S,';');
  if Numbered then begin Str(N,Name); Item:=TidyText(Item) end
  else begin
   K:=Pos('=',Item);
   if K=0 then Name:=Tidy(Item)
   else begin Name:=Tidy(Copy(Item,1,K-1)); Delete(Item,1,K) end;
   Item:=TidyText(Item); if Item='' then Item:=TidyText(Name)
  end;
  if Item<>'' then begin Inc(N); OptName[N]:=Name; OptText[N]:=Item end
 end;
 ParseOptions:=N
end;

procedure Decide(Kind:Char; Rest:String);
var Id,Instr:String; N,I,P,P0,Best,Longest:Integer; T:Longint; Conf,V:Single;
begin
 Id:=Tidy(Field(Rest,'|')); Instr:=TidyText(Field(Rest,'|'));
 if Id='' then Id:='?';
 if State='' then begin WriteLn(Id,' error=no state'); Exit end;
 if Instr='' then begin WriteLn(Id,' error=no instructions'); Exit end;
 N:=0; Longest:=0;
 if Kind<>'N' then begin
  N:=ParseOptions(Rest,Kind='S');
  if N=0 then begin WriteLn(Id,' error=no options'); Exit end;
  if Rest<>'' then begin WriteLn(Id,' error=too many options'); Exit end;
  for I:=1 to N do if Length(OptText[I])>Longest then Longest:=Length(OptText[I]);
  Inc(Longest)
 end;
 if Length(State)+1+Length(Instr)+Longest>MAXLEN then begin
  WriteLn(Id,' error=too long by ',Length(State)+1+Length(Instr)+Longest-MAXLEN); Exit
 end;
 T:=NowMs;
 if not StateReady then begin WriteLn(Id,' error=cancelled'); Exit end;
 P:=Length(State); Cancelled:=False;
 if Kind='N' then begin
  Feed('|'+Instr,P,PollEscape); V:=Sigmoid(YesNo(P));
  if not Cancelled then WriteLn(Id,' noul=',V:0:4,' ms=',NowMs-T)
 end else begin
  Feed('|'+Instr+':',P,PollEscape); P0:=P;
  for I:=1 to N do if not Cancelled then begin
   P:=P0; Feed(OptText[I],P,PollEscape); Delta[I]:=YesNo(P)
  end;
  if not Cancelled then begin
   Conf:=Normalise(N); Best:=1; V:=0;
   for I:=1 to N do begin
    if Prob[I]>Prob[Best] then Best:=I;
    V:=V+(I-1)*Prob[I]
   end;
   if Kind='C' then Write(Id,' choice=',OptName[Best])
   else Write(Id,' score=',V:0:4);
   Write(' confidence=',Conf:0:4);
   for I:=1 to N do Write(' ',OptName[I],'=',Prob[I]:0:4);
   WriteLn(' ms=',NowMs-T)
  end
 end;
 if Cancelled then WriteLn(Id,' error=cancelled')
end;

procedure Ask(Q:String);
var A:String; Tokens,T:Longint;
begin
 Q:=Clean(Q); if Q='' then Exit;
 Fed:=False; T:=NowMs;
 Think(Q,A,Tokens,PollEscape,Letter); WriteLn;
 WriteLn('answer ms=',NowMs-T,' chars=',Length(A));
 if Cancelled then WriteLn('cancelled')
end;

(* AUTO picks the model: ASK goes to the text model (catalog keyword
   "ask"), a decision to the decision model whose keyword is a word of
   the instructions, or else to the first decision model.  USE pins one
   model for everything. *)
function Pick(Text:String; IsAsk:Boolean):Boolean;
var J:Integer;
begin
 Pick:=Ready;
 if Pinned then Exit;
 J:=RouteKind(Tidy(Text),IsAsk);
 if J<>0 then Switch(J);
 Pick:=(J<>0) and Ready
end;

procedure Handle(Cmd,Rest:String);
var J,K,Code:Integer;
begin
 if Cmd='list' then begin
  for J:=1 to Count do WriteLn(Items[J].Id,' ',Items[J].Title)
 end
 else if Cmd='auto' then Pinned:=False
 else if Cmd='mem' then MemoryReport
 else if Cmd='use' then begin
  Val(Tidy(Rest),K,Code); J:=0; if Code=0 then J:=FindId(K);
  if J=0 then WriteLn('unknown id') else begin Switch(J); Pinned:=Active=J end
 end
 else if Cmd='state' then SetState(Rest)
 else if (Cmd='noul') or (Cmd='choice') or (Cmd='score') then begin
  if Pick(Copy(Rest,Pos('|',Rest)+1,255),False) then Decide(UpCase(Cmd[1]),Rest)
  else WriteLn('error=no decision model')
 end
 else if Cmd='ask' then begin
  if Pick(Rest,True) then Ask(Rest) else WriteLn('error=no text model')
 end
 else WriteLn('error=unknown command ',Cmd)
end;

begin
 Interactive:=ConsoleIO; State:=''; Fed:=False;
 Active:=0; Pinned:=False;
 if not ReadCatalog then begin WriteLn('Invalid EXPERTS.CAT'); Halt(1) end;
 Creativity:=0; WriteLn('PasTinyJev 1.0  FPU ',FPUName); MemoryReport;
 Switch(1); AllocMemory; MemoryReport;
 System.Flush(Output);
 if Interactive then begin
  WriteLn('STATE text');
  WriteLn('NOUL id | instructions');
  WriteLn('CHOICE id | instructions | name=description ; name=description');
  WriteLn('SCORE id | instructions | level ; level ; level');
  WriteLn('ASK question, LIST, USE id, AUTO, MEM, QUIT.  Escape cancels.')
 end;
 while True do begin
  if Interactive then begin Write('> '); System.Flush(Output) end;
  if Eof(Input) then Break;
  ReadLn(Line);
  while (Line<>'') and (Line[1]=' ') do Delete(Line,1,1);
  Cmd:=Tidy(Field(Line,' '));
  if Cmd='quit' then Break;
  if Cmd<>'' then Handle(Cmd,Line);
  System.Flush(Output)
 end;
 ReleaseMemory
end.
