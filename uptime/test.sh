#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
UPTIME="lua5.4 $D/uptime.lua"
[ -r /proc/uptime ] || exit 77
$UPTIME | grep -q "load average:" || exit 1
$UPTIME -p | grep -q "^up " || exit 1
$UPTIME -s | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || exit 1
$UPTIME -Z 2>/dev/null && exit 1
# the same minutes as the system tool, where there is one
if command -v uptime >/dev/null 2>&1; then
	[ "$($UPTIME -p)" = "$(uptime -p)" ] || exit 1
fi
exit 0
