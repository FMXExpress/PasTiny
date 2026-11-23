"""Score one model with the Pascal harness and a fixed held-out SOUND sample."""
import random
import subprocess
import sys
from pathlib import Path
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'training'))
import gen_asm

exe, model = map(Path, sys.argv[1:3])
rng = random.Random(935)
pairs = [gen_asm.make(rng, 'sound', held=True) for _ in range(300)]
crc = zlib.crc32(model.read_bytes())
if crc >= 2**31:
    crc -= 2**32
result = subprocess.run([exe, model, str(crc)], check=True, text=True,
                        input=''.join(q+'\n' for q, _ in pairs), capture_output=True)
answers = result.stdout.splitlines()
score = sum(actual == target for actual, (_, target) in zip(answers, pairs, strict=True))
print(f'{model.name}: {score}/300, {model.stat().st_size} bytes')
if len(sys.argv) > 3:
    Path(sys.argv[3]).write_text(result.stdout)
