# 006 · Floppy disk terms

This expert defines seven terms for magnetic diskettes and distinguishes the write-protect mechanisms of 5.25-inch and 3.5-inch PC media. The index-hole answer describes soft-sectored media with an index hole.

- `track` — A circular recording path on one side.
- `sector` — An addressable block of data on a track.
- `cylinder` — The tracks at one radius across all sides.
- `head` — The part that reads or writes magnetic data.
- `index hole` — A hole that marks one turn of the disk.
- `write protect notch` — On a 5.25 inch disk, covering it blocks writes.
- `write protect tab` — On a 3.5 inch disk, an open hole blocks writes.

The geometry and head terminology follow IBM's 5114 manual. The media illustrations and write-protect conventions follow Scott Mueller's *Upgrading and Repairing PCs*. The glosses and questions were written for this expert. [IBM maintenance manual](https://www.bitsavers.org/pdf/ibm/5110/SY31-0551-1_IBM_5114_Diskette_Unit_Mainenance_Jan1979.pdf) · [Upgrading and Repairing PCs](https://computarium.lcd.lu/library/PDF/MUELLER_Upgrading_and_Repairing_PCs_1998.pdf)

The 112 training prompts and 14 disjoint held-out prompts use explicit floppy or diskette context. Each term has one common held-out phrasing and one individual question frozen before fitting. The two routing keywords preserve ambiguous words such as “head” and “track” for other topics.

## Reproduction

From PasTinyMoE with WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch70/006/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/006/model.bin
```
