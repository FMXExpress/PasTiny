#!/bin/sh
# Requires a user-supplied Borland Turbo Pascal 7 compiler; none is redistributed.
set -eu
cd "$(dirname "$0")/.."
DOSBOX_X=${DOSBOX_X:-dosbox-x}
: "${TP7_DIR:?Set TP7_DIR to a directory containing TPC.EXE and TURBO.TPL}"
root=$(pwd)
dest="$root/build/tp7"
mkdir -p "$dest"
cp "$TP7_DIR/TPC.EXE" "$TP7_DIR/TURBO.TPL" "$dest/"
cp TINY.PAS TNYNET.PAS TNYSYS.PAS TNYUI.INC EXPTAB.INC TINY.BIN "$dest/"
python3 - "$dest" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.joinpath('Q.TXT').write_bytes(Path('tests/questions.txt').read_text().replace('\n', '\r\n').encode())
commands = '''@echo off
TPC /B TINY.PAS > INTEGER.LOG
IF ERRORLEVEL 1 GOTO END
COPY TINY.EXE TNYINT.EXE
TPC /B /DFLOATMATH TINY.PAS > FLOAT.LOG
IF ERRORLEVEL 1 GOTO END
COPY TINY.EXE TNYFLT.EXE
TPC /B /DNOASM TINY.PAS > NOASM.LOG
IF ERRORLEVEL 1 GOTO END
COPY TINY.EXE TNYNO.EXE
TNYINT 0 /P < Q.TXT > AINT.TXT
TNYFLT 0 /P < Q.TXT > AFLT.TXT
TNYNO 0 /P < Q.TXT > ANO.TXT
TNYINT 0 /DUMP
:END
exit
'''
p.joinpath('TEST.BAT').write_bytes(commands.replace('\n', '\r\n').encode())
config = Path('tests/DOSBOX.CON').read_text()
config = config.replace('core=dynamic', 'core=normal').replace('cputype=auto', 'cputype=386')
p.joinpath('NOFPU.CON').write_text(config + '\n[cpu]\nfpu=false\n')
PY
SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-dummy} SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy} \
    "$DOSBOX_X" -conf tests/DOSBOX.CON -nogui -fastlaunch \
    -c "mount c $dest" -c 'c:' -c 'test.bat' > "$dest/emulator.log" 2>&1
for transcript in AINT.TXT AFLT.TXT ANO.TXT; do
    python3 tests/verify_dos.py answers "$dest/$transcript" tests/gold_c.txt
done
SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-dummy} SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy} \
    "$DOSBOX_X" -conf "$dest/NOFPU.CON" -nogui -fastlaunch \
    -c "mount c $dest" -c 'c:' -c 'tnyint /bench > nofpu.txt' -c 'exit' \
    > "$dest/emulator_no_fpu.log" 2>&1
python3 - "$dest/NOFPU.TXT" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
answers = [line.strip() for line in text.splitlines() if line.startswith('  ') and not line.startswith('  tokens:')]
assert answers == ['Lima.', 'No, a whale is a mammal.', '7 times 8 is 56.', 'Latvia and Russia.', 'E-L-E-P-H-A-N-T.'], answers
assert 'FPU found: no' in text
assert 'Total tokens: 189' in text
print('Turbo Pascal no-FPU benchmark: 5/5 answers, 189 tokens, FPU absent.')
PY
