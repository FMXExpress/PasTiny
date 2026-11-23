# Building Go from six English requests

Enter the six lines of [GO.EN](GO.EN) into an empty stock MAKECOM screen editor. Five requests left no new source. The request to display the board and get a move was accepted as FOR I=1 TO 7:OUT I:NEXT:SIREN. The request to validate and place a stone was split at “and”; the editor proposed INK 4 and COLOR 5 before refusing the rest and rolling the request back. The resulting program had only the loop and siren.

The experiment trains a Tiny classifier on the 30 labeled prompts in training.tsv, excluding all six specification prompts. Codes A through F identify board setup, display and input, passing and scoring, move validation and placement, capture and suicide, and ko and turn handling. The block library is the existing hand-written Go program. Tiny selects a block ID. It does not write that block's rules. The assembler checks for a complete sequence in dependency order and aborts on duplicates or gaps.

The model returned C F E D E F, correctly selecting placement, capture and ko. The prototype refused to compile that sequence. With the reviewer's explicit A B C D E F confirmation, it sent the corresponding source as keystrokes to an empty MAKECOM editor. There was no LOAD command. The resulting 6,720-byte TABGO.COM passed the capture, immediate ko, suicide, occupied-point and area-scoring smoke tests under DOSBox-X. The review replaced three wrong IDs, so this is an assisted build.

GOSELECT.BIN was fine-tuned from TASKS.BIN with WebTiny revision a1a36720ed558d6998e5beed9d4dbdd792626056 using 350 steps, batch size 8 and one CPU thread. Convert training.tsv to JSONL using the second field as question and the first as answer. With an FPC build of experiments/classic/check.pas, run:

```sh
python3 experiments/goenglish/build.py /path/to/check experiments/goenglish/GOSELECT.BIN experiments/goenglish/GO.EN /path/to/dos
```

Add `--confirm ABCDEF` after reviewing the six requests and the IDs. [Keyboard replay instructions](../editor/README.md)
