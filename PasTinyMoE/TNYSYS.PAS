unit TNYSYS;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$DEFINE TINYDOS}{$ENDIF}
{$IFDEF GO32V2}{$DEFINE TINYDOS}{$ENDIF}
{$IFDEF MSDOS}{$DEFINE TINYDOS}{$ENDIF}
{$N+}{$E+}
{$R-}{$Q-}
interface
const ScreenWidth=80; ScreenHeight=25;
type TScreen=array[0..1999] of Word;
var TextAttr:Byte; Screen:TScreen; SkipDelays:Boolean;
procedure Window(X1,Y1,X2,Y2:Integer);
procedure GotoXY(X,Y:Integer);
function WhereX:Integer;
function WhereY:Integer;
procedure PutCh(C:Char);
procedure PutS(S:String);
procedure ClrScr;
procedure GetText(X1,Y1,X2,Y2:Integer; var Dest);
procedure Flush;
procedure DelayMs(Ms:Word);
function NowMs:Longint;
function NowUs:Longint;
function KeyPressed:Boolean;
function ReadKey:Integer;
procedure Sound(Hz:Word);
procedure NoSound;
procedure Cursor(OnOff:Boolean);
function HasVGA:Boolean;
procedure SetDAC(Index,Red,Green,Blue:Byte);
procedure DisableBlink;
procedure TextMode(Mode:Byte);
function VideoMode:Byte;
function ConsoleIO:Boolean;
function ClockText:String;
function BuildName:String;
function FPUName:String;
implementation
uses
 {$IFDEF TINYDOS}Dos{$IFDEF GO32V2},Go32{$ENDIF}
 {$ELSE}SysUtils{$IFDEF UNIX},BaseUnix{$ENDIF}{$IFDEF WINDOWS},Windows{$ENDIF}{$ENDIF};
var Wx1,Wy1,Wx2,Wy2,Cx,Cy:Integer;
 CursorShape:Word;
 {$IFDEF TINYDOS}LastTicks,EpochTicks:Longint;{$ENDIF}
procedure Window(X1,Y1,X2,Y2:Integer);
begin Wx1:=X1; Wy1:=Y1; Wx2:=X2; Wy2:=Y2; Cx:=1; Cy:=1 end;
procedure GotoXY(X,Y:Integer);
begin Cx:=X; Cy:=Y end;
function WhereX:Integer;
begin WhereX:=Cx end;
function WhereY:Integer;
begin WhereY:=Cy end;
procedure Scroll;
var X,Y:Integer;
begin
 for Y:=Wy1 to Wy2-1 do for X:=Wx1 to Wx2 do
  Screen[(Y-1)*80+X-1]:=Screen[Y*80+X-1];
 for X:=Wx1 to Wx2 do Screen[(Wy2-1)*80+X-1]:=Word(TextAttr)*256+32;
 Cy:=Wy2-Wy1+1
end;
procedure PutCh(C:Char);
var At:Integer;
begin
 if C=#13 then Cx:=1 else if C=#10 then begin
  Inc(Cy); if Cy>Wy2-Wy1+1 then Scroll
 end else begin
  At:=(Wy1+Cy-2)*80+Wx1+Cx-2;
  if (At>=0) and (At<2000) then Screen[At]:=Ord(C)+Word(TextAttr)*256;
  Inc(Cx); if Cx>Wx2-Wx1+1 then begin
   Cx:=1; Inc(Cy); if Cy>Wy2-Wy1+1 then Scroll
  end
 end
end;
procedure PutS(S:String);
var I:Integer;
begin for I:=1 to Length(S) do PutCh(S[I]) end;
procedure ClrScr;
var X,Y:Integer;
begin
 for Y:=Wy1 to Wy2 do for X:=Wx1 to Wx2 do
  Screen[(Y-1)*80+X-1]:=Word(TextAttr)*256+32;
 Cx:=1; Cy:=1
end;
procedure GetText(X1,Y1,X2,Y2:Integer; var Dest);
var Buf:TScreen; X,Y,N:Integer;
begin
 N:=0; for Y:=Y1 to Y2 do for X:=X1 to X2 do begin
  Buf[N]:=Screen[(Y-1)*80+X-1]; Inc(N)
 end;
 Move(Buf,Dest,N*2)
