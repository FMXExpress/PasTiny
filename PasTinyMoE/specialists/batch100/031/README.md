# 031 · Sorting vocabulary

This specialist identifies the term that matches each of the following descriptions.

- Sort key — the field that determines record order.
- Stable sort — ties always keep their original order.
- Ascending order — numbers go from smallest to largest.
- Comparison — two keys are tested against each other.

The original examples follow definitions from the NIST Dictionary of Algorithms and Data Structures. [Sorting](https://xlinux.nist.gov/dads/HTML/sort.html) · [Stability](https://xlinux.nist.gov/dads/HTML/stable.html)

The 64 training questions use four descriptions per term. The 8 disjoint probes were fixed before fitting. Each term has one shared prompt form and one individually written example.

## Reproduction

From PasTinyMoE using WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch100/031/train.jsonl --steps 550 --threads 1 --batch-size 10 --lr .00035 --out build/031/model.bin
```
