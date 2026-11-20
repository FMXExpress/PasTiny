"""Shared pieces for hand-written TNY2 networks: the weight arrays, phase
tables, the ReLU square used for products, and the file writer."""
import math
import struct
from pathlib import Path

import numpy as np

D, H, HID, L, VOCAB, CTX = 96, 4, 256, 4, 97, 128
HD = D // H
FREQ = [2, 7, 46, 54]      # multiples of 2*pi/128; the best of 20,000 random sets of four
F = len(FREQ)
W = [2 * math.pi * f / 128 for f in FREQ]
_lags = np.arange(1, 128)
GAP = F - max(sum(np.cos(2 * np.pi * f * _lags / 128) for f in FREQ))   # worst-case margin, 1.745
KNOTS, STEP = 7, 2.0 / 7


def phase(x):
    """a position as cosine and sine at each frequency"""
    out = []
    for w in W:
        out += [math.cos(w * x), math.sin(w * x)]
    return out


def rot(k):
    """the matrix that turns phase(x) into phase(x + k)"""
    m = np.zeros((2 * F, 2 * F), np.float32)
    for f, w in enumerate(W):
        c, s = math.cos(w * k), math.sin(w * k)
        m[2 * f, 2 * f], m[2 * f, 2 * f + 1] = c, -s
        m[2 * f + 1, 2 * f], m[2 * f + 1, 2 * f + 1] = s, c
    return m


def gain(energy):
    """the norm gain that makes the normalised vector equal the residual itself"""
    return math.sqrt(energy / D)


class Net:
    def __init__(self):
        z = lambda *shape: np.zeros(shape, np.float32)
        self.emb, self.pos, self.gf = z(VOCAB, D), z(CTX, D), z(D)
        self.blocks = [dict(g1=z(D), q=z(D, D), k=z(D, D), v=z(D, D), o=z(D, D),
                            g2=z(D), f1=z(HID, D), f2=z(D, HID)) for _ in range(L)]
        for b in self.blocks:
            b['g1'][:] = 1.0
            b['g2'][:] = 1.0
        self.gf[:] = 3.0
        self.units = [0] * L

    def square(self, layer, terms, out_dim, const):
        """adds 0.5 * (sum of terms)^2 to out_dim, as 14 ReLU pieces; terms are (dimension, sign)"""
        b = self.blocks[layer]
        for side in (1.0, -1.0):
            for k in range(KNOTS):
                u = self.units[layer]
                for d, s in terms:
                    b['f1'][u, d] = side * s
                b['f1'][u, const] = -k * STEP
                b['f2'][out_dim, u] = 0.5 * (STEP if k == 0 else 2 * STEP)
                self.units[layer] += 1

    def angle(self, layer, A, B, out, const, sign):
        """out = phase(A - B) for sign -1, phase(A + B) for sign +1; A, B, out are lists of dimensions.
        cos(A-B) = ((cA+cB)^2 + (sA+sB)^2)/2 - 1     sin(A-B) = ((sA+cB)^2 + (cA-sB)^2)/2 - 1
        cos(A+B) = ((cA+cB)^2 + (sA-sB)^2)/2 - 1     sin(A+B) = ((sA+cB)^2 + (cA+sB)^2)/2 - 1"""
        b = self.blocks[layer]
        for f in range(F):
            cA, sA, cB, sB = A[2 * f], A[2 * f + 1], B[2 * f], B[2 * f + 1]
            self.square(layer, [(cA, 1), (cB, 1)], out[2 * f], const)
            self.square(layer, [(sA, 1), (sB, -sign)], out[2 * f], const)
            self.square(layer, [(sA, 1), (cB, 1)], out[2 * f + 1], const)
            self.square(layer, [(cA, 1), (sB, sign)], out[2 * f + 1], const)
        u = self.units[layer]
        b['f1'][u, const] = 1.0                           # the constant 1
        b['f2'][out, u] = -(1.0 + STEP * STEP / 6)        # the -1, and the mean error of the pieces
        self.units[layer] += 1
        assert self.units[layer] <= HID

    def arrays(self):
        return [self.emb, self.pos, self.gf] + [v for b in self.blocks for v in b.values()]

    def export(self, path):
        """TNY2: 'TNY2', D, L, H, HID; each table row is a float32 scale and int8 values."""
        with open(path, 'wb') as f:
            f.write(b'TNY2' + struct.pack('<4h', D, L, H, HID))

            def table(w):
                for row in w:
                    s = max(float(np.abs(row).max()) / 127.0, 1e-8)
                    f.write(struct.pack('<f', s))
                    f.write(np.clip(np.round(row / s), -127, 127).astype(np.int8).tobytes())

            table(self.emb)
            table(self.pos)
            for b in self.blocks:
                f.write(b['g1'].astype('<f4').tobytes())
                for n in 'qkvo':
                    table(b[n])
                f.write(b['g2'].astype('<f4').tobytes())
                table(b['f1'])
                table(b['f2'])
            f.write(self.gf.astype('<f4').tobytes())
        return Path(path).stat().st_size

    def summary(self):
        return '%d of %d weights are non-zero' % (sum(int((a != 0).sum()) for a in self.arrays()),
                                                    sum(a.size for a in self.arrays()))
