#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
TOP="lua5.4 $D/top.lua"

# top reads the process table through luaposixcli's ps.sys
lua5.4 -e 'require("ps.sys")' 2>/dev/null || exit 77

# No terminal anywhere - setsid drops the controlling one, so /dev/tty
# cannot be opened either. Say so rather than painting into a pipe.
command -v setsid >/dev/null 2>&1 || exit 77
setsid $TOP -n 1 > /dev/null 2>&1 && exit 1
setsid $TOP -n 1 2>&1 < /dev/null | grep -q "not a terminal" || exit 1
# Bad arguments are rejected
$TOP -d -1 2>/dev/null && exit 1
$TOP -z 2>/dev/null && exit 1
exit 0
