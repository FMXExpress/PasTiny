# Go and chess entered through the interactive editor

The shipped TP7 MAKECOM ran in screen-editor mode, starting with an empty program. A DOS test helper supplied printable keys, Enter and Tab through the BIOS keyboard interrupt. Every rule line went through the editor's normal incremental insertion and compilation path. The replay never sent LOAD. Tab advanced past the auto-inserted block closers.

| Game | Tab keys | Enter keys including setup and quit | Compiled size |
| --- | ---: | ---: | ---: |
| Chess | 21 | 85 | 5,379 bytes |
| Go | 29 | 139 | 6,720 bytes |

The replay asked Tiny to write each welcome line. The Text expert supplied PRINT welcome to chess and PRINT welcome to go. Game rules were typed as explicit editor-language statements. The helper converted standalone block openers to the editor's colon form, used Tab to leave each block, and quoted literal text where the editor would otherwise parse punctuation as a separator. The chess replay displays 0 for empty squares.

The Go output passed capture, ko, suicide, occupied-point and scoring tests. The chess output passed legal-move, capture, blocked-rook and self-check tests. Chess remains a prototype with the limits listed in the examples README.

To reproduce, extract PASASM.ZIP into a scratch DOS directory. Assemble the keyboard test helper and generate KEYS.IN from PasTinyAsm on Linux:

```sh
as --32 experiments/editor/keyfeed.s -o /tmp/keyfeed.o
ld -m elf_i386 -Ttext 0x100 --oformat binary /tmp/keyfeed.o -o /path/to/scratch/KEYFEED.COM
python3 experiments/editor/replay.py . /path/to/scratch CHESS
```

Use GOGAME as the final argument for Go. In a fresh DOSBox-X session, run KEYFEED and then MAKECOM at the DOS prompt. The helper remains resident in the test session. Restart the emulator before replaying another game. The editor writes TABCHESS.COM or TABGO.COM and the corresponding editable SRC.
