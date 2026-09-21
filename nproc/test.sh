#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
NPROC="lua5.4 $D/nproc.lua"
[ "$($NPROC)" -ge 1 ] || exit 1
[ "$($NPROC --all)" -ge "$($NPROC)" ] || exit 1
$NPROC -Z 2>/dev/null && exit 1
if command -v nproc >/dev/null 2>&1; then
	[ "$($NPROC)" = "$(nproc)" ] || exit 1
fi
exit 0
