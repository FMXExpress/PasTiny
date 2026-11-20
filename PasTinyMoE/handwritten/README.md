# Hand-written networks

Networks in the TINY 2.1 file format whose weights were written by hand instead of trained. Each one is an ordinary 381,808-byte `TNY2` model that the stock PasTinyMoE programs load and run like any trained expert.

The idea comes from work on "weight-space programming", and in particular from Lex Toumbourou's observation in [Weight-Space Programming builds neural networks like a 1990s researcher](https://notesbylex.com/weight-space-programming-1990s) that a model writing weights from scratch is really compiling a classical algorithm into them. That suits tasks with an exact algorithm, where a small trained model memorises examples and fails on anything new.

| Folder | Models | What they do |
| --- | --- | --- |
| [`reverse/`](reverse/) | `REVERSE.BIN` | Spells the last word of the question backwards |
| [`cipher/`](cipher/) | `ROT13.BIN`, `ATBASH.BIN`, `ECHO.BIN` | Write the last word forwards through a letter substitution |
| [`compare/`](compare/) | `BIGGER.BIN`, `SMALLER.BIN` | Say whether the first number in the question is bigger (or smaller) than the second |
| [`add/`](add/) | `PLUS.BIN` | Adds two whole numbers from 0 to 99 |
| [`rules/`](rules/) | `DIGIT.BIN`, `QMARK.BIN`, `EXCLAIM.BIN` | Exact yes/no rules for PasTinyJev |

[`conformance.py`](conformance.py) uses the first four folders to check any engine build against answers known by construction. [`tny2.py`](tny2.py) holds the shared pieces: weight arrays, phase tables, the ReLU square and the file writer.

## Reverse

[`reverse/REVERSE.BIN`](reverse/REVERSE.BIN) spells the last word of the question backwards. [`reverse/build.py`](reverse/build.py) writes every weight; it needs NumPy only and uses no training and no data. 8,390 of the 366,528 weights are non-zero.

```
> reverse jumped
depmuj
> reverse Hello-World_42!
!24_dlroW-olleH
```

How it works, with n the position where the question ends and p the current position:

1. **Layer 1 attention** looks back at the end-of-question token and reads a table entry that encodes 2n-1.
2. **Layer 1 feed-forward** subtracts its own position to get 2n-1-p, the position of the next letter to output. Positions are held as phases (cosine and sine at four frequencies), so the subtraction needs products. Each product is built from squares, and each square from 14 ReLU pieces.
3. **Layer 2 attention** looks at exactly that question position and copies its letter to the output.
4. **Layer 2 feed-forward** emits the end token when the target position falls before the start of the question. A copied space also ends the answer, so only the last word is reversed.
5. **Layers 3 and 4** are all zero.

Phases are used because the runtime stores attention keys as 8-bit numbers. Values within -1 to 1 survive that; a position counter would not.

### Results

| Test | Hand-written | Trained `TINY.BIN` |
| --- | ---: | ---: |
| 600 dictionary words from TINY's training vocabulary | 600/600 | 557/600 |
| Made-up words of 4, 6, 8, 10 and 12 letters, 100 each | not run | 6, 0, 0, 0, 0 |
| 330 random strings of 1 to 55 printable characters | 330/330 | not run |

The first two rows were measured in PyTorch on the 8-bit weights with the TINY 2.1 training kit, asking the trained model "spell X backwards"; that harness is not in this repository. The third row is what [`reverse/test.py`](reverse/test.py) checks through the stock integer engine.

### Run and verify

On a host, from `PasTinyMoE`:

```sh
fpc -Mtp -B -FEbuild EXPERT.PAS
python3 handwritten/reverse/test.py build/EXPERT
```

The test rebuilds the model and requires it to match the committed file, packages it beside the general model with the catalog keyword `reverse`, and asks through the unmodified runtime. To package it yourself, give `tools/package.py` a manifest with `REVERSE.BIN` and the keyword `reverse`.

On DOS, the unmodified Turbo Pascal 7 `bin/EXPERT.EXE` ran that two-model catalog in DOSBox-X. [`reverse/evidence/FPU.LOG`](reverse/evidence/FPU.LOG) has the run with an emulated FPU, where ordinary questions still go to the general model. [`reverse/evidence/NOFPU.LOG`](reverse/evidence/NOFPU.LOG) is one question on an emulated 386 without an FPU: about 4.3 seconds at `cycles=max`, which is an emulator setting and not a hardware prediction.

### Limits

- The word must be the last word of the question. "spell jumped backwards" would reverse "backwards".
- Question and answer share the 128-position context, so the question can be at most 63 characters.
- It is not in the SPEC100 catalog or its topic rules. Routing here uses the plain keyword router.
- Only this one task has been written. Counting letters, comparing numbers and similar exact tasks should suit the same approach; facts and fuzzy judgement do not.

## Ciphers and echo

[`cipher/build.py`](cipher/build.py) writes three networks that answer with the last word of the question, read forwards, with each letter passed through a fixed substitution. Capital letters are read as small letters; digits and punctuation pass through.

