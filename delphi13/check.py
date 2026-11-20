"""Check a compiled modern console program against the original C answers."""
import argparse
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=Path)
exe = parser.parse_args().executable.resolve()
repo = Path(__file__).resolve().parents[1]
questions = (repo / "tests/questions.txt").read_bytes()
expected = (repo / "tests/gold_c.txt").read_text().splitlines()
assert len([line for line in expected if line.startswith(">   ")]) == 60
model = "/MODEL=" + str(repo / "TINY.BIN")

with TemporaryDirectory() as tmp:
    work = Path(tmp)
    for engine in ([], ["/FLOAT"]):
        answers = subprocess.check_output(
            [exe, "0", model, *engine], input=questions, cwd=work
        ).decode("ascii").splitlines()
        assert [line for line in answers if not line.startswith("   [")] == expected
        bench = subprocess.check_output([exe, model, "/BENCH", *engine], cwd=work, text=True)
        assert re.search(r"^total: 189 tokens ", bench, re.MULTILINE)
        print(f"{'float' if engine else 'integer'}: 60/60 reference answers, 189 benchmark tokens")

    output = work / "answers.txt"
    subprocess.run([exe, "0", model, "/IN=" + str(repo / "tests/questions.txt"),
                    "/OUT=" + str(output)], cwd=work, check=True)
    assert [line for line in output.read_text().splitlines() if not line.startswith("   [")] == expected
    bad = work / "bad.bin"
    bad.write_bytes(b"TNY2")
    failed = subprocess.run([exe, "/MODEL=" + str(bad)], cwd=work, capture_output=True)
    assert failed.returncode != 0 and b"damaged" in failed.stderr
