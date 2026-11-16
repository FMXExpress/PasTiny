#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
FPC=${FPC:-fpc}
CC=${CC:-gcc}
mkdir -p build/reference
"$CC" -x c -O2 TINY.C -lm -o build/reference/tiny_ref
"$CC" -x c -O2 tests/tiny_int.c -lm -o build/reference/tiny_int
build/reference/tiny_ref 0 /P < tests/questions.txt | sed '/^   \[/d' > build/reference/gold_c.txt
build/reference/tiny_int 0 /P < tests/questions.txt | sed '/^   \[/d' > build/reference/gold_int.txt
cmp build/reference/gold_c.txt build/reference/gold_int.txt
for engine in int float debug noasm; do
    mkdir -p "build/$engine"
    defs=
    case "$engine" in
        float) defs=-dFLOATMATH ;;
        debug) defs=-dDEBUG ;;
        noasm) defs=-dNOASM ;;
    esac
    "$FPC" -Mtp -O2 -B $defs -FU"build/$engine" -FE"build/$engine" -oTINY TINY.PAS
    "build/$engine/TINY" 0 /P < tests/questions.txt | sed '/^   \[/d' > "build/$engine/answers.txt"
    cmp build/reference/gold_c.txt "build/$engine/answers.txt"
    echo "$engine: 60/60 reference answers match"
done
for creativity in 5 9; do
    build/debug/TINY "$creativity" /P < tests/questions.txt > "build/debug/random_$creativity.txt"
done
python3 tests/errors.py
build/int/TINY /BENCH > build/int/BENCH.TXT
build/float/TINY /BENCH > build/float/BENCH.TXT
echo 'Host checks passed; DOS and commercial TP7 checks are separate.'
