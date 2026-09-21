#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
KILLALL="lua5.4 $D/killall.lua"
lua5.4 -e 'require("ps.sys")' 2>/dev/null || exit 77

# a name nothing answers to is an error, and -l lists the signals
$KILLALL no-such-process-here 2>/dev/null && exit 1
$KILLALL -l | grep -q TERM || exit 1
$KILLALL 2>/dev/null && exit 1
$KILLALL -NOSUCHSIG something 2>/dev/null && exit 1

# A process of our own, under a name nothing else has: killing everything
# called sleep would take another test's sleep with it.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
NAME="killall$$"
cp "$(command -v sleep)" "$TMP/$NAME" || exit 77
"$TMP/$NAME" 30 &
pid=$!
sleep 0.2
$KILLALL -KILL "$NAME" || { kill $pid 2>/dev/null; exit 1; }
sleep 0.2
kill -0 $pid 2>/dev/null && { kill -9 $pid 2>/dev/null; exit 1; }
exit 0
