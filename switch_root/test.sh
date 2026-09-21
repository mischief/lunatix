#!/bin/sh
# SPDX-License-Identifier: ISC
# Nothing here switches a root: what can be tested is the refusals.
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
SR="lua5.4 $D/switch_root.lua"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

$SR 2>&1 | grep -q "usage: switch_root" || exit 1
# a directory that is not one, and one with no init in it
$SR /etc/hostname 2>&1 | grep -q "not a directory" || exit 1
$SR "$TMP" 2>&1 | grep -q "nothing would run" || exit 1
# as pivot_root it needs both operands
cp "$D/switch_root.lua" "$TMP/pivot_root.lua"
lua5.4 "$TMP/pivot_root.lua" 2>&1 | grep -q "usage: pivot_root" || exit 1
# and without privilege it says why rather than half-doing it
if [ "$(id -u)" != "0" ]; then
	lua5.4 "$TMP/pivot_root.lua" / /mnt 2>&1 | grep -q "pivot_root:" || exit 1
fi
exit 0
