#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
SETSID="lua5.4 $D/setsid.lua"

# -w waits and hands back the command's own status
[ "$($SETSID -w echo hi)" = "hi" ] || exit 1
$SETSID -w true || exit 1
$SETSID -w false && exit 1
$SETSID -w sh -c 'exit 3'; [ "$?" = "3" ] || exit 1
# the command really is in a session of its own
[ "$($SETSID -w sh -c 'ps -o sid= -p $$' 2>/dev/null | tr -d ' ')" != "$(ps -o sid= -p $$ 2>/dev/null | tr -d ' ')" ] || exit 1
$SETSID 2>/dev/null && exit 1
$SETSID -Z true 2>/dev/null && exit 1
exit 0
