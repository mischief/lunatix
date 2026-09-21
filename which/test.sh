#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
WHICH="lua5.4 $D/which.lua"
[ "$($WHICH sh)" = "$(command -v sh)" ] || exit 1
$WHICH no-such-command-anywhere >/dev/null 2>&1 && exit 1
# -a says all of them, so never fewer than one
[ "$($WHICH -a sh | wc -l)" -ge 1 ] || exit 1
# a path is taken as one rather than looked up
[ "$($WHICH /bin/sh)" = "/bin/sh" ] || exit 1
$WHICH 2>/dev/null && exit 1
$WHICH -Z sh 2>/dev/null && exit 1
exit 0
