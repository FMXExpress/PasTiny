# 050 · Word origins

This model answers questions about the source languages of six English loanwords. Four targets name a single source language. Two give a borrowing path through more than one language. The short answers omit dates and the details of later changes in sense. The borrowing paths were checked against Merriam-Webster's etymologies on November 19, 2026.

| English word | Borrowing information taught | Source |
|---|---|---|
| algebra | From Arabic via Medieval Latin. | [Merriam-Webster](https://www.merriam-webster.com/dictionary/algebra) |
| tsunami | From Japanese. | [Merriam-Webster](https://www.merriam-webster.com/dictionary/tsunami) |
| kindergarten | From German. | [Merriam-Webster](https://www.merriam-webster.com/dictionary/kindergarten) |
| robot | From Czech. | [Merriam-Webster](https://www.merriam-webster.com/dictionary/robot) |
| mosquito | From Spanish. | [Merriam-Webster](https://www.merriam-webster.com/dictionary/mosquito) |
| ballet | From French, with Italian roots. | [Merriam-Webster](https://www.merriam-webster.com/dictionary/ballet) |

The 90 original training examples use 15 phrasing patterns per word, with nine rows reserved internally for validation. Each target has two separately frozen evaluation questions, including one individually written prompt. The probes test rephrasing about known words. The router's recognition of a word such as “robot” alone cannot establish that a question asks about its etymology.

## Reproduction

From PasTinyMoE, use the WebTiny trainer at commit a1a36720ed558d6998e5beed9d4dbdd792626056 with CPU PyTorch 2.15, default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/batch20/050/train.jsonl --steps 550 \
  --threads 1 --batch-size 10 --lr .00035 --out build/050/model.bin
```
