"""Write an addition network by hand: PLUS.BIN.

  python3 build.py [OUTPUT_DIRECTORY]

A TNY2 network in the pinned TINY 2.1 shape with no training and no data.  The
question holds two whole numbers from 0 to 99; the answer is their sum, written
normally:

  "what is 20 plus 17"  -> 37
  "what is 58 plus 67"  -> 125

The first digit written depends on the carries from the lower places, and each
carry needs its own layer.  Two digits is what fits exactly: a third place
needs its carry and the choice of which digit to write in the same last layer,
and the one-bit flags passed between layers are not exact enough in the 8-bit
runtime to gate that safely.

Program, with A and B the two numbers:

  layer 1 attention  four heads: the latest non-digit (which number a digit is
                     in), the earliest digit (where A starts), the end-of-
                     question token (are we writing the answer yet), and the
                     previous position
  layer 1 MLP        position counters on question digits only
  layer 2 attention  the last digit of B and the last digit of A: their
                     positions, and the two units digits, added
  layer 2 MLP        the units digit of the sum and the first carry
  layer 3 attention  the tens digits of A and B (zero if absent), added
  layer 3 MLP        the tens digit of the sum and the second carry
  layer 4 MLP        which digit to write at this step of the answer

How far into the answer we are is passed along one step per layer: "the
previous position is the end of the question", then "the position before had
that flag", and so on.

Robustness notes:

  - Flags are kept small in the residual (0.2).  At full size a flag that is
    on changes that position's overall size by a few percent, which upset the
    choice of "the latest digit" two layers later.
  - A flag made in one layer is only within a few percent of 1 when read in
    another.  Each gated copy is therefore written as the difference of two
    units that share the gate, with a little slack, so the gate's error
    cancels.
  - "The last digit of A" is chosen by matching the number's start, which the
    space before A matches too.  That selection now also requires a digit.
  - Digit values and their sums use exact 8-bit steps, so every knot of the
    "sum to digit" tables sits on a whole number.

Limits: a number may not be the very first thing in the question; the
question may be at most 72 characters; exactly two numbers of one or two plain
digits, without a leading zero.
"""
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tny2 import CTX, F, GAP, HD, Net, gain, phase, rot

# ---- residual stream layout
CONST, NL, MRK, LH, LO, DIG, NDG, DVAL, COMP, PAD = range(10)
PPOS = list(range(10, 18))       # phase of the position
OUTP = list(range(18, 22))       # which digit to write (digits carry their code here)
S = list(range(22, 30))          # position of the latest non-digit (the same for every digit of one number)
SA = list(range(30, 38))         # position of the earliest digit (the start of A)
AFTER, T1R, T1, DH, DLO = 38, 39, 40, 41, 42
EB = list(range(43, 51))         # position of the last digit of B
EA = list(range(51, 59))         # position of the last digit of A
SB = list(range(59, 67))         # S at the last digit of B
S0, T2R, T2 = 67, 68, 69
D0C = list(range(70, 74))        # code of the units digit of the sum
C1, S1, E1, T3R = 74, 75, 76, 77
D1C = list(range(78, 82))        # code of the tens digit of the sum
C2, T3, M2, QD = 82, 83, 84, 85   # QD: this is a digit of the question

UNIT = 3.0 / 127                 # one counter step: exactly three 8-bit levels
KW = 5.0
NATS = 14.0 * math.sqrt(HD)      # one step of preference
FINE = NATS / (UNIT * KW)
COARSE = 8 * FINE
FLAG = (9 * COARSE + 7 * FINE) * UNIT * KW + 300
DSTEP = 12.0 / 127               # a digit's value: exactly twelve 8-bit levels per unit
SC = 1.0 / 12                    # digit sums are kept at this size, so one unit is 1/127 ...
ZC = 127.0                       # ... and this coefficient turns a sum back into whole units
CS = 0.05                        # digit codes are kept at this size (plus one, so they are never negative)
FS = 0.2                         # flags are kept at this size
MK = 0.3                         # the marker on position 0 is kept at this size
ALPHA, STOP = 8.0, 20.0


