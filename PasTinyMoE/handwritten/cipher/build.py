"""Write letter-substitution networks by hand: ROT13.BIN, ATBASH.BIN and ECHO.BIN.

  python3 build.py [OUTPUT_DIRECTORY]

Each is a TNY2 network in the pinned TINY 2.1 shape with no training and no
data.  It answers with the last word of the question, read forwards, with
every letter passed through a fixed substitution:

  ROT13   a<->n, b<->o ...        "rot13 hello"  -> uryyb
  ATBASH  a<->z, b<->y ...        "atbash hello" -> svool
  ECHO    no change               "echo hello"   -> hello

Capital letters are read as small letters.  Digits and punctuation pass
through unchanged.

Program, with n = position of the end-of-question token, s = position where
the last word starts and p = the current position:

  layer 1 attention  looks at the latest space (or position 0 if there is none)
                     and fetches a table entry: the phase of s
  layer 1 MLP        subtracts its own position: at the end token this is the
                     phase of s-n
  layer 2 attention  every answer position fetches that from the end token
  layer 2 MLP        adds its own position: the phase of s-n+p, which walks
                     s, s+1, s+2 ... as the answer is written
  layer 3 attention  looks at that question position and copies its letter
                     through the substitution; when the walk reaches the end
                     token, copying it ends the answer
  layer 4            all zero
"""
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tny2 import CTX, F, GAP, HD, VOCAB, Net, gain, phase

# ---- residual stream layout (all 96 dimensions)
CONST, NL, SP, LIN = 0, 1, 2, 3
PPOS = list(range(4, 12))        # phase of the position
VAL = list(range(12, 20))        # table: phase of p+1 (phase of 0 at position 0)
SPH = list(range(20, 28))        # fetched: phase of s
DPH = list(range(28, 36))        # computed: phase of s - p
FPH = list(range(36, 44))        # fetched from the end token: phase of s - n
QPH = list(range(44, 52))        # computed: phase of s - n + p
TOK = list(range(52, 96))        # which letter: 26 letters, 10 digits, 8 dimensions for the rest
LETTERS, DIGITS, OTHER = TOK[:26], TOK[26:36], TOK[36:]


def token(c):
    return ord(c) - 30


def build(substitution):
    """substitution maps each small letter to the letter written for it"""
    net = Net()
    # ---- letters: one dimension each, so any substitution is an exact permutation
    net.emb[1, NL] = 1.0
    net.emb[token(' '), SP] = 1.0
    for i in range(26):
        net.emb[token(chr(97 + i)), LETTERS[i]] = 1.0
        net.emb[token(chr(65 + i)), LETTERS[i]] = 0.9          # capitals read as small letters
    for i in range(10):
        net.emb[token(str(i)), DIGITS[i]] = 1.0
    others = [c for c in map(chr, range(33, 127)) if not c.isalnum()]
    codes = [c for c in np.ndindex(*(2,) * 8) if sum(c) % 2 == 0]     # even-weight words: any two differ in 2+ places
    rng = np.random.RandomState(3)
    for c, i in zip(others, rng.permutation(len(codes))):
        net.emb[token(c), OTHER] = (np.array(codes[i]) * 2.0 - 1.0) / math.sqrt(8)

    # ---- positions
    for p in range(CTX):
        net.pos[p, CONST] = 1.0
        net.pos[p, LIN] = p / 127.0     # a whole 8-bit step per position, so no two positions collide
        net.pos[p, PPOS] = phase(p)
        net.pos[p, VAL] = phase(p + 1)
    net.pos[0, VAL] = phase(0)
    net.pos[0, SP] = 0.5            # with no space in the question, position 0 is the word start
    net.pos[0, NL] = 0.5            # before the end token arrives, look at position 0 instead
    base = 2 + 0.03 + 2 * F         # token, constant, about the mean of LIN squared, two phase tables

    # ---- layer 1 attention: the latest space.  A space beats a letter; among spaces the later wins.
    b = net.blocks[0]
    b['g1'][:] = gain(base)
    b['q'][0, CONST] = 20000.0
    b['k'][0, SP] = 1.0
    b['q'][1, CONST] = 8800.0
    b['k'][1, LIN] = 1.0
    for i in range(2 * F):
        b['v'][i, VAL[i]] = 1.0
        b['o'][SPH[i], i] = 1.0
    # ---- layer 1 MLP: phase(s - p)
    b['g2'][:] = gain(base + F)
    net.angle(0, SPH, PPOS, DPH, CONST, -1)

    # ---- layer 2 attention: fetch phase(s - n) from the end-of-question token
    b = net.blocks[1]
    b['g1'][:] = gain(base + 2 * F)
    b['q'][0, CONST] = 150.0
    b['k'][0, NL] = 1.0
    for i in range(2 * F):
        b['v'][i, DPH[i]] = 1.0
        b['o'][FPH[i], i] = 1.0
    # ---- layer 2 MLP: phase(s - n + p)
    b['g2'][:] = gain(base + 3 * F)
    net.angle(1, FPH, PPOS, QPH, CONST, +1)

    # ---- layer 3 attention: two heads with the same aim copy the letter at s - n + p
    b = net.blocks[2]
    b['g1'][:] = gain(base + 4 * F)
    ALPHA, KAPPA, BETA = 8.0, 16.0, 70.0 / GAP
    for h in (0, 1):
        for i in range(2 * F):
            b['q'][h * HD + i, QPH[i]] = BETA
            b['k'][h * HD + i, PPOS[i]] = 1.0
    target = {LETTERS[i]: LETTERS[ord(substitution[chr(97 + i)]) - 97] for i in range(26)}
    for slot, d in enumerate(TOK):                      # 24 letter dimensions in head 1, 20 in head 2
        b['v'][slot, d] = 1.0
        b['o'][target.get(d, d), slot] = ALPHA
    b['v'][len(TOK), NL] = 0.15                         # the copied end token ...
    b['v'][len(TOK), SP] = -0.30                        # (but not the markers on position 0)
    b['o'][NL, len(TOK)] = KAPPA / 0.15                 # ... ends the answer
    return net


ALPHABET = 'abcdefghijklmnopqrstuvwxyz'
MODELS = {'ROT13.BIN': {c: ALPHABET[(i + 13) % 26] for i, c in enumerate(ALPHABET)},
          'ATBASH.BIN': {c: ALPHABET[25 - i] for i, c in enumerate(ALPHABET)},
          'ECHO.BIN': {c: c for c in ALPHABET}}

if __name__ == '__main__':
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
    for name, substitution in MODELS.items():
        net = build(substitution)
        print('wrote %s, %d bytes; %s; hidden units used per layer %s' % (
            name, net.export(out / name), net.summary(), net.units))
