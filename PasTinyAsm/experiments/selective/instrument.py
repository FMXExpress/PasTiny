"""Create a tracing copy of MAKECOM.PAS alongside the runtime files."""
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = (root / 'MAKECOM.PAS').read_text()
anchor = "  Raw0:=A; A:=PutBack(A,True,True);"
assert source.count(anchor) == 1
trace = """
  if Id=XTEXT then begin
   if Doubt[1].At>0 then WriteLn('MARGIN ',Doubt[1].Gap:0:8);
   if Passes(S,A,Why2) then WriteLn('CAND ',A);
   for K:=1 to MAXDOUBT do if Doubt[K].At>0 then begin
    Think(Q,Up,Tokens,PollEscape,nil);
    Up:=Raw0; ThinkAgain(Q,Up,Doubt[K].At,PollEscape);
    Up:=PutBack(Up,True,True);
    if (Up<>'') and Passes(S,Up,Why2) then WriteLn('CAND ',Up)
   end;
   Think(Q,Up,Tokens,PollEscape,nil)
  end;"""
(Path(sys.argv[1]) / 'TRACE.PAS').write_text(source.replace(anchor,anchor+trace))
