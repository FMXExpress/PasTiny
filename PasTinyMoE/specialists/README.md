# Three trained PasTinyMoE specialists

[Download the DOS runtime ZIP](../dist/SPEC3.ZIP) or [download the 1.44 MB FAT12 image](../dist/SPEC3.IMG). Extract the ZIP into a fresh DOS directory and run EXPERT. Type LIST to see the models, USE 2 to pin Turbo Pascal Coach, or AUTO to resume keyword routing. CHECK.BAT exercises all three. The runtime loads one 381,808-byte model at a time.

| Specialist | ID | Four facts in the pilot | Manual selection | AUTO | Original general model |
|---|---:|---|---:|---:|---:|
| DOS Guide | 1 | DIR, CD, CLS, TYPE | 6/8 | 6/8 | 0/8 |
| Turbo Pascal Coach | 2 | div, mod, begin, end | 5/8 | 5/8 | 0/8 |
| Pocket Naturalist | 51 | Adult insect and spider leg counts and main body divisions | 8/8 | 8/8 | 0/8 |

Each cell counts exact answers on eight unseen wordings of the four trained facts, using greedy generation in a host build of the Pascal runtime. Each fact has one domain-tagged probe and one bare question. AUTO matches whole words from the three pilot syllabi. With zero or multiple matching domains it asks the user to select an expert. IDs 1 and 2 are provisional pilot assignments pending the missing catalog rows. [Paired router benchmark and DOS timing](routing/README.md)

The original model was scored with its own weights on the identical prompts. Exact string matching includes capitalization and punctuation. The sample is small and measures rewording within this syllabus. For example, the Pascal specialist sometimes answered “div.” for a remainder. The no-FPU DOS smoke also reproduced this mistake. The answer-level records include every miss. [Current router results](routing/after.jsonl) · [Initial pilot results](evidence/answers.jsonl)

## Fact sources and data

The JSONL files contain original short prompts written for this pilot. The fact field links each paraphrase to one of the twelve facts in the table. Each specialist has 36 development examples formed from three wordings per fact, each used bare and with two domain cues. The trainer assigned 33 to fitting and three to validation. The separate eight-question held-out file was fixed before fitting. The splits share target facts by design.

- DOS command meanings were checked against Microsoft's command references and exercised in the DOSBox-X shell. Scope is the basic command behavior. [DIR](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/dir) · [CD](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cd) · [CLS](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cls) · [TYPE](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/type)
- The Pascal probe compiled and ran under Borland TP7. Its nested compound statement and integer expressions exercise all four facts. [Probe](evidence/PROBE.PAS) · [Output](evidence/FACTS.LOG)
- Adult insect facts follow the six legs and three body regions described by OpenStax. Spider facts use eight walking legs and two main body divisions. [OpenStax Biology 2e, Arthropods](https://openstax.org/books/biology-2e/pages/28-6-superphylum-ecdysozoa-arthropods) · [Spider anatomy](https://en.wikipedia.org/wiki/Spider) · [San Diego Zoo Wildlife Alliance](https://animals.sandiegozoo.org/animals/tarantula)

## Reproduction

Run from PasTinyMoE with Python 3.12, CPU PyTorch 2.15.0 and WEBTINY set to a checkout at a1a36720ed558d6998e5beed9d4dbdd792626056. All three models started independently from the original TINY.BIN. Each run used the WebTiny trainer's default seed 42 and 10% validation split. [Pinned trainer](https://github.com/FMXExpress/WebTiny/blob/a1a36720ed558d6998e5beed9d4dbdd792626056/training/train.py)

```sh
for model in DOS PASCAL NATURE; do
  python "$WEBTINY/training/train.py" --init TINY.BIN \
    --data "specialists/data/$model-train.jsonl" --steps 320 \
    --batch-size 8 --threads 2 --lr .0003 --out "build/models/$model.BIN"
done
python specialists/build.py build/SPEC3
tools/floppy.sh build/SPEC3 build/SPEC3.IMG
```

The packager reads the pinned exports in specialists/models and verifies their hashes against manifest.json. To replay scoring, supply a native EXPERT executable, the unpacked specialist runtime and the unpacked FLOPPY3 baseline fixture directory to specialists/score.py. Input data, full training logs, model SHA-256 values and per-question outputs are committed. The FAT12 package passed a byte-for-byte file copy-back check. Physical Pocket386 measurements are pending.

The released TP7 executable reproduced all 24 manually routed host outputs under DOSBox-X with the emulated FPU enabled. Its separate no-FPU smoke loaded each specialist, answered one question per model, and ended with 49,160 bytes free. [Full TP7 transcript](evidence/TP7-ON.LOG) · [No-FPU smoke](evidence/TP7-OFF.LOG)
