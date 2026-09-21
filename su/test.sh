#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
SU="lua5.4 $D/su.lua"

$SU --bogus 2>&1 | grep -q "usage: su" || exit 1
$SU no-such-user 2>&1 | grep -q "no such user" || exit 1
# as an ordinary user, a wrong password is a failure and not a shell
if [ "$(id -u)" != "0" ]; then
	printf 'wrong\n' | $SU root 2>&1 | grep -q "Authentication failure" || exit 1
	printf 'wrong\n' | $SU root >/dev/null 2>&1 && exit 1
fi
# root is the only one that is not asked, so only root can be run through
if [ "$(id -u)" = "0" ]; then
	$SU "$(id -un)" -c 'echo ran' 2>/dev/null | grep -q ran || exit 1
else
	# everyone else is asked, and an empty answer is not a password
	printf '\n' | $SU "$(id -un)" -c 'echo ran' 2>/dev/null | grep -q ran && exit 1
fi
exit 0
