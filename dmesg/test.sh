#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
DMESG="lua5.4 $D/dmesg.lua"

# a bad option is refused whatever the kernel allows
$DMESG -z 2>/dev/null && exit 1
# reading the log needs permission; where there is none, say so and stop
if ! head -c 1 /dev/kmsg >/dev/null 2>&1; then
	$DMESG 2>&1 | grep -q "dmesg:" || exit 1
	exit 77
fi
$DMESG | head -1 | grep -q "^\[" || exit 1
$DMESG -t | head -1 | grep -qv "^\[" || exit 1
exit 0
