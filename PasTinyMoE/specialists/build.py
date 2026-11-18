"""Build the three-specialist edition from its pinned manifest."""
import json
import sys
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from package import build

if __name__=="__main__":
    build(json.loads(Path("specialists/manifest.json").read_text()), Path("bin/SPEC3.EXE"),
          Path(sys.argv[1]), extras=Path("specialists/runtime"))
