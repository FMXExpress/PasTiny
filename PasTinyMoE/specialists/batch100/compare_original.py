"""Compare original Tiny and SPEC100 AUTO, writing paired results and a scorecard."""
import argparse
import json
from pathlib import Path
import sys

batch = Path(__file__).resolve().parent
project = batch.parents[1]
sys.path.insert(0, str(project / "tools"))
from evaluate import evaluate
from catalog import entries, ids


def load_probes():
    previous = batch.parent / "batch90/comparison.jsonl"
    probes = []
    for line in previous.read_text().splitlines():
        row = json.loads(line)
        probes.append((row["suite"], dict(question=row["question"], answer=row["target"], expert=row["intended"])))
    for ident in ids:
        path = batch / f"{ident:03}/heldout.jsonl"
        for line in path.read_text().splitlines():
            probes.append(("specialists", dict(json.loads(line), expert=ident)))
    return probes


def summary(label, rows):
    n = len(rows)
    original = sum(r["original"] == r["target"] for r in rows)
    current = sum(r["specialist"] == r["target"] for r in rows)
    asks = sum(r["routed"] == 0 for r in rows)
    return f"| {label} | {original}/{n} | {current}/{n} | {asks} |"


def scorecard(rows):
    legacy = [r for r in rows if r["suite"] == "original60"]
    experts = [r for r in rows if r["suite"] == "specialists"]
    lines = [
        "# SPEC100 paired evaluation",
        "",
        "The native Pascal runtime answered each question twice, first with the original Tiny weights pinned and then with SPEC100 automatic routing. Original questions use the C transcript as their reference. Specialist questions test alternate phrasings of covered material and use each expert’s published reference answers. Exact match includes punctuation. A request to select an expert counts as a miss.",
        "",
        "| Prompt set | Original exact | SPEC100 AUTO exact | Asked for selection |",
        "| --- | ---: | ---: | ---: |",
        summary("Original 60 questions", legacy),
        summary("Previous 90 experts", [r for r in experts if r["intended"] not in ids]),
        summary("Latest ten experts", [r for r in experts if r["intended"] in ids]),
        summary("All 100 experts", experts),
        "",
        "## Per-expert results",
        "",
        "Each example pairs a held-out question with its reference answer. Routing and exact answers are scored independently. Each prompt has equal weight in the totals.",
        "",
        "| ID | Expert | Routed correctly | Exact | Example question → reference |",
        "| ---: | --- | ---: | ---: | --- |",
    ]
    for entry in sorted(entries(), key=lambda e: e["id"]):
        ident = entry["id"]
        group = [r for r in experts if r["intended"] == ident]
        n = len(group)
        routed = sum(r["routed"] == ident for r in group)
        exact = sum(r["specialist"] == r["target"] for r in group)
        example = (group[0]["question"] + " → " + group[0]["target"]).replace("|", r"\|")
        lines.append(f"| {ident:03} | {entry['title']} | {routed}/{n} | {exact}/{n} | {example} |")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("exe", "runtime", "general"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    probes = load_probes()
    inputs = [probe for _, probe in probes]
    exe = args.exe.resolve()
    original = evaluate(exe, args.general.resolve(), inputs, "baseline")
    current = evaluate(exe, args.runtime.resolve(), inputs, "auto")
    records = [
        dict(suite=suite, question=probe["question"], target=probe["answer"],
             intended=probe["expert"], original=old["answer"], routed=new["active"],
             specialist=new["answer"])
        for (suite, probe), old, new in zip(probes, original, current, strict=True)
    ]
    report = scorecard(records)
    (batch / "comparison.jsonl").write_text("".join(json.dumps(r) + "\n" for r in records))
    (batch / "scorecard.md").write_text(report)
    print("\n".join(report.splitlines()[6:10]))
