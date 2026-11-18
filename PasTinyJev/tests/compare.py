"""Compare JEV transcripts number by number.

  python3 tests/compare.py EXPECTED.LOG ACTUAL.LOG [...]

Lines must match word for word, apart from timings (ms=), memory reports and
numbers, which may differ by 0.0006 (the last printed digit, rounded twice).
"""
import sys


def rows(path):
    out = []
    for line in open(path, errors='replace').read().replace('\r', '').splitlines():
        if line.startswith(('heap=', 'PasTinyJev', 'answer ms=')):
            continue
        out.append([f for f in line.split(' ') if not f.startswith('ms=')])
    return out


want = rows(sys.argv[1])
for path in sys.argv[2:]:
    got, worst = rows(path), 0.0
    assert len(got) == len(want), (path, len(got), len(want))
    for a, b in zip(want, got):
        assert len(a) == len(b), (path, a, b)
        for x, y in zip(a, b):
            if x == y:
                continue
            kx, _, vx = x.partition('=')
            ky, _, vy = y.partition('=')
            assert kx == ky, (path, a, b)
            gap = abs(float(vx) - float(vy))
            worst = max(worst, gap)
            assert gap <= 0.0006, (path, a, b)
    print('%s: %d lines match, largest number gap %.4f' % (path, len(got), worst))
