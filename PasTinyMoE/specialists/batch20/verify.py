"""Compare shipped DOS weights and recorded Turbo Pascal answers with the host run."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

batch = Path(__file__).resolve().parent
project = batch.parents[1]
with ZipFile(project / "dist/SPEC20.ZIP") as package:
    models = [name for name in package.namelist() if name.endswith(".BIN")]
    assert len(models) == 20
    assert len({hashlib.sha256(package.read(name)).digest() for name in models}) == 20
    for name in models:
        assert package.read(name) == (batch.parent / "models" / name).read_bytes()
    assert package.read("EXPERT.EXE") == (project / "bin/SPEC20.EXE").read_bytes()

rows = [json.loads(line) for line in (batch / "answers.jsonl").read_text().splitlines()]
auto = [row for row in rows if row["mode"] == "auto"]
log = (batch / "ALL.LOG").read_text().splitlines()
assert "FPU yes" in log
active = None
answers = []
for index, line in enumerate(log):
    if line.startswith("active "):
        active = int(line.split()[1])
    if line.startswith("answer ms="):
        answers.append((active, log[index - 1]))
assert len(answers) == len(auto) == 148
assert answers == [(row["active"], row["answer"]) for row in auto]
smoke = (batch / "NOFPU.LOG").read_text().splitlines()
assert "FPU no" in smoke and "slow" in smoke and "Texas" in smoke
print("Verified 20 packaged weights, DOS executable, 148 DOS answers and no-FPU smoke run.")
