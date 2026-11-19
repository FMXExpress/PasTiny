"""Package eight complete models in a new SD runtime directory."""
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
from package import build
root=Path("specialists/worddesk")
entries=json.loads(Path("specialists/manifest.json").read_text())
for edition in ("wordbench","pcbench"):
    entries.append(json.loads(Path("specialists",edition,"entry.json").read_text()))
entries.extend(json.loads((root/"entries.json").read_text()))
build(entries,Path("bin/SPEC8.EXE"),Path(sys.argv[1]),root/"runtime")
