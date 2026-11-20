# 092 Wordplay

What is a palindrome? It reads the same backward and forward. What does an anagram do? It rearranges all the letters. What do the lines of a simple acrostic hide? The first letters spell a message. What makes a sentence a pangram? It uses every letter of the alphabet.

The corpus contains 20 original training prompts per fact. Two held-out prompts per fact were set aside before training. Pinned results use exact answer matching with this expert loaded in the native Pascal runtime.

## Sources

- [Merriam-Webster, palindrome](https://www.merriam-webster.com/dictionary/palindrome)
- [Merriam-Webster, anagram](https://www.merriam-webster.com/dictionary/anagram)
- [Merriam-Webster, acrostic](https://www.merriam-webster.com/dictionary/acrostic)
- [Merriam-Webster, pangram](https://www.merriam-webster.com/dictionary/pangram)

## Reproduction

From PasTinyMoE, set WEBTINY to the WebTiny checkout at commit `a1a36720ed558d6998e5beed9d4dbdd792626056` and run with CPU PyTorch.

```sh
mkdir -p build/092
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch60/092/train.jsonl --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/092/model.bin
```
