# Turbo Pascal Coach paired-example experiment

With expert 2 pinned, we compared the released operator and block-keyword model at commit 75d6ed3 to one candidate trained from those weights. The router, TP7 executable, model shape, other experts, and greedy decoding were fixed. Twelve new probes (three per fact) were written before fitting. The eight original Pascal probes and three later routing probes were regressions. No exact evaluation question appears in the training data. The candidates and prompts were not iteratively tuned against the final scores.

| Balanced fresh probes | Released | Candidate |
|---|---:|---:|
| div | 0/3 | 2/3 |
| mod | 0/3 | 2/3 |
| begin | 1/3 | 2/3 |
| end | 2/3 | 3/3 |
| **Total** | **3/12** | **9/12** |

On the eight original questions, the score rose from 5 to 6. The candidate gained three correct responses and lost two. On the three Pascal questions from the routing benchmark, it rose from 1 to 3. Each score counts exact strings, including punctuation. See [before.jsonl](before.jsonl) and [after.jsonl](after.jsonl) for all outputs.

## Error profile

On the fresh set the released model produced six malformed or unrelated answers and three incorrect syllabus keywords. The candidate produced two unrelated answers and one wrong keyword. It recognized the words for the quotient and the leftover of a division, but failed both blanks involving 19 and 4. It also confused “introduces a block” with “ends a block.” Among earlier questions it newly missed “how do i divide without the remainder” and “pascal what keyword opens a compound statement.” The aggregate gain does not guarantee the correct reply to any one phrasing.

The numeric training examples used six other operand pairs after excluding a pair with equal quotient and remainder. The two held-out numeric prompts test a new operand pair. With both missed, the next experiment should separate explaining a Pascal operator from actually evaluating arithmetic in Pascal code. For keyword teaching, prioritize negation and contrasting opening/closing cues on a separate development set.

## Reproduction

Use WebTiny trainer a1a36720ed558d6998e5beed9d4dbdd792626056 with CPU PyTorch 2.15.0. The dataset builder retains the original 36 development rows and adds paired operator, block-position and numeric examples. The trainer used 108 fitting rows and 12 internal validation rows, seed 42. We evaluated the prespecified 650-step export once. Final internal validation loss was 0.813 versus training loss 0.00001, so the small, templated dataset remains a limitation.

Run the following from PasTinyMoE. The pinned starting file matters when reproducing this experiment.

```sh
git show 75d6ed3:PasTinyMoE/specialists/models/PASCAL.BIN > /tmp/pascal-v1.bin
python specialists/pascal-v2/make_data.py
python "$WEBTINY/training/train.py" --init /tmp/pascal-v1.bin \
  --data specialists/pascal-v2/train.jsonl --steps 650 --batch-size 12 \
  --threads 2 --lr .00015 --out build/pascal-v2/PASCAL.BIN
```

Run score.py with a native SPEC3 executable, an expanded runtime directory and an output JSONL path. For a target replay, run `EXPERT < Q.IN > TP7.LOG` in DOS with the candidate runtime. The log's FPU line identifies the detected configuration. DOSBox-X core selection can affect emulated FPU detection.

The fresh prompt file SHA-256 is a5a281a4f5f9b972291973b3c921f2ba5f6680a8a61339517311835a81671b6d. The development data SHA-256 is a014b1a32cf572796b7afa68611314e46cd12e844f466b12fd66c012bde84721. Run `python specialists/pascal-v2/verify.py` to compare the saved target transcript with the host output question by question.

DOSBox-X with a normal 386 core and FPU detection reporting **no** reproduced all 23 candidate host outputs. The executable, catalog and all three BIN files in the packaged ZIP matched the files used for that replay. The 1.44 MB FAT12 image passed a byte-for-byte readback. The integrated AUTO score reached 20/24 on the original pilot comparison and 6/9 on the later in-scope router probes. Physical Pocket386 timing was outside this accuracy experiment.
