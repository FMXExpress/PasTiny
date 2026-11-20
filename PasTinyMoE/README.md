# PasTinyMoE for DOS

PasTinyMoE runs one complete TNY2 network at a time on a 386 with conventional memory. Both editions ship the same 30,320-byte real-mode Turbo Pascal 7 executable with integer assembly inference and built-in software floating point.

| Download | Runtime bytes before ZIP compression | Contents |
|---|---:|---|
| [FLOPPY3.ZIP](dist/FLOPPY3.ZIP) or [FAT12 data disk image](dist/FLOPPY3.IMG) | 1,176,377 | Three model files |
| [SD100.ZIP](dist/SD100.ZIP) | 38,218,349 | 100 model files, 38,180,800 bytes of weights |
| [Comparison builds](dist/COMPARE.ZIP) | | Pure Pascal integer, float and debug executables |

**Ten trained pilot specialists are available.** [SPEC10.ZIP](dist/SPEC10.ZIP) adds [Synonyms, expert 046](specialists/synonyms/). [SPEC9.ZIP](dist/SPEC9.ZIP) adds [Punctuation, expert 045](specialists/punctuation/). [SPEC8.ZIP](dist/SPEC8.ZIP) adds Spelling Helper, Confused Words and Grammar Terms. See the [word desk results](specialists/worddesk/) and [100-expert plan](docs/expert-plan.md). The [five-expert SD package](dist/SPEC5.ZIP) adds [PC Workbench](specialists/pcbench/) for 386 hardware questions. The [four-expert SD package](dist/SPEC4.ZIP) adds [Word Bench, expert 041](specialists/wordbench/), covering eight common adjectives. In the three-expert floppy edition, DOS Guide, Turbo Pascal Coach and Pocket Naturalist each cover four facts. Download [SPEC3.ZIP](dist/SPEC3.ZIP) or the [specialist floppy image](dist/SPEC3.IMG). See the [syllabi and evaluation](specialists/README.md). FLOPPY3 and SD100 in the table above are the original capacity fixtures. The five-bank shared-core edition is deferred.

The [expert plan](docs/expert-plan.md) defines the proposed scopes, routing behavior and training order. The first three planned specialists are DOS Guide, Turbo Pascal Coach and Pocket Naturalist.

## Running it

Extract either runtime ZIP into its own new DOS directory, change to that directory and run `EXPERT`. Use `LIST`, `USE 2`, `AUTO`, `MEM` or `QUIT`. Escape during an interactive answer cancels generation. Redirected input takes one command or question per line. A successful USE pins the model. AUTO routes the word “capital” to fixture 2 and “times” to fixture 3. A tie or unknown word selects the first catalog entry.

The loader streams 4 KiB at a time into fixed allocations, checks shape, exact size, finite scale/gain fields and CRC32, then marks the new model ready. The same ID reuses the loaded network. Each question starts at position zero and overwrites every cache position before attending to it. A failed replacement reloads the previous file; failed recovery leaves the runtime unloaded.

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

### PasTinyMoE sixty-expert edition

[Download SPEC60 for DOS](dist/SPEC60.ZIP) or inspect the [expert list and evaluation results](specialists/batch60/README.md).

[Accuracy and example questions for all 60 experts](specialists/batch60/scorecard.md)