end;
{$IFDEF TINYDOS}
function VideoMode:Byte;
var R:Registers;
begin R.AH:=$0F; Intr($10,R); VideoMode:=R.AL end;
procedure Flush;
var Segment:Word; R:Registers;
begin
 if VideoMode=7 then Segment:=$B000 else Segment:=$B800;
 {$IFDEF GO32V2}DosMemPut(Segment,0,Screen,4000);{$ELSE}
 {$IFDEF DPMI}
 if Segment=$B000 then Move(Screen,Mem[SegB000:0],4000)
 else Move(Screen,Mem[SegB800:0],4000);
 {$ELSE}Move(Screen,Mem[Segment:0],4000);{$ENDIF}{$ENDIF}
 R.AH:=2; R.BH:=0; R.DL:=Wx1+Cx-2; R.DH:=Wy1+Cy-2; Intr($10,R)
end;
function InByte(P:Word):Byte;
begin
 {$IFDEF GO32V2}InByte:=InPortB(P);{$ELSE}InByte:=Port[P];{$ENDIF}
end;
procedure OutByte(P:Word; V:Byte);
begin
 {$IFDEF GO32V2}OutPortB(P,V);{$ELSE}Port[P]:=V;{$ENDIF}
end;
function BiosTicks:Longint;
var T:Longint;
begin
 {$IFDEF GO32V2}DosMemGet($40,$6C,T,4);{$ELSE}
 {$IFDEF DPMI}Move(Mem[Seg0040:$6C],T,4);{$ELSE}Move(Mem[$40:$6C],T,4);{$ENDIF}{$ENDIF}
 BiosTicks:=T
end;
function NowUs:Longint;
var T1,T2,Elapsed:Longint; Lo,Hi:Byte; Count:Word;
 Sub:Longint;
begin
 repeat
  T1:=BiosTicks; OutByte($43,0); Lo:=InByte($40); Hi:=InByte($40);
  T2:=BiosTicks
 until T1=T2;
 Count:=Word(Lo)+Word(Hi)*256;
 if T1<LastTicks then EpochTicks:=EpochTicks-$1800B0;
 LastTicks:=T1; Elapsed:=T1-EpochTicks;
 (* Modular microseconds: interval consumers handle the signed wrap. *)
 (* A timer tick is 54925.4 microseconds and a count of the timer chip
    0.8381; in whole numbers, which wrap around as the stamp is meant to. *)
 Sub:=65535-Longint(Count);
 NowUs:=Elapsed*54925+(Elapsed*4) div 10+(Sub*8381) div 10000
end;
function NowMs:Longint;
var T1,T2,Elapsed:Longint; Lo,Hi:Byte; Count:Word;
begin
 repeat
  T1:=BiosTicks; OutByte($43,0); Lo:=InByte($40); Hi:=InByte($40); T2:=BiosTicks
 until T1=T2;
 Count:=Word(Lo)+Word(Hi)*256;
 if T1<LastTicks then EpochTicks:=EpochTicks-$1800B0;
 LastTicks:=T1; Elapsed:=T1-EpochTicks;
 (* A timer tick is 54.9254 milliseconds and the timer chip counts 1193.182
    times in one; in whole numbers, good for the 24 days a tick count lasts. *)
 NowMs:=Elapsed*54+(Elapsed div 10000)*9254+((Elapsed mod 10000)*9254) div 10000+
        ((65535-Longint(Count))*1000) div 1193182
end;
function KeyPressed:Boolean;
var R:Registers;
begin Flush; R.AH:=1; Intr($16,R); KeyPressed:=(R.Flags and $40)=0 end;
function ReadKey:Integer;
var R:Registers;
begin
 Flush; R.AH:=0; Intr($16,R);
 if (R.AL=0) or (R.AL=$E0) then ReadKey:=256+R.AH else ReadKey:=R.AL