def code(d):
    """a digit as two phases round a ten-step circle; different digits are at most a quarter alike"""
    return np.array([math.cos(2 * math.pi * d / 10), math.sin(2 * math.pi * d / 10),
                     math.cos(6 * math.pi * d / 10), math.sin(6 * math.pi * d / 10)], np.float32)


def token(c):
    return ord(c) - 30


def build():
    net = Net()
    for c in map(chr, range(32, 127)):
        t = token(c)
        if c.isdigit():
            v = int(c) * DSTEP
            net.emb[t, DIG], net.emb[t, DVAL], net.emb[t, COMP] = 1.0, v, math.sqrt(0.75 - v * v)
            net.emb[t, OUTP] = 0.5 * code(int(c))
        else:
            net.emb[t, NDG], net.emb[t, PAD] = 1.0, math.sqrt(1.25)
    net.emb[1, NL], net.emb[1, PAD] = 1.0, math.sqrt(1.25)
    for p in range(CTX):
        net.pos[p, CONST] = 1.0
        net.pos[p, LH] = UNIT * min(p // 8, 9)
        net.pos[p, LO] = UNIT * (p % 8)
        net.pos[p, PPOS] = phase(p)
    net.pos[0, MRK] = MK
    base = 2.25 + 1 + 0.01 + F

    def prefer(b, row, later, hi, lo):
        sign = 1.0 if later else -1.0
        b['q'][row, CONST], b['k'][row, hi] = sign * COARSE, KW
        b['q'][row + 1, CONST], b['k'][row + 1, lo] = sign * FINE, KW

    def previous(b, row, pairs):
        """a head on the position just before this one; pairs are (source, destination, weight)"""
        for i in range(2 * F):
            b['q'][row + i, PPOS] = (NATS / GAP) * rot(-1)[i]
            b['k'][row + i, PPOS[i]] = 1.0
        for n, (src, dst, w) in enumerate(pairs):
            b['v'][row + n, src] = 1.0
            b['o'][dst, row + n] = w

    def clamp(layer, terms, out):
        """out += FS * (the terms' sum clipped to 0..1), two units; terms are (dimension, coefficient)"""
        b = net.blocks[layer]
        for step in (0.0, 1.0):
            u = net.units[layer]
            for d, c in terms:
                b['f1'][u, d] += c
            b['f1'][u, CONST] -= step
            b['f2'][out, u] = FS if step == 0 else -FS
            net.units[layer] += 1

    def hinges(layer, zterms, table, outs):
        """outs += table[z] for whole z = sum of zterms, by straight lines between whole numbers.
        table is (values of z) x (len(outs))."""
        b = net.blocks[layer]
        table = np.asarray(table, np.float32)

        def unit(knot, weights):
            u = net.units[layer]
            if knot is None:
                b['f1'][u, CONST] += 1.0
            else:
                for d, c in zterms:
                    b['f1'][u, d] += c
                b['f1'][u, CONST] -= knot
            b['f2'][outs, u] = weights
            net.units[layer] += 1

        unit(None, table[0])
        slope = np.zeros(len(outs), np.float32)
        for j in range(len(table) - 1):
            new = table[j + 1] - table[j]
            if np.abs(new - slope).max() > 1e-9:
                unit(float(j), new - slope)
            slope = new

    # ---- layer 1 attention
    b = net.blocks[0]
    b['g1'][:] = gain(base)
    b['q'][0, CONST], b['k'][0, NDG] = FLAG, 1.0           # head 1: the latest non-digit
    prefer(b, 1, True, LH, LO)
    b['q'][HD, CONST], b['k'][HD, DIG] = FLAG, 1.0         # head 2: the earliest digit
    prefer(b, HD + 1, False, LH, LO)
    for i in range(2 * F):
        b['v'][i, PPOS[i]] = 1.0
        b['o'][S[i], i] = 1.0
        b['v'][HD + i, PPOS[i]] = 1.0
        b['o'][SA[i], HD + i] = 1.0
    b['q'][2 * HD, CONST] = 150.0                          # head 3: the end-of-question token, else position 0
    b['k'][2 * HD, NL], b['k'][2 * HD, MRK] = 1.0, 0.5 / MK
    b['v'][2 * HD, NL] = 1.0
    b['o'][AFTER, 2 * HD] = 1.0
    previous(b, 3 * HD, [(NL, T1R, FS)])                   # head 4: the previous position
    # ---- layer 1 MLP
    b['g2'][:] = gain(base + 2 * F)
    for src, dst in ((LH, DH), (LO, DLO)):                 # the counters, on question digits only
        u = net.units[0]
        b['f1'][u, src], b['f1'][u, DIG], b['f1'][u, AFTER], b['f1'][u, CONST] = 1.0, 1.0, -1.0, -1.0
        b['f2'][dst, u] = 1.0
        net.units[0] += 1
    clamp(0, [(T1R, 4.0 / FS), (CONST, -1.0)], T1)
    clamp(0, [(DIG, 4.0), (AFTER, -4.0), (CONST, -1.0)], QD)

    # ---- layer 2 attention
    b = net.blocks[1]
    b['g1'][:] = gain(base + 2 * F)
    prefer(b, 0, True, DH, DLO)                            # head 1: the latest question digit (the end of B)
    MATCH = FLAG / GAP
    for i in range(2 * F):
        b['v'][i, PPOS[i]] = 1.0
        b['o'][EB[i], i] = 1.0
        b['v'][2 * F + i, S[i]] = 1.0
        b['o'][SB[i], 2 * F + i] = 1.0
        b['q'][HD + i, SA] = MATCH * rot(-1)[i]            # head 2: the latest digit whose number starts at A's start
        b['k'][HD + i, S[i]] = 1.0
        b['v'][HD + i, PPOS[i]] = 1.0
        b['o'][EA[i], HD + i] = 1.0
    b['v'][4 * F, DVAL] = 1.0
    b['o'][S0, 4 * F] = SC
    prefer(b, HD + 2 * F, True, DH, DLO)
    b['q'][HD + 2 * F + 2, CONST], b['k'][HD + 2 * F + 2, QD] = 600.0, 1.0 / FS   # ... and it must be a digit: the
    # space before A matches the same start, and a slightly larger space once beat the digit
    b['v'][HD + 2 * F, DVAL] = 1.0
    b['o'][S0, HD + 2 * F] = SC
    previous(b, 2 * HD, [(T1, T2R, 1.0)])                  # head 3: the previous position
    b['k'][3 * HD, CONST] = 1.25                           # fixes the 8-bit scale of every key
    # ---- layer 2 MLP: units digit and first carry
    b['g2'][:] = gain(base + 5 * F)
    table = [list(CS * (code(z % 10) + 1)) + [FS if z >= 10 else 0.0] for z in range(19)]
    hinges(1, [(S0, ZC)], table, D0C + [C1])
    clamp(1, [(T2R, 4.0 / FS), (CONST, -1.0)], T2)

    # ---- layer 3 attention: the tens digit of A and of B, zero if the number has none
    BETA = NATS * 2 / GAP

    def place(b, row, end, start, start_rot, k, value_pairs):
        """a head on the digit k places left of `end`, in the number whose S matches `start`;
        with no such digit it settles on position 0, which holds nothing"""
        for i in range(2 * F):
            b['q'][row + i, end] = BETA * rot(-k)[i]
            b['k'][row + i, PPOS[i]] = 1.0
            b['k'][row + i, MRK] = -phase(0)[i] / MK
            b['q'][row + 2 * F + i, start] = BETA * (rot(start_rot)[i] if start_rot else np.eye(2 * F, dtype=np.float32)[i])
            b['k'][row + 2 * F + i, S[i]] = 1.0
            b['k'][row + 2 * F + i, MRK] = -phase(0)[i] / MK
        b['q'][row + 4 * F, CONST] = BETA * (2 * F - GAP / 2)
        b['k'][row + 4 * F, MRK] = 1.0 / MK
        for n, (src, dst, w) in enumerate(value_pairs):
            b['v'][row + n, src] = 1.0
            b['o'][dst, row + n] = w

    b = net.blocks[2]
    b['g1'][:] = gain(base + 5 * F)
    place(b, 0, EA, SA, -1, 1, [(DVAL, S1, SC), (DIG, E1, FS)])
    place(b, HD, EB, SB, 0, 1, [(DVAL, S1, SC), (DIG, E1, FS)])
    previous(b, 2 * HD, [(T2, T3R, 1.0)])
    # ---- layer 3 MLP: tens digit and second carry
    b['g2'][:] = gain(base + 5 * F)
    table = [list(CS * (code(z % 10) + 1)) + [FS if z >= 10 else 0.0] for z in range(20)]
    hinges(2, [(S1, ZC), (C1, 1.0 / FS)], table, D1C + [C2])
    clamp(2, [(T3R, 4.0 / FS), (CONST, -1.0)], T3)
    clamp(2, [(E1, 4.0 / FS), (CONST, -1.0)], M2)

    # ---- layer 4 MLP: which digit to write now
    b = net.blocks[3]
    b['g2'][:] = gain(base + 5 * F)
    f1, f2 = b['f1'], b['f2']
    G, SLACK = 4.0, 0.5

    def gated(flags):
        """a new unit that is open, by SLACK, only when every flag holds; flags are (dimension, size, +1 or -1)"""
        u = net.units[3]
        need = sum(1 for _, _, s in flags if s > 0)
        for d, size, s in flags:
            f1[u, d] += G * s / size
        f1[u, CONST] += SLACK - G * need
        net.units[3] += 1
        return u

    def write_code(source, flags):
        """when the gate holds, write the digit whose code is stored in `source`.  The last unit carries
        the gate alone and is subtracted, so the gate's own value (slack and flag error) cancels."""
        for i in range(4):
            u = gated(flags)
            f1[u, source[i]] += 1.0 / CS
            f2[OUTP[i], u] = ALPHA
        u = gated(flags)
        f1[u, CONST] += 1.0
        f2[OUTP, u] = -ALPHA

    def write_fixed(out, weights, flags):
        u = gated(flags)
        f1[u, CONST] += 1.0
        f2[out, u] = weights

    yes, no = 1, -1
    T0, ONE = (NL, 1.0), ALPHA * code(1)
    t1, t2, t3, m2, c1, c2 = (T1, FS), (T2, FS), (T3, FS), (M2, FS), (C1, FS), (C2, FS)
    on = lambda flag: flag + (yes,)
    off = lambda flag: flag + (no,)
    # both numbers have one digit
    write_code(D0C, [off(m2), off(c1), on(T0)])
    write_fixed([NL], [STOP], [off(m2), off(c1), on(t1)])
    write_fixed(OUTP, ONE, [off(m2), on(c1), on(T0)])
    write_code(D0C, [off(m2), on(c1), on(t1)])
    write_fixed([NL], [STOP], [off(m2), on(c1), on(t2)])
    # the longer number has two digits
    write_code(D1C, [on(m2), off(c2), on(T0)])
    write_code(D0C, [on(m2), off(c2), on(t1)])
    write_fixed([NL], [STOP], [on(m2), off(c2), on(t2)])
    write_fixed(OUTP, ONE, [on(m2), on(c2), on(T0)])
    write_code(D1C, [on(m2), on(c2), on(t1)])
    write_code(D0C, [on(m2), on(c2), on(t2)])
    write_fixed([NL], [STOP], [on(m2), on(c2), on(t3)])
    return net


MODELS = {'PLUS.BIN': None}

if __name__ == '__main__':
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
    net = build()
    print('wrote PLUS.BIN, %d bytes; %s; hidden units used per layer %s' % (
        net.export(out / 'PLUS.BIN'), net.summary(), net.units))
