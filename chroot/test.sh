#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
CHROOT="lua5.4 $D/chroot.lua"

$CHROOT 2>&1 | grep -q "usage: chroot" || exit 1
# changing the root is privileged; without it, say why
if [ "$(id -u)" != "0" ]; then
	$CHROOT /tmp /bin/true 2>&1 | grep -q "chroot:" || exit 1
fi
# with a namespace we can prove the root actually moved: a directory that
# is not there fails at the chroot, and one that is fails at the exec
# instead, because the command it names is outside the new root.
command -v unshare >/dev/null 2>&1 || exit 0
TMP=$(mktemp -d)
unshare -r sh -c "lua5.4 $D/chroot.lua /nonexistent /bin/true" 2>&1 |
	grep -q "/nonexistent:" || { rm -rf "$TMP"; exit 1; }
unshare -r sh -c "lua5.4 $D/chroot.lua $TMP /bin/true" 2>&1 |
	grep -q "cannot execute" || { rm -rf "$TMP"; exit 1; }
rm -rf "$TMP"
exit 0
