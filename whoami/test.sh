#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
[ "$(lua5.4 "$D/whoami.lua")" = "$(id -un)" ] || exit 1
lua5.4 "$D/whoami.lua" extra 2>/dev/null && exit 1
exit 0
