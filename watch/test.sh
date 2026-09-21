#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
WATCH="lua5.4 $D/watch.lua"

# without a terminal it says so rather than painting into a pipe
$WATCH echo hi >/dev/null 2>&1 && exit 1
$WATCH echo hi 2>&1 | grep -q "not a terminal" || exit 1
$WATCH 2>/dev/null && exit 1
$WATCH -Z echo 2>/dev/null && exit 1
# on a terminal it draws the title and the output, and -g stops on change
command -v script >/dev/null 2>&1 || exit 0
out=$(script -qec "LINES=24 COLUMNS=80 $WATCH -n 0.2 -g date" /dev/null </dev/null | head -3)
echo "$out" | grep -q "Every 0.2s: date" || exit 1
exit 0
