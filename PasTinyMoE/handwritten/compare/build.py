"""Write number-comparison networks by hand: BIGGER.BIN and SMALLER.BIN.

  python3 build.py [OUTPUT_DIRECTORY]

Each is a TNY2 network in the pinned TINY 2.1 shape with no training and no
data.  The question holds two whole numbers, A then B; the answer is "yes" or
"no":

  BIGGER    "is 842 bigger than 837"   -> yes      (is A bigger than B)
  SMALLER   "is 842 smaller than 837"  -> no       (is A smaller than B)

Equal numbers give "no" from both.  The wording around the numbers does not
matter.  Numbers are compared digit by digit, so size is not limited by
arithmetic precision.

Program:

  layer 1 attention  two heads at every position: the latest non-digit, which
                     gives the start of the number a digit belongs to, and the
                     earliest digit, which gives the start of A
  layer 1 MLP        each digit's place in its number, counted from its start
  layer 2 attention  three heads: each digit of B looks at the digit of A in
                     the same place; and, used at the end of the question, the
                     last digit of B and the last digit of A, whose places give
                     the two lengths
  layer 2 MLP        on each digit of B, whether A's digit is larger or smaller;
                     at the end of the question, the difference in length
  layer 3 attention  the earliest place where the digits differ
  layer 3 MLP        clips that result and the length difference to -1, 0 or +1
  layer 4 MLP        a longer number wins; with equal lengths the first
                     differing digit decides.  It also spells the answer:
                     after y comes e, then s; after n comes o.

Robustness notes, each learned from a failure in the 8-bit runtime:

  - Picking "the latest digit" needs a score that rises with position on
    digits and is zero elsewhere.  A large constant times an "is a digit" flag
    fails once later layers have written uneven amounts into the residual, so
    an MLP first makes position values that are already zero off the digits.
  - Position is ranked with two counters, a coarse one (blocks of eight) and a
    fine one (within the block).  Each has few, widely spaced values, so 8-bit
    rounding cannot put two positions on the same step, and the constants that
    multiply them stay small enough that a 0.1% wobble in size does not matter.
  - Where a key must match "same start as the first number", a constant entry
    larger than everything else fixes the 8-bit scale, so equal starts round to
    exactly equal keys.

Limits: a number may not be the very first thing in the question, the question
may be at most 72 characters, and numbers are plain digits without signs,
points, separators or leading zeros.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tny2 import CTX, F, GAP, HD, Net, gain, phase

# ---- residual stream layout
CONST, NL, LH, LO, DIG, NDG, DVAL, COMP, PAD = 0, 1, 2, 3, 4, 5, 6, 7, 8
PPOS = list(range(9, 17))        # phase of the position
VAL = list(range(17, 25))        # table: phase of p+1
S = list(range(25, 33))          # start of the number this position is in
SA = list(range(33, 41))         # start of the first number
IDX = list(range(41, 49))        # place within the number (as the phase of start - position)
LB = list(range(49, 57))         # place of the last digit of B
LA = list(range(57, 65))         # place of the last digit of A
DL = list(range(65, 73))         # length of B minus length of A
Y, E, SS, N, O = 73, 74, 75, 76, 77
DH, DLO = 78, 79                 # the two position counters, on digits only
ADIG, EH, EL, SGH, RES, RS, LS = 80, 81, 82, 83, 84, 85, 86
UNIT = 3.0 / 127                 # one counter step in the position table: exactly three 8-bit levels
KW = 5.0                         # counters are multiplied by this in keys (coarse reaches 0.94, fine 0.83)
NATS = 14.0 * math.sqrt(HD)      # one step of preference
FINE = NATS / (UNIT * KW)        # multiplies the fine counter (position within a block of eight)
COARSE = 8 * FINE                # multiplies the coarse counter (the block); one block outweighs seven fine steps
FLAG = (9 * COARSE + 7 * FINE) * UNIT * KW + 300     # a wanted kind beats any position preference


def token(c):
    return ord(c) - 30


def build(want_bigger):
    net = Net()
    # ---- tokens: every token has the same energy (2), so phases copied between positions keep their size
    spelled = {'y': Y, 'e': E, 's': SS, 'n': N, 'o': O}
    for c in map(chr, range(32, 127)):
        t = token(c)
        if c.isdigit():
            v = int(c) / 9.0
            net.emb[t, DIG], net.emb[t, DVAL], net.emb[t, COMP] = 1.0, v, math.sqrt(1.0 - v * v)
        else:
            net.emb[t, NDG] = 1.0
            net.emb[t, spelled.get(c, PAD)] = 1.0
    net.emb[1, NL], net.emb[1, PAD] = 1.0, 1.0
    for p in range(CTX):
        net.pos[p, CONST] = 1.0
        net.pos[p, LH] = UNIT * min(p // 8, 9)
        net.pos[p, LO] = UNIT * (p % 8)
        net.pos[p, PPOS] = phase(p)
        net.pos[p, VAL] = phase(p + 1)
    base = 2 + 1 + 0.01 + 2 * F

    def prefer(b, row, later, hi, lo):
        """rows row, row+1 of a head: prefer later (or earlier) positions by the two counters"""
        sign = 1.0 if later else -1.0
        b['q'][row, CONST], b['k'][row, hi] = sign * COARSE, KW
        b['q'][row + 1, CONST], b['k'][row + 1, lo] = sign * FINE, KW

    # ---- layer 1 attention
    b = net.blocks[0]
    b['g1'][:] = gain(base)
    b['q'][0, CONST], b['k'][0, NDG] = FLAG, 1.0           # head 1: the latest non-digit ...
    prefer(b, 1, True, LH, LO)
    b['q'][HD, CONST], b['k'][HD, DIG] = FLAG, 1.0         # head 2: the earliest digit ...
    prefer(b, HD + 1, False, LH, LO)
    for i in range(2 * F):
        b['v'][i, VAL[i]] = 1.0                            # ... the position after it starts this number
        b['o'][S[i], i] = 1.0
        b['v'][HD + i, PPOS[i]] = 1.0                      # ... its position starts the first number
        b['o'][SA[i], HD + i] = 1.0
    # ---- layer 1 MLP: place in the number, and the two counters on digits only
    b['g2'][:] = gain(base + 2 * F)
    net.angle(0, S, PPOS, IDX, CONST, -1)
    for src, dst in ((LH, DH), (LO, DLO)):
        u = net.units[0]
        b['f1'][u, src], b['f1'][u, DIG], b['f1'][u, CONST] = 1.0, 1.0, -1.0   # the counter on a digit, 0 elsewhere
        b['f2'][dst, u] = 1.0
        net.units[0] += 1

    # ---- layer 2 attention
    b = net.blocks[1]
    b['g1'][:] = gain(base + 3 * F)
    BETA = NATS / GAP
    MATCH = FLAG / GAP
    for i in range(2 * F):
        b['q'][i, IDX[i]], b['k'][i, IDX[i]] = BETA, 1.0                 # head 1: same place ...
        b['q'][2 * F + i, SA[i]], b['k'][2 * F + i, S[i]] = BETA, 1.0     # ... in the first number
        b['v'][HD + i, IDX[i]] = 1.0                                     # head 2: the place of the latest digit
        b['o'][LB[i], HD + i] = 1.0
        b['q'][2 * HD + i, SA[i]], b['k'][2 * HD + i, S[i]] = MATCH, 1.0  # head 3: ... of the first number
        b['v'][2 * HD + i, IDX[i]] = 1.0
        b['o'][LA[i], 2 * HD + i] = 1.0
    b['v'][0, DVAL] = 1.0
    b['o'][ADIG, 0] = 0.3                                  # kept small so digits stay the same size
    prefer(b, HD, True, DH, DLO)
    prefer(b, 2 * HD + 2 * F, True, DH, DLO)
    b['k'][3 * HD, CONST] = 1.25                           # fixes the 8-bit scale of every key
    # ---- layer 2 MLP: on a digit, how early it is if A's digit is larger (or smaller), else 0
    b['g2'][:] = gain(base + 3 * F)
    K, GATE = 18.0, 40.0
    f1, f2 = b['f1'], b['f2']
    for sign in (1.0, -1.0):
        for counter, out in ((LH, EH), (LO, EL)):
            for upper in (False, True):                    # relu(x) - relu(x - (1 - counter)) clips x to 0 .. 1-counter
                u = net.units[1]
                f1[u, ADIG], f1[u, DVAL] = sign * K / 0.3, -sign * K
                f1[u, DIG], f1[u, CONST] = GATE, -GATE - 0.5
                if upper:
                    f1[u, CONST] -= 1.0
                    f1[u, counter] = KW
                f2[out, u] = -1.0 if upper else 1.0
                if out == EH:
                    f2[SGH, u] = sign * (-1.0 if upper else 1.0)
                net.units[1] += 1
    net.angle(1, LA, LB, DL, CONST, -1)                    # at the end: length of B minus length of A

    # ---- layer 3 attention: the earliest place where the digits differ
    b = net.blocks[2]
    b['g1'][:] = gain(base + 3 * F + 0.5)
    b['q'][0, CONST], b['k'][0, EH] = COARSE, 1.0
    b['q'][1, CONST], b['k'][1, EL] = FINE, 1.0
    b['v'][0, SGH] = 1.0
    b['o'][RES, 0] = 1.0
    # ---- layer 3 MLP: clip that sign, and the sign of the length difference, to -1, 0 or +1
    b['g2'][:] = gain(base + 6 * F)
    f1, f2 = b['f1'], b['f2']
    for u, (sign, step) in enumerate(((1.0, 0.0), (1.0, 1.0), (-1.0, 0.0), (-1.0, 1.0))):
        f1[u, RES], f1[u, CONST] = sign * 30.0, -step
        f2[RS, u] = sign * (1.0 if step == 0 else -1.0)
        # "A is longer" = -(3 * sine at the lowest frequency + sine at the next); 0.3 clears the
        # error of the ReLU pieces (about 0.1) and stays under the smallest real difference (0.5)
        v = u + 4
        f1[v, DL[1]], f1[v, DL[3]], f1[v, CONST] = -sign * 30.0, -sign * 10.0, -3.0 - step
        f2[LS, v] = sign * (1.0 if step == 0 else -1.0)

    # ---- layer 4 MLP: decide at the end of the question, and spell the answer
    b = net.blocks[3]
    b['g2'][:] = gain(base + 6 * F + 1)
    f1, f2 = b['f1'], b['f2']
    M, K4, GATE4, WRITE = 3.0, 10.0, 60.0, 3.0
    direction = 1.0 if want_bigger else -1.0
    for u, (out, s) in enumerate(((Y, 1.0), (N, -1.0))):
        # U = first-difference sign + M * length sign; yes when direction * U > 0.5
        f1[u, RS] = s * direction * K4
        f1[u, LS] = s * direction * K4 * M
        f1[u, CONST] = -s * 0.5 * K4 - GATE4
        f1[u, NL] = GATE4                                  # only at the end of the question
        f2[out, u] = WRITE
    for u, (seen, nxt) in enumerate(((Y, E), (E, SS), (SS, NL), (N, O), (O, NL)), start=2):
        f1[u, seen] = 1.0
        f2[nxt, u] = 16.0
    return net


MODELS = {'BIGGER.BIN': True, 'SMALLER.BIN': False}

if __name__ == '__main__':
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
    for name, want_bigger in MODELS.items():
        net = build(want_bigger)
        print('wrote %s, %d bytes; %s; hidden units used per layer %s' % (
            name, net.export(out / name), net.summary(), net.units))
