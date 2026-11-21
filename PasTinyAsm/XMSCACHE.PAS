unit XMSCACHE;
(* Keep expert files in extended memory.

   Changing experts means loading 381,808 bytes, and from a disk that is
   the slow part of the whole program on a real 386.  With an XMS driver
   (HIMEM.SYS) a file can be read from the disk once, kept above the
   first megabyte, and copied down each time it is needed.

     XmsPresent           is there a driver?
     XmsFreeKB            the largest free block, in KB
     XmsStore(Name)       read a file into a new block; its handle, or 0
     XmsRead(H,Pos,B,N)   copy N bytes (an even number) from the block

   Every block is given back when the program ends, however it ends.
   Without a driver, and in the host build, XmsPresent is False and
   XmsStore gives 0, which the caller takes to mean "use the disk". *)
{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$IFDEF VER70}{$F+}{$ENDIF}
interface
function XmsPresent:Boolean;
function XmsFreeKB:Word;
function XmsStore(Name:String):Word;
function XmsRead(Handle:Word; Pos:Longint; var Buf; Count:Word):Boolean;
implementation
{$IFDEF VER70}
uses Dos;
type TMove=record Len:Longint; SrcH:Word; SrcOfs:Longint; DstH:Word; DstOfs:Longint end;
const MAXH=8;
var Entry:Pointer; Have:Boolean; M:TMove;
 Handles:array[1..MAXH] of Word; NH:Integer; OldExit:Pointer;

function Alloc(KB:Word):Word; assembler;
asm
 mov ah,9
 mov dx,KB
 call dword ptr Entry
 or ax,ax
 jz @none
 mov ax,dx
 jmp @done
@none:
 xor ax,ax
@done:
end;

procedure Release(H:Word); assembler;
asm
 mov ah,0Ah
 mov dx,H
 call dword ptr Entry
end;

function Largest:Word; assembler;
asm
 mov ah,8
 call dword ptr Entry
end;

(* Do the move described in M. *)
function MoveIt:Boolean; assembler;
asm
 mov si,offset M
 mov ah,0Bh
 call dword ptr Entry
end;

function XmsPresent:Boolean;
begin XmsPresent:=Have end;

function XmsFreeKB:Word;
begin if Have then XmsFreeKB:=Largest else XmsFreeKB:=0 end;

function XmsRead(Handle:Word; Pos:Longint; var Buf; Count:Word):Boolean;
begin
 M.Len:=Count; M.SrcH:=Handle; M.SrcOfs:=Pos; M.DstH:=0; M.DstOfs:=Longint(@Buf);
 XmsRead:=Have and (Handle<>0) and MoveIt
end;

function XmsStore(Name:String):Word;
var F:File; Got:Word;
 Chunk:array[0..511] of Byte;      (* small: this is called from deep in the planner *)
 H:Word; Pos,Size:Longint; Ok:Boolean;
begin
 XmsStore:=0;
 if not Have or (NH=MAXH) then Exit;
 FileMode:=0; Assign(F,Name);
 {$I-}Reset(F,1);{$I+}
 if IOResult<>0 then Exit;
 Size:=FileSize(F);
 H:=Alloc((Size+1023) div 1024);
 Ok:=H<>0; Pos:=0;
 while Ok and (Pos<Size) do begin
  {$I-}BlockRead(F,Chunk,SizeOf(Chunk),Got);{$I+}
  Ok:=(IOResult=0) and (Got>0);
  if Ok then begin
   if Odd(Got) then begin Chunk[Got]:=0; Inc(Got) end;      (* a move is a whole number of words *)
   M.Len:=Got; M.SrcH:=0; M.SrcOfs:=Longint(@Chunk); M.DstH:=H; M.DstOfs:=Pos;
   Ok:=MoveIt; Inc(Pos,Got)
  end
 end;
 {$I-}Close(F);{$I+} if IOResult<>0 then ;
 if Ok then begin Inc(NH); Handles[NH]:=H; XmsStore:=H end
 else if H<>0 then Release(H)
end;

procedure GiveBack;
var I:Integer;
begin
 ExitProc:=OldExit;
 for I:=1 to NH do Release(Handles[I]);
 NH:=0
end;

procedure Detect;
var R:Registers;
begin
 Have:=False; NH:=0;
 R.AX:=$4300; Intr($2F,R);
 if R.AL=$80 then begin
  R.AX:=$4310; Intr($2F,R);
  Entry:=Ptr(R.ES,R.BX); Have:=True
 end
end;

{$ELSE}
function XmsPresent:Boolean; begin XmsPresent:=False end;
function XmsFreeKB:Word; begin XmsFreeKB:=0 end;
function XmsStore(Name:String):Word; begin XmsStore:=0 end;
function XmsRead(Handle:Word; Pos:Longint; var Buf; Count:Word):Boolean; begin XmsRead:=False end;
{$ENDIF}

begin
 {$IFDEF VER70}Detect; OldExit:=ExitProc; ExitProc:=@GiveBack{$ENDIF}
end.
