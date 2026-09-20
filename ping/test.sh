#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
PING="lua5.4 $D/ping.lua"

# An ICMP socket needs either a gid in net.ipv4.ping_group_range or
# CAP_NET_RAW; where there is neither, ping can only say so.
$PING -c 1 127.0.0.1 >/dev/null 2>&1 || exit 77

[ "$($PING -c 2 127.0.0.1 | grep -c 'bytes from 127.0.0.1')" = "2" ] || exit 1
$PING -c 1 127.0.0.1 | grep -q '0% packet loss' || exit 1
# a name that cannot resolve is an error, not a hang
$PING -c 1 no-such-host.invalid >/dev/null 2>&1 && exit 1
exit 0
