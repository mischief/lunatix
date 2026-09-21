#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
INSTALL="lua5.4 $D/install.lua"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
printf 'content\n' > "$TMP/src"

# a file, with the mode asked for
$INSTALL -m 755 "$TMP/src" "$TMP/prog" || exit 1
[ -x "$TMP/prog" ] || exit 1
[ "$(cat "$TMP/prog")" = "content" ] || exit 1
$INSTALL -m 644 "$TMP/src" "$TMP/data" || exit 1
[ -x "$TMP/data" ] && exit 1
# -d makes the whole path
$INSTALL -d "$TMP/a/b/c" || exit 1
[ -d "$TMP/a/b/c" ] || exit 1
# into a directory, several at once, keeping the names
$INSTALL -m 644 "$TMP/src" "$TMP/prog" "$TMP/a/b/c" || exit 1
[ -f "$TMP/a/b/c/src" ] && [ -f "$TMP/a/b/c/prog" ] || exit 1
# the leading directories of a target are made
$INSTALL -m 644 "$TMP/src" "$TMP/x/y/file" || exit 1
[ -f "$TMP/x/y/file" ] || exit 1
# usage errors
$INSTALL 2>/dev/null && exit 1
$INSTALL -Z "$TMP/src" "$TMP/z" 2>/dev/null && exit 1
$INSTALL "$TMP/nope" "$TMP/z" 2>/dev/null && exit 1
$INSTALL "$TMP/src" "$TMP/prog" "$TMP/notadir" 2>/dev/null && exit 1
# and the mode matches what the system install would leave
if command -v install >/dev/null 2>&1; then
	install -m 640 "$TMP/src" "$TMP/sys" 
	$INSTALL -m 640 "$TMP/src" "$TMP/ours"
	[ "$(stat -c%a "$TMP/sys")" = "$(stat -c%a "$TMP/ours")" ] || exit 1
fi
exit 0
