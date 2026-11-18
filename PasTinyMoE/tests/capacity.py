"""Exercise the host runtime's catalog boundaries with baseline fixture weights."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root=Path(__file__).resolve().parents[1]
exe=Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory() as tmp:
    dest=Path(tmp)
    shutil.copyfile(root/"TINY.BIN",dest/"E001.BIN")
    record=(root/"dist/FLOPPY3/EXPERTS.CAT").read_bytes()[5:73]
    for n in (3,100,128,129):
        cat=b"PEC1"+bytes([n])+b"".join(bytes([i])+record[1:] for i in range(1,n+1))
        (dest/"EXPERTS.CAT").write_bytes(cat)
        proc=subprocess.run([exe],cwd=dest,input="list\nuse "+str(n)+"\nquit\n",text=True,capture_output=True)
        if n>128:
            assert proc.returncode==1 and "Invalid EXPERTS.CAT" in proc.stdout
        else:
            assert proc.returncode==0 and f"active {n} " in proc.stdout
        print(n,"passed")
