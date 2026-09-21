#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
CPIO="lua5.4 $D/cpio.lua"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src/sub" "$TMP/ours" "$TMP/theirs"
echo hello > "$TMP/src/a.txt"
echo world > "$TMP/src/sub/b.txt"
ln -s a.txt "$TMP/src/link"
chmod 755 "$TMP/src/a.txt"

# make an archive, and read it back with our own reader
(cd "$TMP/src" && find . | $CPIO -o -H newc > "$TMP/ours.cpio" 2>/dev/null) || exit 1
[ -s "$TMP/ours.cpio" ] || exit 1
$CPIO -t < "$TMP/ours.cpio" | grep -q "sub/b.txt" || exit 1
(cd "$TMP/ours" && $CPIO -idm < "$TMP/ours.cpio") || exit 1
diff -r "$TMP/src" "$TMP/ours" >/dev/null || exit 1
[ -x "$TMP/ours/a.txt" ] || exit 1
[ -L "$TMP/ours/link" ] || exit 1

# an archive nobody understands is refused rather than half-read
printf 'not an archive at all, really not\n' | $CPIO -t >/dev/null 2>&1 && exit 1
$CPIO 2>/dev/null && exit 1
$CPIO -o -H bogus </dev/null 2>/dev/null && exit 1

# and where the system has cpio, each must read what the other wrote
command -v cpio >/dev/null 2>&1 || exit 0
(cd "$TMP/src" && find . | cpio -o -H newc > "$TMP/theirs.cpio" 2>/dev/null) || exit 0
(cd "$TMP/theirs" && $CPIO -idm < "$TMP/theirs.cpio") || exit 1
diff -r "$TMP/src" "$TMP/theirs" >/dev/null || exit 1
rm -rf "$TMP/check"; mkdir "$TMP/check"
(cd "$TMP/check" && cpio -idm < "$TMP/ours.cpio" 2>/dev/null) || exit 1
diff -r "$TMP/src" "$TMP/check" >/dev/null || exit 1
exit 0
