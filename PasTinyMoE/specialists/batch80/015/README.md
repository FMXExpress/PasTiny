# 015 Bitmap graphics

What is a bitmap pixel? One picture element. What is a bitmap palette? A table of colors. What does a bitmap bit plane contain? One bit from every pixel. What is a bitmap scan line? One row of pixels.

Twenty training prompts and two independently worded held-out prompts cover each term. Pinned evaluation runs the host Pascal decoder with the intended model loaded and scores complete answers.

## Sources

- [Microsoft, About Bitmaps](https://learn.microsoft.com/en-us/windows/win32/gdi/about-bitmaps)
- [Amiga Hardware Reference Manual, Bitplanes](https://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node0063.html)

## Reproduction

From PasTinyMoE, set WEBTINY to WebTiny commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/015
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch80/015/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/015/model.bin
```
