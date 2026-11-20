# 009 Batch file vocabulary

The six examples use classic DOS COMMAND.COM syntax. ECHO hello displays text, REM introduces a comment, GOTO done transfers control to the :done label, and %1 and %2 expand to the first and second arguments. [The MS-DOS Encyclopedia, section III, batch-file directives](https://www.pcjs.org/documents/books/mspl13/msdos/encyclopedia/section3/)

Training used 72 prompts. Direct expert selection in the native Pascal runtime yielded 12/18 exact answers on held-out rephrasings. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/009
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch80/009/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/009/model.bin
```
