"""Write exact yes/no rule networks for PasTinyJev by hand.

  python3 build.py [OUTPUT_DIRECTORY]

PasTinyJev reads a decision as the score of the letter y minus the letter n
after "state|instructions".  Each network here answers one fixed rule about
the text with a probability near 1 or near 0, correct by construction:

  DIGIT.BIN     the text contains a digit
  QMARK.BIN     the text contains a question mark
  EXCLAIM.BIN   the text contains an exclamation mark

One attention layer does the work.  The end-of-question position looks for a
character of the wanted kind; if there is none it falls back on position 0.
What it finds sets a flag that the letters y and n read with opposite signs.
The other three layers are zero.

The rule looks at the whole read, state and instructions together.  PasTinyJev
removes a final "?" or "." from instructions, so a question mark there does
not count.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tny2 import CTX, D, VOCAB, Net

CONST, P0, HIT, FLAG = 0, 1, 2, 3


def token(c):
    return ord(c) - 30


def build(wanted):
    net = Net()
    for c in wanted:
        net.emb[token(c), HIT] = 1.0
    net.emb[token('y'), FLAG] = 1.0          # y and n read the flag with opposite signs
    net.emb[token('n'), FLAG] = -1.0
    net.pos[:, CONST] = 1.0
    net.pos[0, P0] = 1.0
    b = net.blocks[0]
    b['g1'][:] = math.sqrt(1.5 / D)          # roughly: normalised vector = residual
    b['q'][0, CONST] = 400.0                 # look for a wanted character ...
    b['k'][0, HIT] = 1.0
    b['k'][0, P0] = 0.4                      # ... or, failing that, position 0
    b['v'][0, HIT] = 2.0                     # a hit is worth +2 (+1 on position 0 itself)
    b['v'][0, P0] = -1.0                     # the fallback is worth -1
    b['o'][FLAG, 0] = 4.0
    net.gf[:] = 0.45                         # sets how far from 0.5 the answers sit
    return net


MODELS = {'DIGIT.BIN': '0123456789', 'QMARK.BIN': '?', 'EXCLAIM.BIN': '!'}

if __name__ == '__main__':
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
    for name, wanted in MODELS.items():
        net = build(wanted)
        print('wrote %s, %d bytes; %s' % (name, net.export(out / name), net.summary()))
