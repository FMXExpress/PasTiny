# 032 · Data structures

This specialist identifies the term that matches each of the following descriptions.

- Stack — last in first out.
- Queue — first in first out.
- Linked list — each node links to the next.

The original examples follow definitions from the NIST Dictionary of Algorithms and Data Structures. [Stack](https://xlinux.nist.gov/dads/HTML/stack.html) · [Queue](https://xlinux.nist.gov/dads/HTML/queue.html) · [Linked list](https://xlinux.nist.gov/dads/HTML/linkedList.html)

The 48 training questions use four descriptions per term. The 6 disjoint probes were fixed before fitting. Each term has one shared prompt form and one individually written example.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch100/032/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/032/model.bin
```
