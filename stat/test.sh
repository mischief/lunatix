#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
STAT="lua5.4 $D/stat.lua"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
echo x > f && chmod 750 f && ln -s f l && mkdir d

# the default form says the things a person reads it for
$STAT f | grep -q "  File: f" || exit 1
$STAT f | grep -q "regular file" || exit 1
$STAT d | grep -q "directory" || exit 1
# a symlink is the link unless -L says otherwise
[ "$($STAT -c %F l)" = "symbolic link" ] || exit 1
[ "$($STAT -L -c %F l)" = "regular file" ] || exit 1
# an unknown file and an unknown option are both errors
$STAT nosuch >/dev/null 2>&1 && exit 1
$STAT -Z f >/dev/null 2>&1 && exit 1
$STAT 2>/dev/null && exit 1

# and every format letter says what the system stat says
command -v stat >/dev/null 2>&1 || exit 0
for fmt in %n %s %a %A %U %G %F %Y %i %h %u %g %b; do
	[ "$($STAT -c $fmt f)" = "$(stat -c $fmt f)" ] || exit 1
done
[ "$($STAT -c '%a %U' d)" = "$(stat -c '%a %U' d)" ] || exit 1
exit 0
