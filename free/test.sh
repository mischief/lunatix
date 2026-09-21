#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
FREE="lua5.4 $D/free.lua"
[ -r /proc/meminfo ] || exit 77
$FREE | head -1 | grep -q "available" || exit 1
$FREE | grep -q "^Mem:" || exit 1
$FREE | grep -q "^Swap:" || exit 1
$FREE -h | grep -qE "[0-9.]+(Ki|Mi|Gi|Ti)" || exit 1
$FREE -Z 2>/dev/null && exit 1
# the total is the one number that cannot drift between two readings
if command -v free >/dev/null 2>&1; then
	[ "$($FREE | awk '/^Mem:/ {print $2}')" = "$(free | awk '/^Mem:/ {print $2}')" ] || exit 1
fi
exit 0
