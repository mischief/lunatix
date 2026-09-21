#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
MKNOD="lua5.4 $D/mknod.lua"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# usage errors are refused
$MKNOD 2>/dev/null && exit 1
$MKNOD "$TMP/x" 2>/dev/null && exit 1
$MKNOD "$TMP/x" z 1 3 2>/dev/null && exit 1
$MKNOD "$TMP/x" c 2>/dev/null && exit 1
$MKNOD "$TMP/x" p 1 3 2>/dev/null && exit 1

# a fifo needs no privilege
$MKNOD "$TMP/fifo" p || exit 1
[ -p "$TMP/fifo" ] || exit 1
$MKNOD -m 600 "$TMP/fifo2" p || exit 1
[ -p "$TMP/fifo2" ] || exit 1
[ "$(ls -l "$TMP/fifo2" | cut -c2-10)" = "rw-------" ] || exit 1

# a device node needs privilege. Where there is none, say so rather
# than making nothing and saying nothing.
if [ "$(id -u)" != "0" ]; then
	$MKNOD "$TMP/null" c 1 3 2>/dev/null && exit 1
else
	$MKNOD "$TMP/null" c 1 3 || exit 1
	[ -c "$TMP/null" ] || exit 1
	echo hi > "$TMP/null" || exit 1
fi
exit 0
