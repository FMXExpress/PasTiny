# PasTinyMoE for DOS

[Download SPEC100.ZIP](dist/SPEC100.ZIP) for the complete catalog of 100 trained experts. The 386 real-mode DOS executable loads one 381,808-byte model at a time and supports a machine without a coprocessor. The ZIP includes all models, the catalog and the runtime in DOS 8.3 format.

Extract the ZIP into a new directory on your DOS drive. Run `EXPERT`, type `LIST` for IDs or ask a question. For manual selection type `USE 2` (Turbo Pascal Coach). Type `AUTO` to resume automatic routing or `QUIT` to exit.

The default interactive DOS screen shows the conversation, the loaded expert, live layer activity, character confidence, generation speed and whether routing is automatic or pinned. Press Up to recall the last input, F1 for help, F9 to save `SCREEN.DMP` or Esc at the prompt to exit. The `LIST` command pages through the catalog. Run `EXPERT /P` for the plain console. Redirected input or output also uses the plain console for scripts and benchmarks. [Screenshot](../docs/screenshots/moe-neon.png)

**SPEC100 AUTO falls back to the original Tiny model when no expert matches.** Replaying the original 60 questions under DOS raised exact matches from 3/60 to 50/60. Tiny answered all 47 unmatched questions correctly. Specialists handled the other 13 and answered three correctly.

On 1,381 in-scope evaluation prompts, automatic routing selected the intended expert 1,381 times and generated 1,159 exact answers. The questions use new wording for topics covered in training. [Per-expert scores, examples and comparison with original Tiny](specialists/batch100/scorecard.md)

## Capacity fixtures and earlier editions

| Download | Runtime bytes before ZIP compression | Contents |
|---|---:|---|
| [FLOPPY3.ZIP](dist/FLOPPY3.ZIP) or [FAT12 data disk image](dist/FLOPPY3.IMG) | 1,176,377 | Three model files |
| [SD100.ZIP](dist/SD100.ZIP) | 38,218,349 | 100 model files, 38,180,800 bytes of weights |
| [Comparison builds](dist/COMPARE.ZIP) | | Pure Pascal integer, float and debug executables |

**Earlier specialist editions.** [SPEC10.ZIP](dist/SPEC10.ZIP) adds [Synonyms, expert 046](specialists/synonyms/). [SPEC9.ZIP](dist/SPEC9.ZIP) adds [Punctuation, expert 045](specialists/punctuation/). [SPEC8.ZIP](dist/SPEC8.ZIP) adds Spelling Helper, Confused Words and Grammar Terms. See the [word desk results](specialists/worddesk/) and [100-expert plan](docs/expert-plan.md). The [five-expert SD package](dist/SPEC5.ZIP) adds [PC Workbench](specialists/pcbench/) for 386 hardware questions. The [four-expert SD package](dist/SPEC4.ZIP) adds [Word Bench, expert 041](specialists/wordbench/), covering eight common adjectives. In the three-expert floppy edition, DOS Guide, Turbo Pascal Coach and Pocket Naturalist each cover four facts. Download [SPEC3.ZIP](dist/SPEC3.ZIP) or the [specialist floppy image](dist/SPEC3.IMG). See the [syllabi and evaluation](specialists/README.md). FLOPPY3 and SD100 in the table above are the original capacity fixtures. The five-bank shared-core edition is deferred.

The [expert plan](docs/expert-plan.md) defines the proposed scopes, routing behavior and training order. The first three planned specialists are DOS Guide, Turbo Pascal Coach and Pocket Naturalist.

## Running it

For the capacity fixtures, extract either runtime ZIP into its own new DOS directory, change to that directory and run `EXPERT`. Use `LIST`, `USE 2`, `AUTO`, `MEM` or `QUIT`. Escape during an interactive answer cancels generation. Redirected input takes one command or question per line. A successful USE pins the model. AUTO routes the word “capital” to fixture 2 and “times” to fixture 3. A tie or unknown word selects the first catalog entry.

The loader streams 4 KiB at a time into fixed allocations, checks shape, exact size, finite scale/gain fields and CRC32, then marks the new model ready. The same ID reuses the loaded network. Each question starts at position zero and overwrites every cache position before attending to it. A failed replacement reloads the previous file; failed recovery leaves the runtime unloaded.

## Exact answers in code

Sums, counting and spelling are things a small network gets wrong and a few lines of code get right. The unit [`TOOLS.PAS`](TOOLS.PAS) recognises such questions and answers them itself, before any model is loaded. The general model says "458 plus 367 is 968."; the tool says "458 plus 367 is 825."

