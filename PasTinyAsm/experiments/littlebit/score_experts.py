"""Score exported expert weights directly, before editor routing or validation."""
import random
import subprocess
import sys
import zlib
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'training'))
import gen_asm
import gen_recipes
import gen_tasks

EXPERTS = ('screen', 'sound', 'text', 'tasks', 'recipes', 'slots')


def probes(expert, count=300):
    rng = random.Random(935)
    for _ in range(count):
        if expert in ('tasks', 'slots'):
            yield gen_tasks.make(rng, 'combo', slots=expert == 'slots')
        elif expert == 'recipes':
            yield gen_recipes.make(rng, 'combo')
        else:
            yield gen_asm.make(rng, expert, held=True)


def signed_crc(path):
    value = zlib.crc32(path.read_bytes())
    return value if value < 2**31 else value - 2**32


def score(executable, path, pairs):
    answers = subprocess.run([executable.resolve(), path.resolve(), str(signed_crc(path))],
                             input=''.join(q + '\n' for q, _ in pairs),
                             capture_output=True, text=True, check=True).stdout.splitlines()
    return sum(a == target for a, (_, target) in zip(answers, pairs, strict=True))


if __name__ == '__main__':
    dense, packed, directory = map(Path, sys.argv[1:4])
    for expert in EXPERTS:
        pairs = list(probes(expert))
        base = score(dense, root / (expert.upper() + '.BIN'), pairs)
        compressed = score(packed, directory / (expert + '.T16'), pairs)
        print(f'{expert}: shipped {base}/300, packed {compressed}/300', flush=True)
