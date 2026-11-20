"""Verify DOS package, catalog, weights and stored AUTO transcripts."""
import hashlib
import json
import zlib
from pathlib import Path
from zipfile import ZipFile

batch = Path(__file__).resolve().parent
project = batch.parents[1]
with ZipFile(project / "dist/SPEC80.ZIP") as package:
    catalog = package.read("EXPERTS.CAT")
    assert catalog[:5] == b"PEC1\x50" and len(catalog) == 5 + 80 * 68
    with ZipFile(project / "dist/SPEC70.ZIP") as previous:
        for name in previous.namelist():
            if name.endswith(".BIN"):
                assert package.read(name) == previous.read(name), name
    weights = {}
    for offset in range(5, len(catalog), 68):
        record = catalog[offset:offset + 68]
        name = record[2:2 + record[1]].decode("ascii")
        data = package.read(name)
        assert data == (batch.parent / "models" / name).read_bytes()
        assert zlib.crc32(data) == int.from_bytes(record[-4:], "little")
        weights[record[0]] = hashlib.sha256(data).digest()
    assert len(set(weights.values())) == len(weights) == 80
    assert package.read("EXPERT.EXE") == (project / "bin/SPEC80.EXE").read_bytes()

rows = [json.loads(line) for line in (batch / "answers.jsonl").read_text().splitlines()]
auto = {row["question"]: (row["active"], row["answer"]) for row in rows if row["mode"] == "auto"}
for name, fpu in (("ALL", "yes"), ("NOFPU", "no")):
    commands = (batch / f"{name}.IN").read_text().splitlines()
    assert commands[0] == "auto" and commands[-2:] == ["mem", "quit"]
    questions = commands[1:-2]
    if name == "ALL":
        assert questions == list(auto)
    lines = (batch / f"{name}.LOG").read_text().splitlines()
    assert f"FPU {fpu}" in lines
    active = None
    answers = []
    for i, line in enumerate(lines):
        if line.startswith("active "):
            active = int(line.split()[1])
        elif line.startswith("answer ms="):
            answers.append((active, lines[i - 1]))
        elif line.startswith("Choose an expert"):
            answers.append((0, None))
    assert answers == [auto[q] for q in questions], name
    print(f"{name}: {len(answers)} DOS answers match the host")
print("80 distinct packaged models match their individual files and catalog checksums")
