#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
SYSCTL="lua5.4 $D/sysctl.lua"
[ -d /proc/sys ] || exit 77

# a knob everyone has, read the way sysctl reads it
$SYSCTL kernel.ostype | grep -q "^kernel.ostype = Linux$" || exit 1
[ "$($SYSCTL -N kernel.ostype)" = "kernel.ostype" ] || exit 1
$SYSCTL -q kernel.ostype | grep -q . && exit 1
# -a says a lot of them
[ "$($SYSCTL -a 2>/dev/null | wc -l)" -gt 100 ] || exit 1
# a knob nobody has, and a bad option
$SYSCTL no.such.knob >/dev/null 2>&1 && exit 1
$SYSCTL -Z 2>/dev/null && exit 1
$SYSCTL 2>/dev/null && exit 1
# setting one needs privilege; where there is none, say so
if [ "$(id -u)" != "0" ]; then
	$SYSCTL kernel.hostname=nope >/dev/null 2>&1 && exit 1
fi
# and what the system sysctl says for the same knob
if command -v sysctl >/dev/null 2>&1; then
	[ "$($SYSCTL kernel.ostype)" = "$(sysctl kernel.ostype)" ] || exit 1
fi
exit 0
