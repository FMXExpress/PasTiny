"""Compare the same MAKECOM executable with and without its disk lookup table."""
import random
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'training'))
import gen_asm

exe = Path(sys.argv[1]).resolve()
rng = random.Random(935)
pairs = [gen_asm.make(rng, 'sound', held=True) for _ in range(300)]
commands = ''.join(f'new\n{q}\n' for q, _ in pairs) + 'quit\n'

def score(directory):
    output = subprocess.run([exe], cwd=directory, input=commands, text=True,
                            capture_output=True, check=True).stdout
    blocks = output.split('> new\n')[1:]
    result = []
    for block, (_, expected) in zip(blocks, pairs, strict=True):
        match = re.search(r'^1 .*? -> (.+?)(?:   \(.*\))?$', block, re.M)
        result.append(bool(match and match[1].strip() == expected))
    return result

with tempfile.TemporaryDirectory() as tmp:
    directory = Path(tmp)
    with ZipFile(root / 'dist/PASASM.ZIP') as package:
        package.extractall(directory)
    (directory / 'SOUND.MAP').unlink()
    neural = score(directory)
    shutil.copy(root / 'SOUND.MAP', directory)
    combined = score(directory)
    lost = sum(old and not new for old, new in zip(neural, combined))
    print(f'Neural {sum(neural)}/300; with lookup {sum(combined)}/300; lost {lost}')
    assert sum(combined) >= 292 and not lost
