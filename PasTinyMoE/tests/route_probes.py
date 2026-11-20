"""Score automatic routing on independent probe questions.

  fpc -Mtp -B -dSPEC100 -FEbuild tests/ROUTEPRB.PAS
  python3 tests/route_probes.py build/ROUTEPRB RUNTIME_DIR

RUNTIME_DIR holds EXPERTS.CAT (for example an extracted dist/SPEC100.ZIP).
tests/route_probes.tsv has three kinds of question, written before either
router was run on them:
  fresh  a covered fact in new wording, key term spelled correctly
         (one, about the word "separate", was added after the fallback first
         sent it to the Spelling Helper, whose terms are misspellings)
  typo   the same, with one typing slip in the key term
  none   outside every expert; the right outcome is "choose an expert" (0)
Each is routed twice: by the topic rules alone, and as EXPERT routes it (rules,
then the typo fallback).  Fails if the fallback result drops below the floors
recorded when it was added, or if it ever changes a route the rules had chosen.
"""
import csv
import subprocess
import sys
from pathlib import Path

FLOORS = {'fresh': 198, 'typo': 67, 'none': 19}      # correct outcomes, of 201, 100 and 20
MAX_WRONG_TYPO = 7                                   # typo probes sent to a wrong expert

exe, runtime = Path(sys.argv[1]).resolve(), Path(sys.argv[2])
rows = list(csv.DictReader(open(Path(__file__).with_name('route_probes.tsv'), newline=''), delimiter='\t'))
out = subprocess.run([str(exe)], input='\n'.join(r['question'] for r in rows) + '\n', text=True,
                     capture_output=True, cwd=runtime, check=True).stdout.split('\n')
routes = [tuple(map(int, line.split())) for line in out[:len(rows)]]
assert len(routes) == len(rows), 'router printed %d lines for %d probes' % (len(routes), len(rows))

print('%-6s %5s   %-28s %s' % ('kind', 'n', 'rules alone', 'with typo fallback'))
failed = []
for kind in ('fresh', 'typo', 'none'):
    part = [(int(r['expert']), a, b) for r, (a, b) in zip(rows, routes) if r['kind'] == kind]
    cells = []
    for col in (1, 2):
        right = sum(p[0] == p[col] for p in part)
        asked = sum(p[col] == 0 and p[0] != 0 for p in part)
        wrong = len(part) - right - asked
        cells.append('right %3d asked %2d wrong %2d' % (right, asked, wrong))
    print('%-6s %5d   %-28s %s' % (kind, len(part), cells[0], cells[1]))
    if right < FLOORS[kind]:
        failed.append('%s: %d correct, floor %d' % (kind, right, FLOORS[kind]))
    if kind == 'fresh' and wrong:
        failed.append('fresh: %d sent to a wrong expert' % wrong)
    if kind == 'typo' and wrong > MAX_WRONG_TYPO:
        failed.append('typo: %d sent to a wrong expert, limit %d' % (wrong, MAX_WRONG_TYPO))
changed = [(r['question'], a, b) for r, (a, b) in zip(rows, routes) if a != 0 and a != b]
if changed:
    failed.append('fallback changed a route the rules had chosen: %r' % (changed[:3],))
if failed:
    sys.exit('FAILED: ' + '; '.join(failed))
print('Routing probes passed.')
