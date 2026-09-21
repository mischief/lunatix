#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
HWCLOCK="lua5.4 $D/hwclock.lua"

# usage errors need no clock at all
$HWCLOCK -Z 2>/dev/null && exit 1
$HWCLOCK -s -w 2>/dev/null && exit 1
$HWCLOCK extra 2>/dev/null && exit 1
# a device that is not there is reported
$HWCLOCK -f /dev/no_such_rtc 2>&1 | grep -q "No such file" || exit 1

# reading the clock needs the device, which only root has
[ -r /dev/rtc0 ] || exit 77
$HWCLOCK -r | grep -qE '^[A-Z][a-z][a-z] [A-Z][a-z][a-z] +[0-9]+ [0-9:]+ [0-9]{4}$' || exit 1
# and what util-linux says about the same clock, to the minute
if command -v hwclock >/dev/null 2>&1; then
	OURS=$(date -d "$($HWCLOCK -r)" +%Y-%m-%dT%H:%M 2>/dev/null)
	THEIRS=$(date -d "$(hwclock -r)" +%Y-%m-%dT%H:%M 2>/dev/null)
	[ -n "$OURS" ] && [ "$OURS" = "$THEIRS" ] || exit 1
fi
exit 0
