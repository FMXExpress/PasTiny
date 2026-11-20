# 047 · Antonyms

This expert supplies one opposite for a specified adjective sense. It shares eight headwords with Word Bench and Synonyms. The training corpus uses these short reference answers: brief → long (duration), fragile → sturdy (a box), silent → noisy (a room), rapid → slow (a current), vacant → occupied (a seat), damp → dry (a towel), narrow → wide (a road), and ancient → modern (a building). An antonym depends on sense and context. Other answers can be reasonable.

The headwords and adjective senses come from the [Word Bench syllabus](../../wordbench/words.tsv). The opposite choices and question wordings were written for this pilot. The 24 evaluation prompts were frozen before fitting. They use three unseen patterns per familiar headword, including a context-dependent question. Exact matching measures recall of the selected answer. It does not test new vocabulary.

Reproduce from PasTinyMoE using the WebTiny trainer at a1a36720ed558d6998e5beed9d4dbdd792626056 and CPU PyTorch 2.15.0. The run used seed 42 and the trainer's default internal validation fraction.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch20/047/train.jsonl \
  --steps 500 --batch-size 8 --threads 1 --lr .00035 --out build/047/model.bin
```
