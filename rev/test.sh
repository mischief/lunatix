#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
REV="lua5.4 $D/rev.lua"
[ "$(printf 'abc\n' | $REV)" = "cba" ] || exit 1
[ "$(printf 'abc\nxyz\n' | $REV | tr '\n' ' ')" = "cba zyx " ] || exit 1
# a line with no newline at the end still comes out
[ "$(printf 'abc' | $REV)" = "cba" ] || exit 1
$REV /nonexistent 2>/dev/null && exit 1
$REV -Z 2>/dev/null && exit 1
if command -v rev >/dev/null 2>&1; then
	[ "$(printf 'hello world\n' | $REV)" = "$(printf 'hello world\n' | rev)" ] || exit 1
fi
exit 0
