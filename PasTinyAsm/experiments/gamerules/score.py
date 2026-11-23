"""Compare shipped and fine-tuned weights on held-out rule translations."""
from pathlib import Path
import subprocess
import sys
import zlib

rows = [line.split('\t') for line in Path(__file__).with_name('held.tsv').read_text().splitlines()]
for name in sys.argv[2:]:
    model = Path(name)
    crc = zlib.crc32(model.read_bytes())
    if crc >= 2**31:
        crc -= 2**32
    output = subprocess.run([sys.argv[1], model, str(crc)], check=True, text=True,
                            input=''.join(question+'\n' for _, question, _ in rows),
                            capture_output=True).stdout.splitlines()
    correct = 0
    for (rule, _, expected), actual in zip(rows, output, strict=True):
        correct += actual == expected
        print(f'{rule}: {actual!r}  expected {expected!r}')
    print(f'{model.name}: {correct}/{len(rows)} exact', flush=True)
