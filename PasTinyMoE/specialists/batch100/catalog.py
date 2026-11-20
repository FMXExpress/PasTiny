"""Generate the SPEC100 routing index and package its 100 trained DOS experts."""
import argparse
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
project = root.parents[1]
sys.path.insert(0, str(project))
sys.path.insert(0, str(project / "tools"))
from package import build

ids = range(27, 37)


def index():
    previous = (project / "TOPIC90.INC").read_text()
    terms = {term: int(ident) for term, ident in re.findall(r"Term:'([^']+)'; Id:(\d+)", previous)}
    for ident in ids:
        metadata = json.loads((root / f"{ident:03}" / "meta.json").read_text())
        if metadata["id"] != ident:
            raise ValueError(f"Unexpected ID in {ident:03}/meta.json")
        for term in metadata["keywords"]:
            if not re.fullmatch("[a-z][a-z0-9]{0,19}", term) or terms.setdefault(term, ident) != ident:
                raise ValueError(f"Invalid or ambiguous topic {term!r} for expert {ident}")
    rows = ",\n".join(f" (Term:'{term}'; Id:{ident})" for term, ident in sorted(terms.items()))
    (project / "TOPIC100.INC").write_text(f"const Topics:array[1..{len(terms)}] of TopicEntry=(\n{rows});\n")


def entries():
    # Preserve the ordering of the released SPEC90 catalog.
    from specialists.batch90.catalog import entries as previous_entries

    return previous_entries() + json.loads((root / "entries.json").read_text())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", action="store_true")
    parser.add_argument("dest", nargs="?", type=Path)
    args = parser.parse_args()
    if args.index:
        index()
    if args.dest:
        build(entries(), project / "bin/SPEC100.EXE", args.dest, root / "runtime", project / "TINY.BIN")
