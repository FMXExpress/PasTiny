#!/bin/sh
# Rebuild all variants and verify the redirected 60-question target transcripts.
set -eu
cd "$(dirname "$0")/.."
: "${TP7_DIR:?Set TP7_DIR to the directory holding TPC.EXE and TURBO.TPL}"
dosbox=${DOSBOX_X:-dosbox-x}
root=$(pwd)
mkdir -p build
stage=$(mktemp -d "$root/build/tp7.XXXXXX")
cp "$TP7_DIR/TPC.EXE" "$TP7_DIR/TURBO.TPL" *.PAS BUILD.BAT "$stage"
python3 - "$stage" <<'PY'
from pathlib import Path
from zipfile import ZipFile
import sys
stage=Path(sys.argv[1])
with ZipFile("dist/SD100.ZIP") as archive:
    for name in archive.namelist():
        if name.endswith((".BIN",".CAT")):
            archive.extract(name,stage)
for name in ("Q.IN","SWITCH.IN"):
    (stage/name).write_bytes((Path("evidence")/name).read_bytes())
for filename, commands in [
    ("ON.BAT", ["call build.bat","if not exist expert.exe goto end",
                "expert < q.in > asm.log","expno < q.in > pure.log","expflt < q.in > flt.log"]),
    ("OFF.BAT", ["expert < q.in > nofpu.log","expert < switch.in > heap.log"])]:
    (stage/filename).write_bytes(("\r\n".join(["@echo off",*commands,":end","exit"])+"\r\n").encode())
PY
run() {
    SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-dummy} SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy} \
      "$dosbox" -conf "$1" -nogui -fastlaunch -c "mount c $stage" -c 'c:' -c "$2"
}
run evidence/fpu-on/TEST.CON ON.BAT >"$stage/on-emulator.log" 2>&1
python3 tests/verify_answers.py "$stage/ASM.LOG" "$stage/PURE.LOG" "$stage/FLT.LOG"
run evidence/TEST.CON OFF.BAT >"$stage/off-emulator.log" 2>&1
python3 tests/verify_answers.py "$stage/NOFPU.LOG"
python3 - "$stage" <<'PY'
from pathlib import Path
import sys
stage=Path(sys.argv[1])
lines=(stage/"HEAP.LOG").read_text().splitlines()
heap=[s for s in lines if s.startswith("heap=")]
active=[s for s in lines if s.startswith("active ")]
assert "FPU no" in lines and len(active)==303 and active[-1].startswith("active 100 ")
assert len(heap)>=3 and heap[1]==heap[-1]
print("300 switches, stable heap and final ID 100 verified in",stage)
PY
