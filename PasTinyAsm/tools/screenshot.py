#!/usr/bin/env python3
"""Draw a DOS text screen saved by tests/snap.asm as a PNG.

  python3 tools/screenshot.py SNAP.SCR SNAP.FNT OUT.PNG

SNAP.SCR is 4000 bytes of character and colour pairs from B800:0000 and
SNAP.FNT the machine's own 8 x 16 font, so the picture shows what a VGA
card would: 80 x 25 cells of 9 x 16 dots, drawn at twice the size.
Needs Pillow.
"""
import sys
from PIL import Image

COLORS = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170), (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
          (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255), (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255)]
screen, font = open(sys.argv[1], 'rb').read(), open(sys.argv[2], 'rb').read()
assert len(screen) == 4000 and len(font) == 4096
im = Image.new('RGB', (720, 400))
px = im.load()
for row in range(25):
    for col in range(80):
        ch, attr = screen[2 * (row * 80 + col)], screen[2 * (row * 80 + col) + 1]
        fg, bg = COLORS[attr & 15], COLORS[(attr >> 4) & 7]
        for y in range(16):
            bits = font[ch * 16 + y]
            for x in range(9):
                on = bits & (0x80 >> x) if x < 8 else (bits & 1 and 0xC0 <= ch <= 0xDF)
                px[col * 9 + x, row * 16 + y] = fg if on else bg
im.resize((1440, 800), Image.NEAREST).save(sys.argv[3])
