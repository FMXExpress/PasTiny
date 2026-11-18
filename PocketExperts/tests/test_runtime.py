"""Run with a native FPC build of EXPERT and the expanded FLOPPY3 fixture."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

exe=Path(sys.argv[1]).resolve()
root=Path(__file__).resolve().parents[1]
def run(commands):
    return subprocess.run([exe],input=commands,text=True,capture_output=True,cwd=dest)

with tempfile.TemporaryDirectory() as tmp:
    dest=Path(tmp)/"runtime"
    shutil.copytree(root/"dist/FLOPPY3",dest)
    catalog=dest/"EXPERTS.CAT"
    original=catalog.read_bytes()
    for offset,payload in [(0,b"FAIL"),(4,b"\x81"),(4,b"\0"),(5+68,b"\x01"),(6,b"\xff"),(7,b"/"),(0,original+b"!")]:
        raw=bytearray(original)
        raw[offset:offset+len(payload)]=payload
        catalog.write_bytes(raw)
        assert run("quit\n").returncode==1,offset
    catalog.write_bytes(original)
    first=dest/"E001.BIN"
    second=dest/"E002.BIN"
    model=second.read_bytes()
    for bad in (None,model[:-1],model+b"!",b"FAIL"+model[4:],model[:4]+b"\0"+model[5:],model[:12]+bytes.fromhex("0000807f")+model[16:],model[:-1]+bytes([model[-1]^1])):
        if bad is None: second.unlink()
        else: second.write_bytes(bad)
        out=run("use 2\nuse 1\nwhat is 7 times 8\nquit\n").stdout
        assert "load failed E002" in out and out.count("active 1 ")==2 and "7 times 8 is 56." in out,out
    first.unlink()
    out=run("what is 7 times 8\nquit\n").stdout
    assert "unloaded" in out and "active 3 " in out,out
    first.write_bytes(model)
    second.write_bytes(model)
    gold=[line[4:] for line in (root/"tests/gold_c.txt").read_text().splitlines() if line.startswith(">   ")]
    out=run((root/"tests/questions.txt").read_text()).stdout.splitlines()
    actual=[out[i-1] for i,line in enumerate(out) if line.startswith("answer ms=")]
    assert actual==gold and len(gold)==60,(len(actual),len(gold))
print("Host: 60/60 exact, catalog rejection, seven replacement failures and first-load recovery passed.")
