# 010 Text file conventions

The six facts cover CR (13 decimal), LF (10), horizontal tab (9), DOS CRLF line endings, the historical Ctrl-Z text marker (26), and the directory size field defining the actual end of a disk file. [ASCII character table](https://www.rfc-editor.org/rfc/rfc20) · [The MS-DOS Encyclopedia, section II](https://www.pcjs.org/documents/books/mspl13/msdos/encyclopedia/section2/)

Training used 72 prompts. Direct expert selection in the native Pascal runtime yielded 12/18 exact answers on held-out rephrasings. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/010
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch80/010/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/010/model.bin
```
