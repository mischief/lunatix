#!/bin/sh
# SPDX-License-Identifier: ISC
# Nothing here calls reboot: the argument handling is what can be tested.
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

lua5.4 "$D/reboot.lua" --bogus 2>&1 | grep -q "usage: reboot" || exit 1
cp "$D/reboot.lua" "$TMP/notaname.lua"
lua5.4 "$TMP/notaname.lua" 2>&1 | grep -q "call me as reboot" || exit 1
exit 0
