#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp "$D/hexdump.lua" "$TMP/xxd.lua"
HD="lua5.4 $D/hexdump.lua"
XXD="lua5.4 $TMP/xxd.lua"
printf 'hello world\nsecond line here\n' > "$TMP/a"
head -c 300 /dev/urandom > "$TMP/r"

$HD -C "$TMP/a" | grep -q "|hello world" || exit 1
$XXD "$TMP/a" | head -1 | grep -q "^00000000: 6865" || exit 1
# what xxd writes, xxd reads back
$XXD "$TMP/r" > "$TMP/hex" && $XXD -r "$TMP/hex" > "$TMP/back" || exit 1
cmp -s "$TMP/r" "$TMP/back" || exit 1
$XXD -p "$TMP/r" > "$TMP/plain" && $XXD -r -p "$TMP/plain" > "$TMP/pback" || exit 1
cmp -s "$TMP/r" "$TMP/pback" || exit 1
$HD -Z "$TMP/a" 2>/dev/null && exit 1

# byte for byte against the system tools, on text and on random bytes
if command -v xxd >/dev/null 2>&1; then
	for f in a r; do
		$XXD "$TMP/$f" | cmp -s - "$(xxd "$TMP/$f" > "$TMP/sys"; echo "$TMP/sys")" || exit 1
	done
	for opt in -p "-c 8" "-l 5" "-s 4"; do
		$XXD $opt "$TMP/a" > "$TMP/o"; xxd $opt "$TMP/a" > "$TMP/s"
		cmp -s "$TMP/o" "$TMP/s" || exit 1
	done
fi
if command -v hexdump >/dev/null 2>&1; then
	for f in a r; do
		$HD -C "$TMP/$f" > "$TMP/o"; hexdump -C "$TMP/$f" > "$TMP/s"
		cmp -s "$TMP/o" "$TMP/s" || exit 1
	done
fi
exit 0
