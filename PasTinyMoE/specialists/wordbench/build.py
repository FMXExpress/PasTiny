"""Run from PasTinyMoE, supplying a fresh runtime directory."""
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from package import build
root=Path("specialists/wordbench")
entries=json.loads(Path("specialists/manifest.json").read_text())
entries.append(json.loads((root/"entry.json").read_text()))
build(entries,Path("bin/SPEC4.EXE"),Path(sys.argv[1]),root/"runtime")
