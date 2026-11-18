#!/bin/sh
# Create a fresh FAT12 image and compare every file after reading it back.
set -eu
runtime=${1:?runtime directory required}
image=${2:?new image path required}
if test -e "$image"; then echo "Choose a new image filename" >&2; exit 1; fi
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
truncate -s 1474560 "$temp/disk.img"
if command -v mkfs.fat >/dev/null; then mkfs.fat -F 12 "$temp/disk.img" >/dev/null
else mformat -i "$temp/disk.img" -f 1440 ::; fi
mcopy -i "$temp/disk.img" "$runtime"/* ::
mkdir "$temp/check"
mcopy -i "$temp/disk.img" '::*' "$temp/check"
diff -qr "$runtime" "$temp/check"
cp "$temp/disk.img" "$image"
