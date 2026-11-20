# 049 · Idioms

This model gives one conventional figurative meaning for each of six English expressions. Its training set uses 15 original question patterns per expression (90 rows), including nine internal validation rows. The separate 12 evaluation questions were frozen before fitting. Each expression has a new general question and an individually written situation. Sources were checked on November 19, 2026.

| Expression | Target meaning | Sense reference |
|---|---|---|
| break the ice | Make people feel at ease. | [Cambridge Dictionary](https://dictionary.cambridge.org/dictionary/english/break-the-ice) |
| spill the beans | Reveal a secret. | [Cambridge Dictionary](https://dictionary.cambridge.org/dictionary/english/spill-the-beans) |
| hit the books | Study hard. | [Cambridge Dictionary](https://dictionary.cambridge.org/dictionary/english/hit-the-books) |
| under the weather | Feeling unwell. | [Cambridge Dictionary](https://dictionary.cambridge.org/dictionary/english/under-the-weather) |
| on the fence | Undecided. | [Cambridge Dictionary](https://dictionary.cambridge.org/dictionary/english/on-the-fence) |
| a piece of cake | Something easy. | [Cambridge Dictionary](https://dictionary.cambridge.org/dictionary/english/a-piece-of-cake) |

The probes ask about familiar expressions. The evaluation covers neither unfamiliar idioms nor arbitrary literal uses of the same nouns. For example, a question about actual beans may contain the router keyword “beans.”

## Reproduction

From PasTinyMoE, use the WebTiny trainer at commit a1a36720ed558d6998e5beed9d4dbdd792626056 with CPU PyTorch 2.15, default seed 42. The JSONL files are the complete input and probe records.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/batch20/049/train.jsonl --steps 550 \
  --threads 1 --batch-size 10 --lr .00035 --out build/049/model.bin
```
