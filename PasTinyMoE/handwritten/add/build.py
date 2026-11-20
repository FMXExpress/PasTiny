"""Write an addition network by hand: PLUS.BIN.

  python3 build.py [OUTPUT_DIRECTORY]

A TNY2 network in the pinned TINY 2.1 shape with no training and no data.  The
question holds two whole numbers of up to three digits each; the answer is
their sum, written normally:

  "what is 458 plus 367"  -> 825
  "999 + 999" after a word, e.g. "add 999 + 999" -> 1998

The first digit written depends on carries from every lower place, and each
carry needs its own layer, so three digits is what four layers allow.

Program, with A and B the two numbers and "place 0" the units:

  layer 1 attention  four heads: the latest non-digit (which number a digit is
                     in), the earliest digit (where A starts), the end-of-
                     question token (are we writing the answer yet), and the
                     previous position
  layer 1 MLP        position counters on question digits only; "I am the
                     second or later digit of a number"
  layer 2 attention  the last digit of B and the last digit of A: their
                     positions, and the two units digits, added
  layer 2 MLP        the units digit of the sum and the first carry
  layer 3 attention  the tens digits of A and B (zero if absent), added; and
                     whether any number has three digits
  layer 3 MLP        the tens digit of the sum and the second carry
  layer 4 attention  the hundreds digits, added
  layer 4 MLP        the hundreds digit and the last carry, and which digit to
                     write at this step of the answer

How far into the answer we are is passed along one step per layer: "the
previous position is the end of the question", then "the position before had
that flag", and so on.

Limits: a number may not be the very first thing in the question; the
question may be at most 72 characters; exactly two numbers of one to three
plain digits, without leading zeros.
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
AFTER, T1R, PD1, T1, G2, DH, DLO = 38, 39, 40, 41, 42, 43, 44
EB = list(range(45, 53))         # position of the last digit of B
EA = list(range(53, 61))         # position of the last digit of A
SB = list(range(61, 69))         # S at the last digit of B
S0, T2R, PG2, T2, G3 = 69, 70, 71, 72, 73
D0C = list(range(74, 78))        # code of the units digit of the sum
C1 = 78
S1, E1, T3R, M3R = 79, 80, 81, 82
D1C = list(range(83, 87))        # code of the tens digit of the sum
C2, T3, M2, M3, S2, T4R = 87, 88, 89, 90, 91, 92

UNIT = 3.0 / 127                 # one counter step: exactly three 8-bit levels
KW = 5.0
NATS = 14.0 * math.sqrt(HD)      # one step of preference
FINE = NATS / (UNIT * KW)
COARSE = 8 * FINE
FLAG = (9 * COARSE + 7 * FINE) * UNIT * KW + 300
DSTEP = 12.0 / 127               # a digit's value: exactly twelve 8-bit levels per unit
SC = 0.25                        # digit sums are kept at this size, so one unit is 3/127 ...
ZC = 1.0 / (DSTEP * SC)          # ... and this coefficient (127/3) turns a sum back into whole units
CS = 0.05                        # digit codes are kept at this size (plus one, so they are never negative)
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
    net.pos[0, MRK] = 1.0
    base = 2.25 + 1 + 0.01 + F

    def prefer(b, row, later, hi, lo):
        sign = 1.0 if later else -1.0
        b['q'][row, CONST], b['k'][row, hi] = sign * COARSE, KW
        b['q'][row + 1, CONST], b['k'][row + 1, lo] = sign * FINE, KW

    def previous(b, row, pairs):
        """a head on the position just before this one; pairs are (source, destination) dimensions"""
        for i in range(2 * F):
            b['q'][row + i, PPOS] = (NATS / GAP) * rot(-1)[i]
            b['k'][row + i, PPOS[i]] = 1.0
        for n, (src, dst) in enumerate(pairs):
            b['v'][row + n, src] = 1.0
            b['o'][dst, row + n] = 1.0

    def clamp(layer, terms, out):
        """out += the terms' sum clipped to 0..1 (two units); terms are (dimension, coefficient)"""
        b = net.blocks[layer]
        for step in (0.0, 1.0):
            u = net.units[layer]
            for d, c in terms:
                b['f1'][u, d] += c
            b['f1'][u, CONST] -= step
            b['f2'][out, u] = 1.0 if step == 0 else -1.0
            net.units[layer] += 1

    def hinges(layer, zterms, table, outs, gate=()):
        """outs += table[z] for whole z = sum of zterms, by straight lines between whole numbers.
        table is (values of z) x (len(outs)).  gate: (dimension, +1 or -1) flags that must hold."""
        b = net.blocks[layer]
        need = sum(1 for _, s in gate if s > 0)
        G = 20.0
        table = np.asarray(table, np.float32)

        def unit(knot, weights):
            u = net.units[layer]
            if knot is None:
                b['f1'][u, CONST] += 1.0
            else:
                for d, c in zterms:
                    b['f1'][u, d] += c
                b['f1'][u, CONST] -= knot
            for d, s in gate:
                b['f1'][u, d] += G * s
            b['f1'][u, CONST] -= G * need
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
    b['k'][2 * HD, NL], b['k'][2 * HD, MRK] = 1.0, 0.5
    b['v'][2 * HD, NL] = 1.0
    b['o'][AFTER, 2 * HD] = 1.0
    previous(b, 3 * HD, [(NL, T1R), (DIG, PD1)])           # head 4: the previous position
    # ---- layer 1 MLP
    b['g2'][:] = gain(base + 2 * F)
    for src, dst in ((LH, DH), (LO, DLO)):                 # the counters, on question digits only
        u = net.units[0]
        b['f1'][u, src], b['f1'][u, DIG], b['f1'][u, AFTER], b['f1'][u, CONST] = 1.0, 1.0, -1.0, -1.0
        b['f2'][dst, u] = 1.0
        net.units[0] += 1
    clamp(0, [(T1R, 4.0), (CONST, -1.0)], T1)
    clamp(0, [(DIG, 4.0), (PD1, 4.0), (AFTER, -4.0), (CONST, -6.0)], G2)   # a digit after a digit, in the question

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
    b['v'][HD + 2 * F, DVAL] = 1.0
    b['o'][S0, HD + 2 * F] = SC
    previous(b, 2 * HD, [(T1, T2R), (G2, PG2)])            # head 3: the previous position
    b['k'][3 * HD, CONST] = 1.25                           # fixes the 8-bit scale of every key
    # ---- layer 2 MLP: units digit and first carry
    b['g2'][:] = gain(base + 5 * F)
    table = [list(CS * (code(z % 10) + 1)) + [1.0 if z >= 10 else 0.0] for z in range(19)]
    hinges(1, [(S0, ZC)], table, D0C + [C1])
    clamp(1, [(T2R, 4.0), (CONST, -1.0)], T2)
    clamp(1, [(DIG, 4.0), (PG2, 4.0), (AFTER, -4.0), (CONST, -6.0)], G3)   # third or later digit of a number

    # ---- layers 3 and 4 attention: one place of A and of B, zero if the number has no such place
    BETA = NATS * 2 / GAP

    def place(b, row, end, start, start_rot, k, value_pairs):
        """a head on the digit k places left of `end`, in the number whose S matches `start`;
        with no such digit it settles on position 0, which holds nothing"""
        for i in range(2 * F):
            b['q'][row + i, end] = BETA * rot(-k)[i]
            b['k'][row + i, PPOS[i]] = 1.0
            b['k'][row + i, MRK] = -phase(0)[i]
            b['q'][row + 2 * F + i, start] = BETA * (rot(start_rot)[i] if start_rot else np.eye(2 * F, dtype=np.float32)[i])
            b['k'][row + 2 * F + i, S[i]] = 1.0
            b['k'][row + 2 * F + i, MRK] = -phase(0)[i]
        b['q'][row + 4 * F, CONST] = BETA * (2 * F - GAP / 2)
        b['k'][row + 4 * F, MRK] = 1.0
        for n, (src, dst, w) in enumerate(value_pairs):
            b['v'][row + n, src] = 1.0
            b['o'][dst, row + n] = w

    b = net.blocks[2]
    b['g1'][:] = gain(base + 5 * F)
    place(b, 0, EA, SA, -1, 1, [(DVAL, S1, SC), (DIG, E1, 1.0)])
    place(b, HD, EB, SB, 0, 1, [(DVAL, S1, SC), (DIG, E1, 1.0)])
    previous(b, 2 * HD, [(T2, T3R)])
    b['q'][3 * HD, CONST], b['k'][3 * HD, G3] = 60.0, 1.0  # head 4: any third digit anywhere
    b['v'][3 * HD, G3] = 1.0
    b['o'][M3R, 3 * HD] = 1.0
    # ---- layer 3 MLP: tens digit and second carry
    b['g2'][:] = gain(base + 5 * F)
    table = [list(CS * (code(z % 10) + 1)) + [1.0 if z >= 10 else 0.0] for z in range(20)]
    hinges(2, [(S1, ZC), (C1, 1.0)], table, D1C + [C2])
    clamp(2, [(T3R, 4.0), (CONST, -1.0)], T3)
    clamp(2, [(E1, 4.0), (CONST, -1.0)], M2)
    clamp(2, [(M3R, 4.0), (CONST, -1.0)], M3)

    b = net.blocks[3]
    b['g1'][:] = gain(base + 5 * F)
    place(b, 0, EA, SA, -1, 2, [(DVAL, S2, SC)])
    place(b, HD, EB, SB, 0, 2, [(DVAL, S2, SC)])
    previous(b, 2 * HD, [(T3, T4R)])
    # ---- layer 4 MLP: hundreds digit, last carry, and which digit to write now
    b['g2'][:] = gain(base + 5 * F)
    f1, f2 = b['f1'], b['f2']
    Z2 = [(S2, ZC), (C2, 1.0)]                             # the hundreds sum with its carry, in whole units
    G, GR = 55.0, 5.0

    def gated(flags, low=None):
        """a new unit's gate: every flag must hold; low=True also needs the hundreds sum <= 9, False >= 10"""
        u = net.units[3]
        need = sum(1 for _, s in flags if s > 0)
        for d, s in flags:
            f1[u, d] += G * s
        f1[u, CONST] -= G * need
        if low is not None:
            sign = -1.0 if low else 1.0
            for d, c in Z2:
                f1[u, d] += sign * GR * c
            f1[u, CONST] -= sign * GR * 9.5
        net.units[3] += 1
        return u

    def write_code(source, flags, low=None):
        """when the gate holds, write the digit whose code is stored in `source`"""
        for i in range(4):
            u = gated(flags, low)
            f1[u, source[i]] += 1.0 / CS
            f2[OUTP[i], u] = ALPHA
        u = gated(flags, low)
        f1[u, CONST] += 1.0
        f2[OUTP, u] = -ALPHA

    def write_fixed(weights_out, weights, flags, low=None):
        u = gated(flags, low)
        f1[u, CONST] += 1.0
        f2[weights_out, u] = weights

    T0 = NL
    ONE = ALPHA * code(1)
    yes, no = 1, -1
    # one-digit numbers
    write_code(D0C, [(M2, no), (M3, no), (C1, no), (T0, yes)])
    write_fixed(OUTP, ONE, [(M2, no), (M3, no), (C1, yes), (T0, yes)])
    write_code(D0C, [(M2, no), (M3, no), (C1, yes), (T1, yes)])
    write_fixed([NL], [STOP], [(M2, no), (M3, no), (C1, no), (T1, yes)])
    write_fixed([NL], [STOP], [(M2, no), (M3, no), (C1, yes), (T2, yes)])
    # the longer number has two digits
    write_code(D1C, [(M2, yes), (M3, no), (C2, no), (T0, yes)])
    write_code(D0C, [(M2, yes), (M3, no), (C2, no), (T1, yes)])
    write_fixed([NL], [STOP], [(M2, yes), (M3, no), (C2, no), (T2, yes)])
    write_fixed(OUTP, ONE, [(M2, yes), (M3, no), (C2, yes), (T0, yes)])
    write_code(D1C, [(M2, yes), (M3, no), (C2, yes), (T1, yes)])
    write_code(D0C, [(M2, yes), (M3, no), (C2, yes), (T2, yes)])
    write_fixed([NL], [STOP], [(M2, yes), (M3, no), (C2, yes), (T3, yes)])
    # the longer number has three digits: the hundreds sum decides whether a fourth digit leads
    first = [list(ALPHA * (code(z) if z <= 9 else code(1))) for z in range(20)]
    second = [list(ALPHA * code(z - 10)) if z >= 10 else [0.0] * 4 for z in range(20)]
    hinges(3, Z2, first, OUTP, gate=[(M3, yes), (T0, yes)])
    hinges(3, Z2, second, OUTP, gate=[(M3, yes), (T1, yes)])
    write_code(D1C, [(M3, yes), (T1, yes)], low=True)
    write_code(D0C, [(M3, yes), (T2, yes)], low=True)
    write_fixed([NL], [STOP], [(M3, yes), (T3, yes)], low=True)
    write_code(D1C, [(M3, yes), (T2, yes)], low=False)
    write_code(D0C, [(M3, yes), (T3, yes)], low=False)
    write_fixed([NL], [STOP], [(M3, yes), (T4R, yes)], low=False)
    return net


MODELS = {'PLUS.BIN': None}

if __name__ == '__main__':
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
    net = build()
    print('wrote PLUS.BIN, %d bytes; %s; hidden units used per layer %s' % (
        net.export(out / 'PLUS.BIN'), net.summary(), net.units))
