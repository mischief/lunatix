#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
MP="lua5.4 $D/mountpoint.lua"

# / is one, a directory inside it is not, and the codes match util-linux
$MP -q / || exit 1
$MP -q /etc && exit 1
[ "$($MP /)" = "/ is a mountpoint" ] || exit 1
$MP /nonexistent 2>/dev/null && exit 1
# -d prints the device numbers
$MP -d / | grep -qE '^[0-9]+:[0-9]+$' || exit 1
$MP 2>/dev/null && exit 1
$MP -Z / 2>/dev/null && exit 1
# where util-linux is installed, the exit codes agree
if command -v mountpoint >/dev/null 2>&1; then
	$MP -q /; ours=$?
	mountpoint -q /; sys=$?
	[ "$ours" = "$sys" ] || exit 1
	$MP -q /etc; ours=$?
	mountpoint -q /etc; sys=$?
	[ "$ours" = "$sys" ] || exit 1
fi
exit 0
