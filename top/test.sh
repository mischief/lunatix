#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
TOP="lua5.4 $D/top.lua"

# top reads the process table through luaposixcli's ps.sys
lua5.4 -e 'require("ps.sys")' 2>/dev/null || exit 77

# Not a terminal: say so rather than painting escape sequences into a pipe
$TOP -n 1 > /dev/null 2>&1 && exit 1
$TOP -n 1 2>&1 | grep -q "not a terminal" || exit 1
# Bad arguments are rejected
$TOP -d -1 2>/dev/null && exit 1
$TOP -z 2>/dev/null && exit 1
exit 0
