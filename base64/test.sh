#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
B64="lua5.4 $D/base64.lua"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf 'hello world' > "$TMP/a"
head -c 200 /dev/urandom > "$TMP/b"
: > "$TMP/empty"

# the published encoding of that text
[ "$($B64 "$TMP/a")" = "aGVsbG8gd29ybGQ=" ] || exit 1
# every length of tail, so the padding is right
for n in 1 2 3 4 5; do
	head -c $n "$TMP/b" > "$TMP/part"
	$B64 "$TMP/part" | $B64 -d > "$TMP/back" || exit 1
	cmp -s "$TMP/part" "$TMP/back" || exit 1
done
# a binary file, and nothing at all
$B64 "$TMP/b" | $B64 -d | cmp -s - "$TMP/b" || exit 1
[ "$($B64 "$TMP/empty")" = "" ] || exit 1
# what is not base64 is refused, unless -i says to skip it
printf 'not!valid!' | $B64 -d >/dev/null 2>&1 && exit 1
printf 'aGVs!bG8=' | $B64 -i -d >/dev/null 2>&1 || exit 1
$B64 -Z 2>/dev/null && exit 1

# and the system tool agrees, where there is one
command -v base64 >/dev/null 2>&1 || exit 0
[ "$($B64 "$TMP/b")" = "$(base64 "$TMP/b")" ] || exit 1
for w in 0 4 76; do
	[ "$($B64 -w $w "$TMP/a")" = "$(base64 -w $w "$TMP/a")" ] || exit 1
done
base64 "$TMP/b" | $B64 -d | cmp -s - "$TMP/b" || exit 1
exit 0
