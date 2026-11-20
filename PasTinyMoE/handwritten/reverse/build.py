"""Write REVERSE.BIN by hand: a TNY2 network that spells a word backwards.

  python3 build.py [REVERSE.BIN]

No training and no data.  Every weight comes from the construction below, in
the pinned TINY 2.1 shape (96 wide, 4 layers, 4 heads, 256 hidden, 381,808
bytes), so the stock DOS programs load it.  Needs NumPy only.

The question is read letter by letter; the answer is the last word of the
question, reversed.  With n = position of the end-of-question token and
p = the current position:

  layer 1 attention  every answer position looks at the end-of-question token
                     and fetches a table entry: the phase of 2n-1
  layer 1 MLP        subtracts its own position, giving the phase of 2n-1-p.
                     Angle subtraction needs products; they are built from
                     squares, and each square from 14 ReLU pieces
  layer 2 attention  looks at the question position whose phase matches,
                     2n-1-p, and copies that letter to the output
  layer 2 MLP        emits the end token when the target position is -1; a
                     copied space also ends the answer, so only the last word
                     is reversed
  layers 3 and 4     all zero: they pass everything through

Positions are stored as phases (cosine and sine at four frequencies) because
the runtime keeps attention keys as 8-bit numbers: phases stay within -1..1
and survive that, where a position counter would not.
"""
import math
import struct
import sys
from pathlib import Path

import numpy as np

D, H, HID, L, VOCAB, CTX = 96, 4, 256, 4, 97, 128
HD = D // H
FREQ = [2, 7, 46, 54]      # multiples of 2*pi/128; the best of 20,000 random sets of four
F = len(FREQ)
W = [2 * math.pi * f / 128 for f in FREQ]
lags = np.arange(1, 128)
GAP = F - max(sum(np.cos(2 * np.pi * f * lags / 128) for f in FREQ))   # worst-case margin, 1.745


def phase(x):
    out = []
    for w in W:
        out += [math.cos(w * x), math.sin(w * x)]
    return out


# ---- residual stream layout
CONST, NL, SP = 0, 1, 2
PPOS = list(range(3, 3 + 2 * F))                 # phase of the position
DBL = list(range(3 + 2 * F, 3 + 4 * F))          # table: phase of 2p-1
APH = list(range(3 + 4 * F, 3 + 6 * F))          # fetched: phase of 2n-1
QPH = list(range(3 + 6 * F, 3 + 8 * F))          # computed: phase of 2n-1-p
NTOK = 46
TOK = list(range(3 + 8 * F, 3 + 8 * F + NTOK))   # which letter


def zeros(*shape):
    return np.zeros(shape, np.float32)


emb, pos = zeros(VOCAB, D), zeros(CTX, D)
blocks = [dict(g1=zeros(D), q=zeros(D, D), k=zeros(D, D), v=zeros(D, D), o=zeros(D, D),
               g2=zeros(D), f1=zeros(HID, D), f2=zeros(D, HID)) for _ in range(L)]
gf = zeros(D)

# ---- letters: 94 near-orthogonal +-1 codes; space and the end token have their own dimension
rng = np.random.RandomState(1)
codes = []
while len(codes) < 94:
    c = rng.choice([-1.0, 1.0], NTOK)
    if all(abs(c @ o) / NTOK <= 0.31 for o in codes):
        codes.append(c)
emb[1, NL] = 1.0
emb[2, SP] = 1.0
for t in range(3, VOCAB):
    emb[t, TOK] = codes[t - 3] / math.sqrt(NTOK)

# ---- positions
for p in range(CTX):
    pos[p, CONST] = 1.0
    pos[p, PPOS] = phase(p)
    pos[p, DBL] = phase(2 * p - 1)
pos[0, NL] = 0.5               # before the end token arrives, look at position 0 instead


def gain(energy):              # makes the normalised vector equal the residual itself
    return math.sqrt(energy / D)


# ---- layer 1 attention: fetch phase(2n-1) from the end-of-question token
b = blocks[0]
b['g1'][:] = gain(2 + 2 * F)
b['q'][0, CONST] = 150.0
b['k'][0, NL] = 1.0
for i in range(2 * F):
    b['v'][i, DBL[i]] = 1.0
    b['o'][APH[i], i] = 1.0