| Kind | Examples |
|---|---|
| Sums | `what is 458 plus 367`, `7 x 8`, `subtract 3 from 10`, `divide 17 by 5`, `one more than 9` |
| One number | `double 17`, `half of 45`, `13 squared`, `square root of 169`, `what number comes after 842` |
| Counting | `count up from 48 to 52` |
| Number words | `write 1234 in words`, `write sixty-one in numbers` |
| Roman numerals | `roman numeral for 1986`, `what number is XIX` |
| Comparison | `is 842 bigger than 837`, `which is smaller 100 or 99` |
| Words | `reverse jumped`, `how do you spell laugh`, `make knives uppercase` |
| Letters | `how many letters in jumped`, `first letter of tear`, `what letter does moon end with` |
| Alphabet | `what comes before r in the alphabet`, `which letter of the alphabet is c` |

Numbers are whole, in digits or in words, and results must fit in 32 bits. A question the unit does not recognise for certain goes to a model as before. A tool answer is marked on its timing line: `answer ms=0 chars=20 tool`.

`TOOLS ON` and `TOOLS OFF` switch it. It starts on at the keyboard and off when input is redirected, so existing transcripts and regressions are unchanged. `USE n` also bypasses it, because that asks for one model's own answer.

Measured on the 780 held-out questions of the TINY 2.1 training kit, with the general model alone and then with the tools on:

| | Questions | Model alone | With tools | Answered by a tool |
|---|---:|---:|---:|---:|
| Numbers | 60 | 43 | 59 | 53 |
| Squares, roots, Roman numerals | 60 | 38 | 60 | 60 |
| Letters and spelling | 60 | 48 | 59 | 54 |
| The other nine kinds | 600 | 352 | 352 | 0 |
| All | 780 | 481 | 530 | 167 |

Every one of the 167 tool answers was right. The one numbers question still counted wrong is "651 is larger." where the reference says "bigger". None of the 600 other questions set a tool off.

`python3 tests/test_tools.py ./EXPERT` checks 33 exact answers, 10 questions that must be left to the models, and the off-by-default rule, with a host build. Under DOS, a Turbo Pascal 7 build ran [`evidence/tools/TOOLS.IN`](evidence/tools/TOOLS.IN) in DOSBox-X with an emulated FPU ([`FPU.LOG`](evidence/tools/FPU.LOG)) and on an emulated 386 without one ([`NOFPU.LOG`](evidence/tools/NOFPU.LOG)). The unit adds about 18 KB to the executable (30,320 to 48,624 bytes in the plain build) and leaves the free heap after loading a model unchanged at 30,872 bytes. The executables in `bin/` and `dist/` were built before this unit and do not contain it; run BUILD.BAT to get it.

## Rebuild and package

Use your own TPC.EXE and TURBO.TPL from Borland Turbo Pascal 7 on DOS. Run BUILD.BAT from this directory. EXPERT.EXE is the integer/ASM build. EXPNO.EXE, EXPFLT.EXE and EXPDBG.EXE are alternatives. The program uses far callbacks, a 16 KiB stack and TP7 software emulation. The compiler stays on the development machine.

To replay the full target regression on a host, set TP7_DIR to your compiler directory and DOSBOX_X to a DOSBox-X executable, then run `tests/run_tp7.sh`. It creates an isolated build directory and records FPU-on and no-FPU transcripts.

On a host, run the following from this directory with fresh output paths.

```sh
python3 tools/package.py bin/EXPERT.EXE build/FLOPPY3 --fixtures 3
python3 tools/package.py bin/EXPERT.EXE build/SD100 --fixtures 100
tools/floppy.sh build/FLOPPY3 build/FLOPPY3.IMG
```

The supplied image was formatted and copied back out with dosfstools and mtools. Every extracted file matched its source byte for byte. For the host regression, extract dist/FLOPPY3.ZIP into dist/FLOPPY3/, build with `fpc -Mtp -B EXPERT.PAS` and run `python3 tests/test_runtime.py ./EXPERT`.

## Formats and specialist inputs

EXPERTS.CAT starts with ASCII PEC1, a one-byte record count (1–128), and exactly that many packed 68-byte records. Each record contains a unique one-byte ID (1–128), a Pascal short string for an uppercase local BIN filename (12 bytes maximum), title (28), keyword (20), and an IEEE CRC32 as a little-endian 32-bit integer. Each short string occupies one length byte plus its full padded capacity. All model files use the pinned 381,808-byte TNY2 layout, width 96, four layers, four heads and hidden dimension 256.

To package distinct exports, pass `--manifest experts.json` in place of `--fixtures`. Each JSON array entry has id, name, title, keyword, source and sha256 fields. Source paths are relative to the working directory. The host packager verifies the full SHA-256 before copying.

