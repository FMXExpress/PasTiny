"""Assemble the DOS world interpreter and export its lamp-word patch offset."""
from pathlib import Path
import subprocess, tempfile, struct
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    wd = Path(tmp)
    (wd/'rooms.inc').write_text('rooms:\n')
    subprocess.run(['as','--32','-I',tmp,str(root/'experiments/classic/world.s'),'-o','w.o'],cwd=wd,check=True)
    subprocess.run(['ld','-m','elf_i386','-Ttext','0x100','--oformat','binary','w.o','-o','core'],cwd=wd,check=True)
    symbols = {name:int(at,16) for at,kind,name in
               (line.split() for line in subprocess.check_output(['nm','w.o'],cwd=wd,text=True).splitlines())}
    core=(wd/'core').read_bytes()
    assert symbols['rooms']==len(core)
    (root/'WORLD.DAT').write_bytes(b'WRL1'+struct.pack('<HH',len(core),symbols['lamp'])+core)
