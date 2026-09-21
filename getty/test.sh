#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
GETTY="lua5.4 $D/getty.lua"

$GETTY 2>&1 | grep -q "usage: getty" || exit 1
# a device that is not there is reported, not crashed on
$GETTY /dev/nosuchtty 2>&1 | grep -q "getty: /dev/nosuchtty" || exit 1
exit 0
