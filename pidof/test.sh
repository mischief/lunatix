#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
PIDOF="lua5.4 $D/pidof.lua"
lua5.4 -e 'require("ps.sys")' 2>/dev/null || exit 77

# a process of our own, by name
sleep 30 &
pid=$!
sleep 0.2
$PIDOF sleep | tr ' ' '\n' | grep -q "^$pid$" || { kill $pid; exit 1; }
# -s stops at one
[ "$($PIDOF -s sleep | wc -w)" = "1" ] || { kill $pid; exit 1; }
# -o leaves one out
$PIDOF -o "$pid" sleep | tr ' ' '\n' | grep -q "^$pid$" && { kill $pid; exit 1; }
kill $pid 2>/dev/null
# a name nothing answers to is 1, and says nothing
[ "$($PIDOF no-such-program-here)" = "" ] || exit 1
$PIDOF no-such-program-here && exit 1
$PIDOF 2>/dev/null && exit 1
$PIDOF -Z x 2>/dev/null && exit 1
exit 0
