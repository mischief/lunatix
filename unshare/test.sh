#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
UNSHARE="lua5.4 $D/unshare.lua"

$UNSHARE -Z true 2>/dev/null && exit 1
# a user namespace is the one an ordinary user may have
if [ "$(id -u)" != "0" ]; then
	[ "$($UNSHARE -r id -u)" = "0" ] || exit 77
fi
# a hostname set inside one stays inside it
[ "$($UNSHARE -r -u sh -c 'hostname inside; hostname')" = "inside" ] || exit 1
[ "$(hostname)" != "inside" ] || exit 1
# a mount namespace of its own
$UNSHARE -r -m true || exit 1
exit 0