# ---- layer 1 MLP: phase(A - B) from squares, each square from ReLU pieces
b['g2'][:] = gain(2 + 3 * F)
KNOTS, STEP = 7, 2.0 / 7
unit = 0


def square(terms, out_dim):
    """adds 0.5 * (sum of terms)^2 to out_dim; terms are (dimension, sign)"""
    global unit
    for side in (1.0, -1.0):
        for k in range(KNOTS):
            for d, s in terms:
                b['f1'][unit, d] = side * s
            b['f1'][unit, CONST] = -k * STEP
            b['f2'][out_dim, unit] = 0.5 * (STEP if k == 0 else 2 * STEP)
            unit += 1


for f in range(F):
    cA, sA, cB, sB = APH[2 * f], APH[2 * f + 1], PPOS[2 * f], PPOS[2 * f + 1]
    square([(cA, 1), (cB, 1)], QPH[2 * f])          # cos(A-B) = ((cA+cB)^2 + (sA+sB)^2)/2 - 1
    square([(sA, 1), (sB, 1)], QPH[2 * f])
    square([(sA, 1), (cB, 1)], QPH[2 * f + 1])      # sin(A-B) = ((sA+cB)^2 + (cA-sB)^2)/2 - 1
    square([(cA, 1), (sB, -1)], QPH[2 * f + 1])
b['f1'][unit, CONST] = 1.0                          # the constant 1
b['f2'][QPH, unit] = -(1.0 + STEP * STEP / 6)       # the -1, and the mean error of the pieces
unit += 1
assert unit <= HID

# ---- layer 2 attention: two heads with the same aim copy the letter at 2n-1-p
b = blocks[1]
b['g1'][:] = gain(2 + 4 * F)
ALPHA, KAPPA, BETA = 8.0, 16.0, 70.0 / GAP
for h in (0, 1):
    for i in range(2 * F):
        b['q'][h * HD + i, QPH[i]] = BETA
        b['k'][h * HD + i, PPOS[i]] = 1.0
for i in range(NTOK):                               # 24 letter dimensions in head 1, 22 in head 2
    b['v'][i, TOK[i]] = 1.0
    b['o'][TOK[i], i] = ALPHA
b['v'][NTOK, SP] = 0.15                             # a copied space ...
b['o'][NL, NTOK] = KAPPA / 0.15                     # ... becomes the end token

# ---- layer 2 MLP: stop when the target position is -1
b['g2'][:] = 1.0
b['f1'][0, QPH] = phase(-1)
b['f1'][0, CONST] = -(F - GAP / 2)
b['f2'][NL, 0] = 160.0 / GAP

for l in (2, 3):
    blocks[l]['g1'][:] = 1.0
    blocks[l]['g2'][:] = 1.0
gf[:] = 3.0


def export(path):
    """TNY2: 'TNY2', D, L, H, HID; each table row is a float32 scale and int8 values."""
    with open(path, 'wb') as f:
        f.write(b'TNY2' + struct.pack('<4h', D, L, H, HID))

        def table(w):
            for row in w:
                s = max(float(np.abs(row).max()) / 127.0, 1e-8)
                f.write(struct.pack('<f', s))
                f.write(np.clip(np.round(row / s), -127, 127).astype(np.int8).tobytes())

        table(emb)
        table(pos)
        for b in blocks:
            f.write(b['g1'].astype('<f4').tobytes())
            for n in 'qkvo':
                table(b[n])
            f.write(b['g2'].astype('<f4').tobytes())
            table(b['f1'])
            table(b['f2'])
        f.write(gf.astype('<f4').tobytes())
    return Path(path).stat().st_size


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).with_name('REVERSE.BIN'))
    nonzero = int(sum((a != 0).sum() for a in [emb, pos, gf] + [v for b in blocks for v in b.values()]))
    total = int(sum(a.size for a in [emb, pos, gf] + [v for b in blocks for v in b.values()]))
    print('wrote %s, %d bytes; %d of %d weights are non-zero; %d hidden units and %d dimensions used' % (
        out, export(out), nonzero, total, unit, TOK[-1] + 1))
