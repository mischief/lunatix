#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
LOSETUP="lua5.4 $D/losetup.lua"

# -a lists what is attached, which on a machine with nothing is nothing
$LOSETUP -a >/dev/null || exit 1
$LOSETUP 2>/dev/null && exit 1
$LOSETUP -Z 2>/dev/null && exit 1
# a device nothing is behind answers nonzero
[ -e /dev/loop0 ] || exit 77
$LOSETUP /dev/loop0 >/dev/null 2>&1
[ "$?" != "0" ] || exit 0
# attaching needs privilege; where there is none, it must say so
if [ "$(id -u)" != "0" ]; then
	TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
	dd if=/dev/zero of="$TMP" bs=1024 count=64 2>/dev/null
	$LOSETUP /dev/loop0 "$TMP" 2>&1 | grep -q "losetup:" || exit 1
fi
exit 0
