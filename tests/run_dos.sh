#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
DOSBOX_X=${DOSBOX_X:-dosbox-x}
: "${DOS_RUNTIME:?Set DOS_RUNTIME to the FPC bin/go32v2 runtime directory}"
root=$(pwd)
mkdir -p build/doscheck
for engine in original int float; do
    dest="$root/build/doscheck/$engine"
    mkdir -p "$dest"
    cp TINY.BIN "$dest/"
    cp tests/questions.txt "$dest/Q.TXT"
    case "$engine" in
        original) cp TINY.EXE "$dest/TINY.EXE" ;;
        int) cp build/dos/TINY.EXE "$dest/TINY.EXE" ;;
        float) cp build/dosfloat/TNYFLT.EXE "$dest/TINY.EXE" ;;
    esac
    if [ "$engine" != original ]; then
        cp "$DOS_RUNTIME/cwsdpmi.exe" "$DOS_RUNTIME/wmemu387.dxe" "$dest/"
    fi
    printf '@echo off\r\nTINY 0 /P < Q.TXT > A.TXT\r\nTINY 0 /DUMP\r\nexit\r\n' > "$dest/TEST.BAT"
    SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-dummy} SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy} \
        "$DOSBOX_X" -conf tests/DOSBOX.CON -nogui -fastlaunch \
        -c "mount c $dest" -c 'c:' -c 'test.bat' > "$dest/emulator.log" 2>&1
    python3 tests/verify_dos.py answers "$dest/A.TXT" tests/gold_c.txt
done
python3 tests/verify_dos.py ui build/doscheck/original build/doscheck/int
python3 tests/verify_dos.py ui build/doscheck/original build/doscheck/float
