#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
HOSTNAME="lua5.4 $D/hostname.lua"

[ "$($HOSTNAME)" = "$(hostname)" ] || exit 1
$HOSTNAME --bogus 2>&1 | grep -q "usage: hostname" || exit 1
$HOSTNAME -F /nonexistent 2>&1 | grep -q "cannot read" || exit 1
# naming the machine is privileged; as an ordinary user it must refuse
if [ "$(id -u)" != "0" ]; then
	$HOSTNAME somename 2>&1 | grep -q "hostname:" || exit 1
fi
# in a namespace of its own it works, and the change stays inside
if command -v unshare >/dev/null 2>&1; then
	unshare -r -u sh -c "lua5.4 $D/hostname.lua inside && [ \"\$(lua5.4 $D/hostname.lua)\" = inside ]" || exit 1
	[ "$($HOSTNAME)" != "inside" ] || exit 1
fi
exit 0
