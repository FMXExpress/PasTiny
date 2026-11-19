# PC Workbench

[Download SPEC5.ZIP](../../dist/SPEC5.ZIP) and extract it into a fresh DOS directory on an SD card. Run EXPERT and ask “what does a 387 do”, or select PC Workbench with USE 3. ID 3 is a provisional pilot assignment. LIST shows the four other resident-model choices. Only one complete model occupies the runtime buffers at a time.

The syllabus covers seven jobs on a 386 PC: RAM as powered working storage, ROM as persistent firmware storage, the CPU executing instructions, the 387 performing floating-point arithmetic, disk storage retaining data without power, and serial versus parallel bit transmission. ROM describes a typical firmware use. The references to serial and parallel describe the classic PC interfaces. [Exact syllabus and aliases](syllabus.tsv) · [Intel 80386 documentation](https://www.pcjs.org/documents/manuals/intel/80386/)

### Measured quality

On 21 unseen questions about the seven trained facts, the original general model produced 0 exact answers. PC Workbench produced 14 with manual selection and 14 with AUTO. AUTO selected the intended expert on all 21. Some misses were substantive: for “which job does the cpu perform” the model gave the serial-port answer. Treat the model as a small teaching pilot. The committed output records include all incorrect and malformed answers. [Per-question results](results.jsonl)

The runtime prints TP7's detected coprocessor state for the FPU command and recognized presence questions such as “does my machine have a 387?”. This comes from the runtime's FPUName function. MEM reports the program's free heap. Other recognized installed-hardware questions direct the user to those commands. This is bounded phrase matching; the learned answers cannot inventory a machine.

The four prior experts reproduced all 72 original integration outcomes and all 24 Word Bench AUTO outputs in host Pascal testing. SPEC5 is an SD edition with five independently trained full TNY2 files, totaling 1,909,040 model bytes. The proposed five-bank shared-core floppy format remains a separate milestone.

### Rebuild and evaluate

The WebTiny trainer at a1a36720ed558d6998e5beed9d4dbdd792626056 fine-tuned TINY.BIN with CPU PyTorch 2.15.0, seed 42. data.py builds 210 development rows from the seven concepts, three aliases per concept and ten prompt patterns. The trainer used 189 fitting and 21 validation rows. Each concept has three separate evaluation questions; facts overlap by design. The experiment measures response to alternative wording on this syllabus.

From PasTinyMoE:

```sh
python specialists/pcbench/data.py
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/pcbench/train.jsonl --steps 750 --batch-size 12 \
  --threads 2 --lr .0003 --out build/pcbench/PCBENCH.BIN
python specialists/pcbench/build.py build/SPEC5
```

BUILD.BAT produces SPEC5.EXE using actual Borland TP7. The packager reads bin/SPEC5.EXE and the pinned model hashes and emits EXPERT.EXE inside the runtime. For a native replay, build EXPERT.PAS using FPC with -B -dSPEC5 and pass its executable, the expanded SPEC5 directory and the general-model FLOPPY3 fixture directory to score.py. CHECK.BAT exercises a model switch, an educational question, coprocessor detection and heap reporting. Physical Pocket386 results are pending.

All 21 DOSBox-X FPU-on answers matched the host outputs, including the seven misses. In the no-FPU run, the DOS runtime switched from Word Bench to PC Workbench, answered the 387 role question correctly, returned “no” for coprocessor detection and directed the installed-RAM question to runtime commands. Loaded and final free heap were both 46,840 bytes. [FPU-on transcript](ALL.LOG) · [No-FPU transcript](NOFPU.LOG)