end;
procedure Sound(Hz:Word);
var Divisor:Word;
begin
 if Hz=0 then begin NoSound; Exit end;
 Divisor:=1193182 div Hz; OutByte($43,$B6);
 OutByte($42,Lo(Divisor)); OutByte($42,Hi(Divisor));
 OutByte($61,InByte($61) or 3)
end;
procedure NoSound;
begin OutByte($61,InByte($61) and $FC) end;
procedure Cursor(OnOff:Boolean);
var R:Registers;
begin
 if not OnOff then begin
  R.AH:=3; R.BH:=0; Intr($10,R);
  if R.CX<>$2000 then CursorShape:=R.CX;
  R.CX:=$2000
 end else R.CX:=CursorShape;
 R.AH:=1; Intr($10,R)
end;
function HasVGA:Boolean;
var R:Registers;
begin R.AX:=$1A00; Intr($10,R); HasVGA:=R.AL=$1A end;
procedure SetDAC(Index,Red,Green,Blue:Byte);
var R:Registers;
begin
 R.AX:=$1010; R.BX:=Index; R.DH:=Red; R.CH:=Green; R.CL:=Blue; Intr($10,R)
end;
procedure DisableBlink;
var R:Registers;
begin R.AX:=$1003; R.BL:=0; Intr($10,R) end;
procedure TextMode(Mode:Byte);
var R:Registers;
begin R.AH:=0; R.AL:=Mode; Intr($10,R) end;
function IsConsole(Handle:Word; Mask:Word):Boolean;
var R:Registers;
begin
 R.AX:=$4400; R.BX:=Handle; MsDos(R);
 IsConsole:=((R.Flags and 1)=0) and ((R.DX and ($80 or Mask))=($80 or Mask))
end;
function ConsoleIO:Boolean;
begin ConsoleIO:=IsConsole(0,1) and IsConsole(1,2) end;
function ClockText:String;
var H,M,S,Hs:Word; A,B:String;
begin
 GetTime(H,M,S,Hs); Str(H:2,A); Str(M:2,B);
 if A[1]=' ' then A[1]:='0'; if B[1]=' ' then B[1]:='0'; ClockText:=A+':'+B
end;
{$ELSE}
function NowMs:Longint;
begin NowMs:=Longint(GetTickCount64 and $7FFFFFFF) end;
function NowUs:Longint;
begin NowUs:=Longint((GetTickCount64*1000) and $7FFFFFFF) end;
procedure Flush; begin end;
function KeyPressed:Boolean; begin KeyPressed:=False end;
function ReadKey:Integer; begin ReadKey:=27 end;
procedure Sound(Hz:Word); begin end;
procedure NoSound; begin end;
procedure Cursor(OnOff:Boolean); begin end;
function HasVGA:Boolean; begin HasVGA:=False end;
procedure SetDAC(Index,Red,Green,Blue:Byte); begin end;
procedure DisableBlink; begin end;
procedure TextMode(Mode:Byte); begin end;
function VideoMode:Byte; begin VideoMode:=3 end;
function ConsoleIO:Boolean; begin ConsoleIO:=False end;
function ClockText:String; begin ClockText:=FormatDateTime('hh:nn',Now) end;
{$ENDIF}
procedure DelayMs(Ms:Word);
var T:Longint;
begin
 Flush; if SkipDelays then Exit;
 T:=NowMs; while NowMs-T<Ms do begin end
end;
function BuildName:String;
begin
 {$IFDEF TINYDOS}
 {$IFDEF FPC}BuildName:='FPC go32v2';{$ELSE}
 {$IFDEF DPMI}BuildName:='BP7 DPMI';{$ELSE}BuildName:='TP7 real mode';{$ENDIF}{$ENDIF}
 {$ELSE}BuildName:='host';{$ENDIF}
end;
function FPUName:String;
begin
 {$IFDEF VER70}if Test8087=0 then FPUName:='no' else FPUName:='yes';
 {$ELSE}FPUName:='unknown';{$ENDIF}
end;
begin
 TextAttr:=7; CursorShape:=$0607; SkipDelays:=False;
 Window(1,1,80,25); ClrScr;
 {$IFDEF TINYDOS}EpochTicks:=BiosTicks; LastTicks:=EpochTicks;{$ENDIF}
end.
