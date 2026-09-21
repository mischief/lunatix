#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
PIDOF="lua5.4 $D/pidof.lua"
lua5.4 -e 'require("ps.sys")' 2>/dev/null || exit 77

# A process of our own, under a name nothing else on the machine has:
# another test signalling everything called sleep would take ours with it.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
NAME="pidof$$"
cp "$(command -v sleep)" "$TMP/$NAME" || exit 77
"$TMP/$NAME" 30 &
pid=$!
sleep 0.2
$PIDOF "$NAME" | tr ' ' '\n' | grep -q "^$pid$" || { kill $pid; exit 1; }
# -s stops at one
[ "$($PIDOF -s "$NAME" | wc -w)" = "1" ] || { kill $pid; exit 1; }
# -o leaves one out
$PIDOF -o "$pid" "$NAME" | tr ' ' '\n' | grep -q "^$pid$" && { kill $pid; exit 1; }
kill $pid 2>/dev/null
# a name nothing answers to is 1, and says nothing
[ "$($PIDOF no-such-program-here)" = "" ] || exit 1
$PIDOF no-such-program-here && exit 1
$PIDOF 2>/dev/null && exit 1
$PIDOF -Z x 2>/dev/null && exit 1
exit 0