The optional host trainer uses coordinate search on the final 96 RMS gains, leaving all other weights fixed. It scores greedy outputs through the native runtime and exports a complete BIN when the validation score improves. Run `python3 tools/train.py HOST_EXE BASE.BIN train.json validation.json NEW.BIN`. Each split manifest specifies file, sha256, source, authorization and split. The referenced JSONL contains question, answer and integer expert ID. Training and validation questions must be disjoint. Archive the printed training report with the export. No training job was run against the reference questions.

For held-out evaluation, freeze the weights and catalog first. Run `python3 tools/evaluate.py HOST_EXE RUNTIME_DIR heldout.json` to capture per-question oracle, auto and baseline results. The baseline is catalog ID 1. Include held-out paraphrases, ambiguous and unrelated prompts in authorized evaluation inputs. Latency from this command measures the host executable.

## Physical Pocket386 acceptance

Copy the ZIP contents to a new versioned directory on the card, such as PEX001. Run CHECK.BAT there and retain CHECK.LOG with the machine model, clock, FPU configuration and DOS version. The script runs two consecutive same-model queries, changes models and prints heap measurements. On a spare copy, temporarily rename E003.BIN to E003.SAV, run CHECK.BAT again and save its log under another name, then restore the file. Run EXPERT interactively and press Escape during an answer. Record cold launch with a stopwatch and verify the next query works. Physical hardware and an SD card were unavailable here.

## Provenance

Derived from FMXExpress/PasTiny commit 619052aab899ad837b003093752bc36008558eff and its WollyMonjac/Tiny-2.1 model. The general model SHA-256 is 4b603237070ad9084433537bf8d6c7470d0fc583e6a4f1f03c00cd17264e7095. See ORIGINAL.TXT, LICENSE and the parent project's attribution for upstream material. See [validation records](evidence/) for compiler logs, runtime transcripts and emulator settings.

The production TP7 build matched all 60 reference answers in DOSBox-X with the emulated FPU disabled. With the FPU enabled, each of the integer/ASM, NOASM and float builds matched 60/60. Free heap and largest free block both stayed at 49,160 bytes across 300 switches. [Transcripts, memory observations and timing results](evidence/README.md)

Pass `--report summary.json` to the evaluation command to record the held-out results and SHA-256 hashes of the corpus, host executable, catalog and model files. Use a manifest split of `test` or `heldout`. An optional `group` on each JSONL row identifies a slice such as ambiguous or out-of-domain. Each mode reports sample count, exact answers, intended-expert selections and median host answer time overall and by group. Select a different general model with `--baseline ID`. Redirect stdout to a JSONL file to keep every question and answer alongside the summary.

## Typo fallback in automatic routing

When the topic rules claim no expert, the router looks for a word of six or more letters that is one typing slip (a letter changed, added, dropped, or two neighbours swapped) from a topic term of seven or more letters. If the slips point to a single expert, the question is routed with the term corrected, the program prints `read as:` with the corrected question, and the expert answers that. Routes chosen by the rules are never changed. Shorter terms are left alone because ordinary words sit one letter from them, such as state and slate. The Spelling Helper's terms are skipped as well: they are misspellings, so the correct word is always one slip away.

[tests/route_probes.tsv](tests/route_probes.tsv) holds 321 probe questions. 320 were written before either router was run on them: two freshly worded questions and one with a typo for each of the 100 experts, and 20 questions outside every expert. One more, about the word "separate", was added after the fallback first sent it to the Spelling Helper. Measured with the SPEC100 build:

| Probes | Rules alone | With the fallback |
| --- | ---: | ---: |
| Fresh wording, term spelled correctly | 198/201 | 198/201 |
| One typo in the key term | 33/100 | 67/100 |
| Outside every expert, asks for a choice | 19/20 | 19/20 |

Seven typo probes go to a wrong expert under both. The fallback routes all 9,818 training and reserved questions of the 100 experts exactly as the rules do, reproduces the 1,312 replayed outcomes, and uses about 1.6 KB of conventional memory. To rerun, build `tests/ROUTEPRB.PAS` with FPC and `-Mtp -B -dSPEC100`, then run `python3 tests/route_probes.py ROUTEPRB RUNTIME_DIR` with an extracted SPEC100 package. `bin/SPEC100.EXE` and `dist/SPEC100.ZIP` include the fallback. They were rebuilt with the Turbo Pascal 7.0 compiler from the TP(WDB) 7.3.5 distribution, whose runtime library adds 32 bytes of code compared with the one used for the other executables; the same source built either way differs only by that. The earlier editions (`SPEC8` to `SPEC90`) and their packages are unchanged and route without the fallback.
