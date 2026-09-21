#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
LAST="lua5.4 $D/last.lua"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

$LAST -Z 2>/dev/null && exit 1
$LAST -f /no/such/wtmp 2>&1 | grep -q "cannot read" || exit 1

# a wtmp of our own: a boot, two logins, one of which ended
lua5.4 -e '
local utmp = require("luaposixcli.utmp")
local f = assert(io.open("'"$TMP"'/wtmp", "wb"))
local base = 1600000000
f:write(utmp.pack({ type = utmp.BOOT_TIME, line = "~", user = "reboot",
	host = "6.1.0", time = base }))
f:write(utmp.pack({ type = utmp.USER_PROCESS, pid = 10, line = "tty1",
	user = "alice", host = "", time = base + 60 }))
f:write(utmp.pack({ type = utmp.USER_PROCESS, pid = 11, line = "pts/0",
	user = "bob", host = "elsewhere", time = base + 120 }))
f:write(utmp.pack({ type = utmp.DEAD_PROCESS, pid = 11, line = "pts/0",
	time = base + 3720 }))
f:close()' || exit 1

# newest first: bob, then alice, then the boot
[ "$($LAST -f "$TMP/wtmp" | head -1 | cut -d" " -f1)" = "bob" ] || exit 1
$LAST -f "$TMP/wtmp" | grep -q "^alice .*no logout" || exit 1
# bob's session lasted an hour
$LAST -f "$TMP/wtmp" | grep -q "(01:00)" || exit 1
# the boot is there, and -n stops early
$LAST -f "$TMP/wtmp" | grep -q "^reboot   system boot" || exit 1
[ "$($LAST -n 1 -f "$TMP/wtmp" | head -1 | cut -d" " -f1)" = "bob" ] || exit 1
[ "$($LAST -n 1 -f "$TMP/wtmp" | grep -c .)" = "2" ] || exit 1
# a name picks out one person
[ "$($LAST -f "$TMP/wtmp" alice | grep -c "^alice")" = "1" ] || exit 1
[ "$($LAST -f "$TMP/wtmp" alice | grep -c "^bob")" = "0" ] || exit 1
# and the footer says where the records came from
$LAST -f "$TMP/wtmp" | tail -1 | grep -q "^wtmp begins" || exit 1

# what util-linux says about the same file
if command -v last >/dev/null 2>&1; then
	[ "$($LAST -f "$TMP/wtmp")" = "$(last -f "$TMP/wtmp")" ] || exit 1
fi
exit 0
