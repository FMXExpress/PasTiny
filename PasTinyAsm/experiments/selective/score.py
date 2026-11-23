"""Score candidate traces from an instrumented FPC build of MAKECOM."""
import collections
import random
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'training'))
import gen_asm


def behavior(line):
    if line.startswith('PRINT '):
        return ('output', line[6:])
    if line.startswith('ECHO '):
        return ('output', line[5:] + '\n')
    if line in ('NL', 'NEWLINE'):
        return ('output', '\n')
    return ('command', line)


def run(directory, seed):
    rng = random.Random(seed)
    for pool in (None, gen_asm.V1HELD['text'], gen_asm.HELD['text']):
        pairs = []
        while len(pairs) < 300:
            q, target = gen_asm.make(rng, 'text', pool=pool)
            if ' and ' not in f' {q} ':
                pairs.append((q, target))
    commands = ''.join(f'new\n{q}\n' for q, _ in pairs) + 'quit\n'
    output = subprocess.run([directory / 'MAKECOM'], cwd=directory, input=commands,
                            text=True, capture_output=True, check=True).stdout
    for block, (_, target) in zip(output.split('> new\n')[1:], pairs, strict=True):
        match = re.search(r'^1 .*? -> (.+?)(?:\s+\((?:no model|second choice)\))?$', block, re.M)
        base = match[1] if match else None
        margin = re.search(r'^MARGIN ([-.0-9]+)$', block, re.M)
        candidates = dict.fromkeys(re.findall(r'^CAND (.*)$', block, re.M))
        # Count each independently generated path, including paths that agree.
        votes = collections.Counter(behavior(a) for a in re.findall(r'^CAND (.*)$', block, re.M))
        majority = next((a for a in candidates if votes[behavior(a)] * 2 > votes.total()
                         and votes[behavior(a)] >= 2), None)
        yield target, base, float(margin[1]) if margin else None, majority


def counts(rows, choose):
    right = wrong = refused = 0
    for target, base, margin, majority in rows:
        answer = choose(base, margin, majority)
        right += answer == target
        wrong += answer is not None and answer != target
        refused += answer is None
    return right, wrong, refused


if __name__ == '__main__':
    directory = Path(sys.argv[1]).resolve()
    tune = list(run(directory, 935))
    test = list(run(directory, 5))

    def abstain(threshold):
        return lambda base, gap, _: None if gap is not None and gap < threshold else base

    baseline = lambda base, gap, vote: base
    limit = counts(tune, baseline)[0] * .95
    choices = [(counts(tune, abstain(t)), t) for t in (0, .05, .1, .2, .4, .8, 1.6, 3.2)]
    result, threshold = min((c for c in choices if c[0][0] >= limit), key=lambda c: (c[0][1], -c[0][0]))
    print('Calibration', counts(tune, baseline), 'threshold', threshold, 'result', result)
    for label, policy in [('baseline', baseline), ('abstain', abstain(threshold)),
                          ('vote with fallback', lambda base, gap, vote: vote or base),
                          ('vote or abstain', lambda base, gap, vote: vote if gap is not None else base)]:
        print(label, counts(test, policy))
