# Word Bench · expert 041

[Download SPEC4.ZIP](../../dist/SPEC4.ZIP), extract it to its own directory on an SD card, and run EXPERT. Use AUTO and ask “what does fragile mean”, or pin Word Bench with USE 41. This four-model edition includes DOS Guide, Turbo Pascal Coach, Pocket Naturalist and Word Bench. The model files alone occupy 1,527,232 bytes. The three-model floppy edition is available separately.

Word Bench teaches one common adjective sense for each of **brief, fragile, silent, rapid, vacant, damp, narrow and ancient**. The [syllabus](words.tsv) gives the exact short answers. Each sense was checked against the adjective entry from the Free Dictionary API. [Brief](https://api.dictionaryapi.dev/api/v2/entries/en/brief) · [Fragile](https://api.dictionaryapi.dev/api/v2/entries/en/fragile) · [Silent](https://api.dictionaryapi.dev/api/v2/entries/en/silent) · [Rapid](https://api.dictionaryapi.dev/api/v2/entries/en/rapid) · [Vacant](https://api.dictionaryapi.dev/api/v2/entries/en/vacant) · [Damp](https://api.dictionaryapi.dev/api/v2/entries/en/damp) · [Narrow](https://api.dictionaryapi.dev/api/v2/entries/en/narrow) · [Ancient](https://api.dictionaryapi.dev/api/v2/entries/en/ancient)

## Evaluation

| Greedy exact answer | Two withheld wording patterns, 16 prompts | Individual context sentences, 8 prompts |
|---|---:|---:|
| Original general weights | 0/16 | 0/8 |
| Word Bench, pinned | 16/16 | 8/8 |
| Four-expert AUTO | 16/16 | 8/8 |

The context probes were added after training. Both sets ask about the same eight trained words. These results measure recall of that fixed vocabulary. A dictionary lookup could answer the same syllabus exactly. The pilot establishes that a fourth independently trained TNY2 model works in the existing real-mode runtime. [Per-question results](results.jsonl)

AUTO looks for a supported word as a whole token. Mixed domains or no matching domain request clarification. Within a single domain this is a keyword heuristic, so a sentence that merely mentions “rapid” may select Word Bench. All 72 earlier host integration outcomes matched the previous three-expert release.

## Rebuild

Run from PasTinyMoE, with WEBTINY pointing to WebTiny commit a1a36720ed558d6998e5beed9d4dbdd792626056. The run used Python 3.12, PyTorch 2.15 CPU, default seed 42, 87 fitting rows and 9 validation rows. The prepared data contains 12 training question patterns for each word. The evaluation prompts were excluded from fitting and validation.

```sh
python specialists/wordbench/data.py
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/wordbench/train.jsonl --steps 600 --batch-size 12 \
  --threads 2 --lr .00035 --out build/wordbench/WORDS.BIN
python specialists/wordbench/build.py build/SPEC4
```

The packager reads the pinned WORDS.BIN from specialists/models and verifies its digest from entry.json. BUILD.BAT compiles the SPEC4 executable using TP7. For host testing build EXPERT.PAS with FPC using -B -dSPEC4. Pass its executable, the expanded SPEC4 directory and the expanded general-model FLOPPY3 fixture to score.py. CHECK.BAT in the package exercises a switch to expert 41 and prints the available heap.

The no-FPU DOSBox-X smoke answered “define fragile” with “Easily broken.” and reported 48,312 bytes of free heap. Physical Pocket386 measurements remain pending. [No-FPU transcript](NOFPU.LOG)

The shipped TP7 executable matched all 24 AUTO answers under DOSBox-X with FPU enabled and requested clarification for both an unknown word and a mixed-domain query. [DOS input](ALL.IN) · [DOS transcript](ALL.LOG)
