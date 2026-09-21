#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
FUSER="lua5.4 $D/fuser.lua"
[ -d /proc/self/fd ] || exit 77

$FUSER 2>/dev/null && exit 1
$FUSER -Z /tmp 2>/dev/null && exit 1
# a file nobody names at all
$FUSER /no/such/file 2>&1 | grep -q "No such file" || exit 1

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
# nobody holds it yet, which is exit 1 and nothing on stdout
[ -z "$($FUSER "$TMP" 2>/dev/null)" ] || exit 1
$FUSER -s "$TMP" && exit 1

# hold it open and it is found, with the pid of the holder
sleep 5 < "$TMP" &
HOLDER=$!
sleep 0.3
$FUSER -s "$TMP" || { kill $HOLDER; exit 1; }
echo "$($FUSER "$TMP" 2>/dev/null)" | grep -q "$HOLDER" || { kill $HOLDER; exit 1; }
# -u names the user as well
$FUSER -u "$TMP" 2>/dev/null | grep -q "($(id -un))" || { kill $HOLDER; exit 1; }
# and what the system fuser says about the same file
if command -v fuser >/dev/null 2>&1; then
	[ "$($FUSER "$TMP" 2>/dev/null)" = "$(fuser "$TMP" 2>/dev/null)" ] ||
		{ kill $HOLDER; exit 1; }
fi

# -k signals the holder
$FUSER -k -TERM "$TMP" >/dev/null 2>&1
sleep 0.3
kill -0 $HOLDER 2>/dev/null && { kill $HOLDER; exit 1; }
wait 2>/dev/null
exit 0