```
> rot13 hello
uryyb
> atbash wizard
draziw
> echo jumped
jumped
```

Reading forwards needs the position where the last word starts, which reverse never needed. With n the end of the question, s the start of the last word and p the current position:

1. **Layer 1 attention** looks at the latest space, or at position 0 when there is none, and reads a table entry encoding s. A space always beats a letter, and among spaces the later one wins, using a position counter that takes exactly one 8-bit step per position.
2. **Layer 1 feed-forward** subtracts its own position, which at the end of the question gives s-n.
3. **Layer 2 attention** lets every answer position fetch that from the end-of-question token.
4. **Layer 2 feed-forward** adds its own position: s-n+p, which walks s, s+1, s+2 and so on as the answer is written.
5. **Layer 3 attention** copies the letter at that position through the substitution. When the walk reaches the end-of-question token, copying it ends the answer.

Each letter has its own dimension, so any substitution is an exact permutation in the copy step; the three files differ only there. [`cipher/test.py`](cipher/test.py) rebuilds the models, requires a byte match, and asks 726 questions through the stock runtime: random words of 1 to 40 printable characters after zero to two lead-in words, and questions with no space at all.

## Number comparison

[`compare/build.py`](compare/build.py) writes two networks that read two whole numbers from the question, A then B, and answer `yes` or `no`. The wording around the numbers does not matter. Numbers are compared digit by digit, so size is not limited by arithmetic precision.

```
> is 842 bigger than 837
yes
> is 99999999999 bigger than 100000000000
no
> which is smaller 100 or 99
no
```

This one uses all four layers:

1. **Layer 1 attention**, two heads at every position: the latest non-digit, which gives the start of the number a digit belongs to, and the earliest digit, which gives the start of A.
2. **Layer 1 feed-forward** works out each digit's place in its number, counted from its start.
3. **Layer 2 attention**, three heads: each digit of B looks at the digit of A in the same place; and, at the end of the question, the last digit of B and the last digit of A, whose places give the two lengths.
4. **Layer 2 feed-forward** marks, on each digit of B, whether A's digit is larger or smaller, and at the end of the question works out the difference in length.
5. **Layer 3** finds the earliest place where the digits differ and clips both results to -1, 0 or +1.
6. **Layer 4 feed-forward** decides: a longer number wins, and with equal lengths the first differing digit decides. It also spells the answer: after `y` comes `e`, then `s`; after `n` comes `o`.

| Test, 1,200 pairs of 1 to 12 digits | Hand-written | Trained `TINY.BIN` |
| --- | ---: | ---: |
| "Bigger" questions | 1,200/1,200 | 648/1,200 |
| "Smaller" questions | 1,200/1,200 | not run |

The pairs are chosen to be hard: equal numbers, numbers differing in one digit at a random place, numbers one digit longer or shorter, neighbours, and unrelated numbers, in six wordings. [`compare/test.py`](compare/test.py) runs them through the stock runtime and checks each answer against Python's own comparison; `--general` adds the trained model's score. The integer, `NOASM`, `FLOATMATH` and `DEBUG` host builds all answer every pair exactly.

Getting this exact in the 8-bit runtime took three changes, each after a failure:

- Picking "the latest digit" with a large constant times an "is a digit" flag failed once later layers had written uneven amounts into the residual. A feed-forward layer now makes position values that are already zero off the digits.
- Ranking positions with one counter failed because 8-bit rounding of the tables makes each position's overall size wobble by about 0.1%, which the large constants amplified. Position is now ranked by a coarse counter (blocks of eight) and a fine one (within the block), stored as exact 8-bit multiples.
- Matching "same start as the first number" was noisy because each key is rounded on its own scale. A constant entry larger than everything else now fixes that scale.

Limits: a number may not be the very first thing in the question; the question may be at most 72 characters; numbers are plain digits without signs, points, separators or leading zeros; and a question with more than two numbers is not supported (the answer mixes them).

## Addition

[`add/build.py`](add/build.py) writes a network that adds two whole numbers from 0 to 99 and writes the sum normally, most significant digit first.

```
> what is 20 plus 17
37
> what is 58 plus 67
125
```

The first digit written depends on the carries from the lower places, and each carry needs its own layer:

1. **Layer 1** finds which number each digit belongs to, where the first number starts, and whether the answer has begun.
2. **Layer 2** fetches the two units digits, adds them, and works out the units digit of the sum and the first carry.
3. **Layer 3** fetches the two tens digits (zero if a number has none), adds them with the carry, and works out the tens digit and the second carry.
4. **Layer 4** chooses which digit to write at this step of the answer, or ends it.

How far into the answer we are is passed along one step per layer: "the previous position is the end of the question", then "the position before had that flag", and so on.

| Test | Hand-written | Trained `TINY.BIN` |
| --- | ---: | ---: |
| Every pair from 0 to 99, in six wordings | 10,000/10,000 | not run |
| "what is A plus B" on 1,000 of those pairs | 1,000/1,000 | 61/1,000 |

[`add/test.py`](add/test.py) asks all 10,000 pairs through the stock runtime; the integer, `NOASM`, `FLOATMATH` and `DEBUG` host builds all answer every one exactly.

