"""Verify a PasTinyMoE (not legacy TINY) corpus transcript."""
from pathlib import Path
import sys

reference=Path(__file__).with_name("gold_c.txt").read_text().splitlines()
gold=[line[4:] for line in reference if line.startswith(">   ")]
assert len(gold)==60
for path in map(Path,sys.argv[1:]):
    lines=path.read_text().splitlines()
    result=[lines[i-1] for i,line in enumerate(lines) if line.startswith("answer ms=")]
    assert result==gold,(path,len(result))
    print(f"{path}: 60/60 exact")
