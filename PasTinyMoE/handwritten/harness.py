"""Run hand-written models in a stock PasTinyMoE runtime, for the tests."""
import hashlib
import subprocess
import sys
from pathlib import Path

project = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project / 'tools'))
from package import build


def rebuilt_matches(folder, tmp):
    """Run folder/build.py into tmp and require every committed .BIN to match."""
    out = Path(tmp) / ('fresh_' + folder.name)
    out.mkdir()
    subprocess.run([sys.executable, str(folder / 'build.py'), str(out)], check=True, capture_output=True)
    names = sorted(p.name for p in out.glob('*.BIN'))
    assert names, 'build.py wrote no model'
    for name in names:
        assert (out / name).read_bytes() == (folder / name).read_bytes(), name + ' does not match build.py'
    return names


class Runtime:
    """The general model as expert 1, then each (file, keyword) as the next expert."""

    def __init__(self, exe, tmp, models):
        self.exe = Path(exe).resolve()
        general = project / 'TINY.BIN'
        entries = [dict(id=1, name='GENERAL.BIN', title='TINY 2.1 general (trained)', keyword='', source=str(general),
                        sha256=hashlib.sha256(general.read_bytes()).hexdigest())]
        for i, (path, keyword) in enumerate(models):
            entries.append(dict(id=i + 2, name=Path(path).name, title=Path(path).stem.title() + ' (hand-written)',
                                keyword=keyword, source=str(path),
                                sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest()))
        self.dir = Path(tmp) / 'rt'
        Path(tmp).mkdir(parents=True, exist_ok=True)
        build(entries, self.exe, self.dir)

    def ask(self, lines):
        """Answers to the lines that are questions (USE and AUTO lines pass through)."""
        out = subprocess.run([str(self.exe)], input='\n'.join(lines) + '\n', text=True, capture_output=True,
                             cwd=self.dir, check=True).stdout.splitlines()
        return [out[i - 1] for i, line in enumerate(out) if line.startswith('answer ms=')]
