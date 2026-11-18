#!/bin/sh
# Build every Turbo Pascal 7 variant in DOSBox-X and check the DOS programs
# against the host builds, with the FPU on and on a 386 without one.
#   TP7_DIR=/dir/with/TPC.EXE+TURBO.TPL tests/run_tp7.sh
set -eu
cd "$(dirname "$0")/.."
: "${TP7_DIR:?Set TP7_DIR to the directory holding TPC.EXE and TURBO.TPL}"
dosbox=${DOSBOX_X:-dosbox-x}
root=$(pwd)
conf=../PasTinyMoE/evidence
mkdir -p build/int build/flt
fpc -Mtp -B -FEbuild/int JEV.PAS >/dev/null
fpc -Mtp -B -dFLOATMATH -FEbuild/flt JEV.PAS >/dev/null
stage=$(mktemp -d "$root/build/tp7.XXXXXX")
rm -rf "$stage/rt"
python3 tools/package.py build/int/JEV "$stage/rt" --exe-name JEV >/dev/null
cp "$TP7_DIR/TPC.EXE" "$TP7_DIR/TURBO.TPL" *.PAS BUILD.BAT "$stage"
cp "$stage"/rt/*.BIN "$stage/rt/EXPERTS.CAT" "$stage"
python3 - "$stage" <<'PY'
import json, sys
from pathlib import Path
sys.path.insert(0, 'tools')
from jevrun import script
stage = Path(sys.argv[1])
qs = [json.loads(s) for s in Path('training/wild.jsonl').read_text().splitlines() if s.strip()]
lines = ['LIST'] + script(qs) + ['ASK what is 7 times 8', 'USE 2', 'USE 1', 'MEM', 'QUIT']
(stage / 'Q.IN').write_bytes(('\r\n'.join(lines) + '\r\n').encode())
(stage / 'rt' / 'Q.IN').write_text('\n'.join(lines) + '\n')
short = ['LIST'] + script(qs[:6]) + ['MEM', 'QUIT']
(stage / 'S.IN').write_bytes(('\r\n'.join(short) + '\r\n').encode())
(stage / 'rt' / 'S.IN').write_text('\n'.join(short) + '\n')
for name, commands in [
    ('ON.BAT', ['call build.bat', 'if not exist jev.exe goto end',
                'jev < q.in > asm.log', 'jevno < q.in > pure.log', 'jevflt < q.in > flt.log']),
    ('OFF.BAT', ['jev < s.in > nofpu.log'])]:
    (stage / name).write_bytes(('\r\n'.join(['@echo off', *commands, ':end', 'exit']) + '\r\n').encode())
PY
(cd "$stage/rt" && ./JEV < Q.IN > ../HOSTINT.LOG && ./JEV < S.IN > ../HOSTS.LOG \
  && "$root/build/flt/JEV" < Q.IN > ../HOSTFLT.LOG)
run() {
    SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-dummy} SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy} \
      "$dosbox" -conf "$1" -nogui -fastlaunch -c "mount c $stage" -c 'c:' -c "$2"
}
run $conf/fpu-on/TEST.CON ON.BAT >"$stage/on-emulator.log" 2>&1
python3 tests/compare.py "$stage/HOSTINT.LOG" "$stage/ASM.LOG" "$stage/PURE.LOG"
python3 tests/compare.py "$stage/HOSTFLT.LOG" "$stage/FLT.LOG"
run $conf/TEST.CON OFF.BAT >"$stage/off-emulator.log" 2>&1
grep -q "FPU no" "$stage/NOFPU.LOG"
python3 tests/compare.py "$stage/HOSTS.LOG" "$stage/NOFPU.LOG"
ls -l "$stage"/JEV*.EXE
echo "TP7 builds verified in $stage"
