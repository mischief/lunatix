#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp "$D/sum.lua" "$TMP/sha256sum.lua"
cp "$D/sum.lua" "$TMP/sha1sum.lua"
SHA256="lua5.4 $TMP/sha256sum.lua"
SHA1="lua5.4 $TMP/sha1sum.lua"

printf 'abc' > "$TMP/abc"
# the published vectors for abc
[ "$($SHA256 "$TMP/abc" | cut -d' ' -f1)" = \
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" ] || exit 1
[ "$($SHA1 "$TMP/abc" | cut -d' ' -f1)" = \
  "a9993e364706816aba3e25717850c26c9cd0d89d" ] || exit 1
# and what the system says, where it has the same tool
if command -v sha256sum >/dev/null 2>&1; then
	[ "$($SHA256 "$TMP/abc")" = "$(sha256sum "$TMP/abc")" ] || exit 1
fi
# stdin, and -c reading back what was written
printf 'abc' | $SHA256 | grep -q '^ba7816bf' || exit 1
(cd "$TMP" && $SHA256 abc > sums && $SHA256 -c sums | grep -q "abc: OK") || exit 1
(cd "$TMP" && printf 'xyz' > abc && $SHA256 -c sums | grep -q "abc: FAILED") || exit 1
(cd "$TMP" && ! $SHA256 -c sums >/dev/null 2>&1) || exit 1
exit 0
