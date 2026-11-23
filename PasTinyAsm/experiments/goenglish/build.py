"""Select Go rule blocks from English and prepare an interactive MAKECOM replay."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
# Slice the tested Go source at the six rule boundaries. Blocks may contain
# open control structures, so the manifest's order is a compiler dependency.
RANGES = {'A': (0, 5), 'B': (5, 15), 'C': (15, 75),
          'D': (75, 81), 'E': (81, 137), 'F': (137, 158)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('check', type=Path)
    parser.add_argument('model', type=Path)
    parser.add_argument('specification', type=Path)
    parser.add_argument('dos_directory', type=Path)
    parser.add_argument('--confirm', help='explicit human-approved block IDs in request order')
    args = parser.parse_args()
    requests = args.specification.read_text().lower().splitlines()
    if len(requests) != len(RANGES) or any(not 0 < len(q) <= 72 for q in requests):
        parser.error('provide six English requests of 1–72 characters each')
    crc = zlib.crc32(args.model.read_bytes())
    if crc >= 2**31:
        crc -= 2**32
    selections = subprocess.run([args.check.resolve(), args.model.resolve(), str(crc)], check=True,
                                text=True, capture_output=True,
                                input=''.join(q+'\n' for q in requests)).stdout.splitlines()
    if len(selections) != len(requests):
        parser.error('unexpected number of model responses')
    for request, code in zip(requests, selections):
        print(f'{code!r}  {request}', flush=True)
    approved = list(args.confirm) if args.confirm is not None else selections
    if approved != list(RANGES):
        parser.error('rule blocks are missing or out of dependency order. Review the IDs before compiling')
    if args.confirm is not None:
        print('Reviewer corrections:', sum(a != b for a,b in zip(selections,approved)), flush=True)
    library = (ROOT / 'examples/GOGAME.SRC').read_text().splitlines()
    if len(library) != 158:
        parser.error('the source library no longer matches the block manifest')
    with tempfile.TemporaryDirectory() as temp:
        scratch = Path(temp)
        (scratch/'examples').mkdir()
        lines = [line for code in approved for line in library[slice(*RANGES[code])]]
        (scratch/'examples/GOGAME.SRC').write_text('\n'.join(lines)+'\n')
        subprocess.run([sys.executable, ROOT/'experiments/editor/replay.py',
                        scratch, args.dos_directory, 'GOGAME'], check=True)


if __name__ == '__main__':
    main()
