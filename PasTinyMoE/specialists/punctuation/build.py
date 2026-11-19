"""Package the nine complete specialist exports into a fresh SD directory."""
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from package import build
root=Path("specialists/punctuation")
entries=json.loads(Path("specialists/manifest.json").read_text())
for edition in ("wordbench","pcbench"):
    entries.append(json.loads(Path("specialists",edition,"entry.json").read_text()))
entries.extend(json.loads(Path("specialists/worddesk/entries.json").read_text()))
entries.append(json.loads((root/"entry.json").read_text()))
build(entries,Path("bin/SPEC9.EXE"),Path(sys.argv[1]),root/"runtime")