Two digits is what fits exactly in four layers. A third place needs its carry and the choice of which digit to write in the same last layer, and the one-bit flags passed between layers are only within a few percent of 1 when read later, which is not enough to gate that safely. Three more lessons from making this exact:

- Flags are kept small in the residual. At full size, a flag that is on changed that position's overall size by a few percent and upset the choice of "the latest digit" two layers later.
- Each gated copy is the difference of two units that share the gate, with a little slack, so the gate's error cancels.
- "The last digit of A" is chosen by matching the number's start, which the space before A matches too. That selection now also requires a digit.

Limits: a number may not be the very first thing in the question; at most 72 characters; exactly two numbers of one or two plain digits, without a leading zero.

### As a starting point for training

One idea was that a hand-written network could give training a head start. It does not: starting from `PLUS.BIN` is worse than starting from random weights.

The task was "what is A plus B" for A and B from 0 to 999, which is one digit more than `PLUS.BIN` was built for. Each run trained for 6,000 steps of 128 questions. Scores are exact answers on pairs never trained on, at the end of the run.

| Start | Learning rate | Both numbers below 100 (of 500) | A number of 100 or more (of 1,000) |
|---|---:|---:|---:|
| Random weights | 0.001 | 494 | 980 |
| Random weights | 0.0003 | 495 | 946 |
| Trained `TINY.BIN` | 0.001 | 500 | 977 |
| Trained `TINY.BIN` | 0.0003 | 494 | 977 |
| `PLUS.BIN` | 0.001 | 74 | 21 |
| `PLUS.BIN` | 0.0003 | 24 | 21 |
| `PLUS.BIN` | 0.0001 | 3 | 2 |
| `PLUS.BIN` | 0.00003 | 455 | 45 |

`PLUS.BIN` starts at 500 of 500 on the smaller pairs. At the three larger rates training destroys that within 500 to 2,000 steps and never recovers. At the smallest rate the circuit mostly survives (455) but almost nothing new is learned (45). The trained general model is the best start: after 500 steps at rate 0.001 it has 729 of 1,000 where random weights have 405, and the two are level by the end.

The likely cause, which was not tested, is that hand-written weights are extreme: large constants, saturated units and many all-zero rows, which leave gradients badly scaled and give zeroed units no signal.

Each row is one run with one seed, so the small differences among the random and `TINY.BIN` rows mean little. Training and scoring were in floating point in PyTorch, not in the 8-bit runtime, and no trained model was exported. [`add/training_start.py`](add/training_start.py) is the script and [`add/training_start.json`](add/training_start.json) has the scores every 500 steps.

## Exact rules for PasTinyJev

[`rules/build.py`](rules/build.py) writes three one-layer networks for [PasTinyJev](../../PasTinyJev/), which reads a decision as the score of the letter y minus the letter n. Each answers one fixed rule with a probability near 1 or near 0: the text contains a digit, a question mark, or an exclamation mark.

```
STATE Where is my order 4412? It was due Friday!
NOUL a | does the text contain a digit        ->  a noul=0.9998
STATE thanks, all good now
NOUL a | does the text contain a digit        ->  a noul=0.0002
```

They sit in the PasTinyJev catalog beside the trained triage model with the keywords `digit`, `question mark` and `exclamation mark`; an instruction containing one of those goes to the rule, and everything else to the trained model. [`rules/test.py`](rules/test.py) checks 900 random states. The rule looks at the whole read, state and instructions together.

## Engine conformance

The trained models can only show that two engine builds agree with each other. These networks have answers known by construction, so a build can be checked against the truth. [`conformance.py`](conformance.py) asks 93 fixed questions, including the longest the context allows, where attention must land on exact positions through the 8-bit key cache, number comparisons that rank positions one step apart, and sums with every pattern of carry.

```sh
python3 handwritten/conformance.py build/EXPERT            # any host builds
python3 handwritten/conformance.py --write DIR             # package for a DOS EXPERT.EXE
python3 handwritten/conformance.py --check CONFORM.LOG     # check its transcript
```

All four host builds (integer, `NOASM`, `FLOATMATH`, `DEBUG`) answer all 93 exactly.

So do the four DOS executables in this repository, run in DOSBox-X with an emulated FPU: `bin/EXPERT.EXE` (integer with assembly) and the pure Pascal, float and debug builds from `dist/COMPARE.ZIP`. Their transcripts are in [`evidence/`](evidence/) as `CONF-ASM.LOG`, `CONF-NOASM.LOG`, `CONF-FLOAT.LOG` and `CONF-DEBUG.LOG`. Two comparison questions were also run on an emulated 386 without an FPU ([`evidence/COMPARE-NOFPU.LOG`](evidence/COMPARE-NOFPU.LOG), about 4.9 seconds each at `cycles=max`), and so was one sum, "what is 58 plus 67" ([`evidence/PLUS-NOFPU.LOG`](evidence/PLUS-NOFPU.LOG), 4.1 seconds). The full set has not been run without an FPU, and the other engines (the C original, the browser port, the Delphi ports) have not been tried.
