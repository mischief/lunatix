#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
WALL="lua5.4 $D/wall.lua"

$WALL -Z </dev/null 2>/dev/null && exit 1
$WALL a b </dev/null 2>/dev/null && exit 1
$WALL /no/such/file 2>&1 | grep -q "cannot read" || exit 1
# with nobody to say it to, it says it to nobody and exits happy
echo hello | $WALL || exit 1
echo hello | $WALL -n || exit 1

# a terminal of our own, with the write bit on, does receive it
command -v script >/dev/null 2>&1 || exit 0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/run.sh" <<INNER
lua5.4 $D/../../os/mesg/mesg.lua y 2>/dev/null || true
LINE=\$(tty); LINE=\${LINE#/dev/}
lua5.4 -e '
local utmp = require("luaposixcli.utmp")
local f = assert(io.open("$TMP/utmp", "wb"))
f:write(utmp.pack({ type = utmp.USER_PROCESS, pid = 1, line = "'"\$LINE"'",
	user = "tester", time = os.time() }))
f:close()'
echo "the message" | lua5.4 -e '
local utmp = require("luaposixcli.utmp")
utmp.UTMP = "$TMP/utmp"
arg = { [0] = "wall" }
dofile("$D/wall.lua")'
INNER
script -qec "sh $TMP/run.sh" /dev/null | tr -d '\r' > "$TMP/out" || exit 1
grep -q "Broadcast message from" "$TMP/out" || exit 1
grep -q "^the message$" "$TMP/out" || exit 1
exit 0
