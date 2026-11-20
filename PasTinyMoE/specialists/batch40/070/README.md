# 070 · Human Body

Six elementary organ-to-system associations cover the heart, brain, kidneys, skin, lungs and stomach. Each answer gives a principal organ system. Organs can play roles in multiple systems. The syllabus supplies introductory anatomical terminology; it contains no diagnostic or treatment examples. [OpenStax Anatomy and Physiology 2e, structural organization and organ systems](https://openstax.org/books/anatomy-and-physiology-2e/pages/1-2-structural-organization-of-the-human-body)

The 72 development questions use 12 original template wordings per organ. The 18 evaluation questions use two additional templates and one independently phrased question per organ and were frozen before training. All probes contain the organ name. Testing concerns the same six associations only.

From PasTinyMoE use CPU PyTorch 2.15.0 and WebTiny at a1a36720ed558d6998e5beed9d4dbdd792626056, with seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch40/070/train.jsonl \
  --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/070/model.bin
```

The independently pinned native Pascal replay produced 18/18 exact answers. [Per-question results](oracle.jsonl)
