#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
MOUNT="lua5.4 $D/mount.lua"
UMOUNT="lua5.4 $D/../umount/umount.lua"

# with no operands it reports what is mounted
$MOUNT | grep -q " on / type " || exit 1
# usage errors are refused
$MOUNT onlyone 2>/dev/null && exit 1
$UMOUNT 2>/dev/null && exit 1
# mounting something we may not mount fails with the reason, not a crash
$MOUNT -t tmpfs none /proc/nonexistent 2>&1 | grep -q "mount:" || exit 1

# a real mount, where the kernel lets us have one: a user namespace with
# its own mount namespace can hold a tmpfs
command -v unshare >/dev/null 2>&1 || exit 0
TMP=$(mktemp -d)
unshare -r -m sh -c "lua5.4 $D/mount.lua -t tmpfs none $TMP && echo x > $TMP/f && lua5.4 $D/../umount/umount.lua $TMP && [ ! -f $TMP/f ]" || { rm -rf "$TMP"; exit 1; }
rm -rf "$TMP"
exit 0
