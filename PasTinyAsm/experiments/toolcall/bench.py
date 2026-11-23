"""Build a sound/text selector corpus and score exported Tiny weights in Pascal."""
import argparse
import collections
import json
from pathlib import Path
import random
import re
import time
import subprocess
import sys
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'training'))
import gen_asm

LABELS = dict(zip('BEEP SIREN WAIT SCALE KEY REPEAT PRINT NUMBER NEWLINE'.split(), 'ABCDEFGHI'))
LABELS['NL'] = LABELS['NEWLINE']


def pairs(seed, count, held):
    rng = random.Random(seed)
    for family in ('sound', 'text'):
        for _ in range(count):
            q, answer = gen_asm.make(rng, family, held=held)
            yield family, q, LABELS[answer.split()[0]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--score', nargs=2, metavar=('CHECK', 'BIN'), type=Path)
    parser.add_argument('--editor', type=Path)
    args = parser.parse_args()
    if args.score is None and args.editor is None:
        for _, q, label in pairs(11, 4000, False):
            print(json.dumps(dict(question=q, answer=label)))
        return
    training = {q for _, q, _ in pairs(11, 4000, False)}
    rows = [row for row in pairs(935, 300, True) if row[1] not in training and ' and ' not in f' {row[1]} ']
    started = time.monotonic()
    if args.editor:
        exe = args.editor.resolve()
        result = subprocess.run([exe], cwd=exe.parent, check=True, text=True,
                                input=''.join(f'new\n{q}\n' for _, q, _ in rows)+'quit\n',
                                capture_output=True)
        answers = []
        for block in result.stdout.split('> new\n')[1:]:
            line = re.search(r'^1 .*? -> (\S+)', block, re.M)
            answers.append(LABELS.get(line[1], '?') if line else '?')
    else:
        exe, weights = args.score
        crc = zlib.crc32(weights.read_bytes())
        if crc >= 2**31:
            crc -= 2**32
        result = subprocess.run([exe.resolve(), weights.resolve(), str(crc)], check=True, text=True,
                                input=''.join(q+'\n' for _, q, _ in rows), capture_output=True)
        answers = result.stdout.splitlines()
    print(f'Batch elapsed {time.monotonic()-started:.2f}s')
    totals = collections.Counter()
    correct = collections.Counter()
    invalid = collections.Counter()
    for (family, _, expected), answer in zip(rows, answers, strict=True):
        totals[family] += 1
        correct[family] += expected == answer
        invalid[family] += answer not in LABELS.values()
    for family in totals:
        print(f'{family}: {correct[family]}/{totals[family]}, invalid outputs {invalid[family]}')


if __name__ == '__main__':
    main()
