# 066 · Forces and motion

This mechanics vocabulary pilot covers inertia, velocity, acceleration, sliding friction, linear momentum and net force. It uses the elementary classical definition of momentum for a moving body and the vector sum for net force. The friction response is scoped to sliding contact. These short answers support identification and explanation. Actual numerical calculations belong in Pascal.

The concepts follow the mechanics chapters on motion, Newton's laws, friction and momentum in [OpenStax College Physics 2e](https://openstax.org/details/books/college-physics-2e). The training examples and short labels were written for the pilot. Ninety development questions cover six terms. Eighteen prompts, including six individually written questions, were frozen before training. Evaluation concerns unseen wording of known concepts.

Use WebTiny trainer a1a36720ed558d6998e5beed9d4dbdd792626056 and CPU PyTorch 2.15.0. From PasTinyMoE:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch30/066/train.jsonl \
  --steps 650 --batch-size 8 --threads 1 --lr .00035 --out build/066/model.bin
```
