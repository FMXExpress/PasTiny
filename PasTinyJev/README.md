# PasTinyJev

Typed decisions from a TINY 2.1 network, in real-mode DOS. Give it a state and typed
questions (yes/no, choice, score) and it returns a probability for each answer, in the style of
TypeSafe's [Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev) and
[OpenJev](https://github.com/razorback16/openjev). It reads the answers from the network's
scores and generates no text, so an answer cannot be off-schema.

- Same engine as [PasTinyMoE](../PasTinyMoE/): Turbo Pascal 7, integer inference with the
  assembly dot product, built-in software floating point, one model resident at a time.
- Same model format: every model is a 381,808-byte `TNY2` file (96 wide, 4 layers, 4 heads,
  128 letters of context). The whole edition is 804,207 bytes and fits on a 1.44 MB floppy.
- One trained decision model, `TRIAGE.BIN`, for short customer-support messages. The unchanged
  TINY 2.1 model rides along as `GENERAL.BIN` for text answers.

PasTinyJev is an independent experiment. It is not affiliated with or endorsed by TypeSafe AI
or OpenJev.

## What it can and cannot do

`TRIAGE.BIN` has 367,000 parameters. It was trained on a CPU in two steps: one hour on synthetic
template messages, then 45 minutes of distillation from a local OpenJev server running the
[Laya](https://github.com/NandhaKishorM/laya) model (421M parameters) as the teacher. Measured
on the exported 8-bit model, before and after distillation:

| Test | Templates only | Distilled (shipped) |
|---|---:|---:|
| Agrees with the teacher on 1,500 questions about real messages never trained on | 57.7% | 80.7% |
| Mean probability gap to the teacher on those questions | 0.286 | 0.095 |
| 40 hand-written questions ([`training/wild.jsonl`](training/wild.jsonl)) | 30 | 31 |
| Trained template wordings: yes/no, choice, score | 100.0 / 100.0 / 99.7% | 99.5 / 100.0 / 98.2% |
| New template messages, trained question words | 89.9 / 77.6 / 92.2% | 87.6 / 73.1 / 89.0% |
| Trained template messages, new question and option words | 71.9 / 60.9 / 21.5% | 67.8 / 70.0 / 54.4% |

- Distillation helped most where the first model was weakest: real messages (banking and
  support requests it never saw) and option or level words outside its training list.
- The hand-written set is essentially unchanged, 31 of 40 against 30 (15 of 19 yes/no, 12 of 14
  choice, 4 of 7 score). It was written before any training and never used to change the model,
  the generator or the question pool. The teacher itself gets 34 of 40 on it.
- Confidence is more honest than before but still not reliable: some hand-written misses come
  with 0.99 for the wrong answer.
- It is not a general reasoner and does not follow arbitrary instructions the way Jev does. It
  knows short customer-support and banking messages.

The teacher is OpenJev's CPU-capable Laya backend. OpenJev's main model, DiffusionGemma 26B,
needs a 24 GB GPU and was not used; a stronger teacher or more labelled data should help
further.

## Run on DOS

Extract [`dist/JEV1.ZIP`](dist/JEV1.ZIP) into a DOS directory, or write
[`dist/JEV1.IMG`](dist/JEV1.IMG) to a 1.44 MB floppy. Needs a 386 and about 570 KB of free
conventional memory. A coprocessor is optional.

```dos
JEV
JEV < DEMO.IN
```

```
STATE Everything is down and we have a demo with our biggest client at noon.
NOUL urgent | Does the customer need a reply within the hour?
CHOICE team | Which team should handle it? | outage=service down ; billing=charges, refunds ; feature=requests, how-to
SCORE tone | How upset is the customer? | calm ; annoyed ; furious
```

```
state chars=70
urgent noul=0.6720
team choice=outage confidence=0.4602 outage=0.8169 billing=0.0617 feature=0.1213
tone score=0.2011 confidence=0.5206 0=0.8441 1=0.1106 2=0.0453
```

| Command | |
|---|---|
| `STATE text` | Sets the state. A longer state keeps its first 53 and last 26 letters. |
| `NOUL id \| instructions` | Yes/no. Answers `noul=` P(yes). |
| `CHOICE id \| instructions \| name=description ; ...` | Answers the best name, `confidence=` and a probability per name. |
| `SCORE id \| instructions \| level ; level ; ...` | Answers `score=` the expected level from 0, `confidence=` and a probability per level. |
| `ASK question` | Text answer from the general model. |
| `LIST`, `USE id`, `AUTO`, `MEM`, `QUIT` | Catalog, pin one model, automatic model choice (default), free memory, leave. |

`confidence` is `1 − H(p)/ln K`, as in OpenJev. Each answer ends with `ms=`, the time taken.
State, instructions and the longest option must fit in 127 letters together; a question that
does not fit answers `error=too long by N`. A command line holds 255 letters and 24 options.
[`README.TXT`](README.TXT) is the short DOS manual that ships in the ZIP.

## How a decision is read

```
noul            state|instructions<end>          -> score of "y" minus score of "n"
choice, score   state|instructions:option<end>   -> the same, once per option, then a softmax
```

- The network is causal and keeps a key/value cache. `JEV` feeds the state once; each question
  rewinds to the end of the state and costs only its own letters. Options of one question share
  the instructions too.
- A choice is one yes/no read per option, so the model never has to tie a letter to an option.
- The engine change is two procedures in [`TNYNET.PAS`](TNYNET.PAS), `Feed` and `YesNo`. The
  loader, CRC check, integer arithmetic and assembly are PasTinyMoE's, unchanged.
- The catalog is PasTinyMoE's `EXPERTS.CAT`. An entry with the keyword `ask` is a text model; it
  answers `ASK` and never a decision. Any other keyword routes decisions whose instructions
  contain that word to that model, so more decision specialists can be added without code.

## Build and verify

Host build and tests need Free Pascal 3.2.2, Python 3, PyTorch and NumPy:

```sh
fpc -Mtp -B -FEbuild/int JEV.PAS
fpc -Mtp -B -dFLOATMATH -FEbuild/flt JEV.PAS
python3 tests/test_host.py build/int/JEV build/flt/JEV
```

The test checks the command protocol, state caching, model switching, recovery from a damaged
model, and that both engines give PyTorch's probabilities on all 40 hand-written questions. The
largest gap is 0.0072 for the integer engine and 0.0008 for the float engine.

DOS builds use your own `TPC.EXE` and `TURBO.TPL` from Turbo Pascal 7: run `BUILD.BAT`, or
replay everything in DOSBox-X from a host:

```sh
TP7_DIR=/path/to/compiler/bin tests/run_tp7.sh
```

It builds the integer ASM, pure Pascal and float programs, runs the 40 questions through each,
and compares every printed number with the host builds. Then it runs six questions on an
emulated 386 with the FPU disabled. Verified here with DOSBox-X 2024.03.01:

| Build | Size | Result |
|---|---:|---|
| `JEV.EXE`, integer ASM | 36,848 | identical to the host integer build, FPU on and FPU off |
| `JEVNO.EXE`, integer, pure Pascal | 36,912 | identical to the host integer build |
| `JEVFLT.EXE`, float | 35,968 | identical to the host float build |

The three executables are in [`bin/`](bin/) and the transcripts, compiler logs and training log
in [`evidence/`](evidence/).

Not measured or tested: speed at a fixed cycle count, physical 386 hardware, and the Free Pascal
go32v2 build. With the emulated FPU off, the first question of the demo (a 70-letter state and a
45-letter question) took about 56 seconds at DOSBox-X `cycles=max`; that is one emulator
setting, not a hardware prediction.

To package: `python3 tools/package.py bin/JEV.EXE build/JEV1` then
`tools/floppy.sh build/JEV1 build/JEV1.IMG`. [`models.json`](models.json) lists the models.

## Train

```sh
cd training
python3 gen_jev.py                                   # sample states and questions
python3 train_jev.py train 60 base.pt --init ../TINY.BIN
python3 train_jev.py train 45 jev.pt --resume base.pt --distill distill.jsonl.gz --mix 0.6
python3 train_jev.py eval jev.pt --distill distill.jsonl.gz
python3 train_jev.py export jev.pt ../JEV.BIN
```

- [`gen_jev.py`](training/gen_jev.py) composes messages with a known topic, tone and urgency and
  asks typed questions about them. Some labels are soft on purpose. One message core in five and
  one question or option wording in four are held back for the tests above.
- [`train_jev.py`](training/train_jev.py) starts from the TINY 2.1 weights and trains only the
  y-minus-n read: binary cross-entropy for a noul, softmax cross-entropy across the options of a
  choice or score. Targets are probabilities, so a teacher's answer is used as it is.
- [`distill.jsonl.gz`](training/distill.jsonl.gz) holds 29,229 questions with the teacher's
  probabilities: template messages plus real ones from banking77 and Bitext's customer-support
  set. One real message in ten (1,855 questions) is held back for the agreement test.
  [`DATA_LICENSES.md`](DATA_LICENSES.md) has the sources and terms.
- The network code and the `TNY2` export come from
  [WebTiny](https://github.com/FMXExpress/webTiny)'s trainer
  ([`webtiny_train.py`](training/webtiny_train.py), unchanged), which also imitates the runtime's
  8-bit key/value cache during training.
- `jev.pt` is the released model at full precision; exporting it gives the released `JEV.BIN`.

To label more data, run OpenJev locally and point
[`build_distill.py`](training/build_distill.py) at it. It asks eight questions per message
from a wide pool of instructions, option words and scales, at about 12 questions a second on
four CPU cores:

```sh
pip install -e "openjev[laya]"                       # in an OpenJev checkout
OPENJEV_BACKEND=laya OPENJEV_DEVICE=cpu OPENJEV_PORT=8081 python -m openjev
python3 build_distill.py 45 distill.jsonl --banking banking77.parquet --bitext bitext.csv
```

## Jev wire API on a host

```sh
python3 tools/serve.py build/int/JEV build/rt --port 8080
curl localhost:8080/v1/systemone -H "Content-Type: application/json" \
  -d '{"model": "jev-latest", "state": "I was charged twice this month.",
       "questions": {"is_billing": {"type": "noul", "instructions": "Is this a billing issue?"}}}'
```

`POST /v1/systemone` takes `{state, model, questions}` and returns `{model, answers, usage}` in
OpenJev's shapes; `GET /v1/models` lists the names. Checked with curl only. The TypeSafe SDK was
not run against it. `usage.input_tokens` counts letters.

## Provenance

Derived from FMXExpress/PasTiny (PasTinyMoE at commit d8bf7e8) and the WollyMonjac/Tiny-2.1
model. `TINY.BIN` is the unchanged general model (SHA-256 4b603237…7095). `JEV.BIN` was trained
here from it, with OpenJev's Laya model as the teacher. The trainer core is from FMXExpress/webTiny under its MIT licence
([`training/WEBTINY_LICENSE`](training/WEBTINY_LICENSE)). See [`NOTICE.TXT`](NOTICE.TXT),
[`ORIGINAL.TXT`](ORIGINAL.TXT) and [`LICENSE`](LICENSE). The Turbo Pascal compiler is not
included.
