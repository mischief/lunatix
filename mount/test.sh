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

# -a mounts what an fstab says to mount, skips noauto, and umount -a
# takes it away again
mkdir -p "$TMP/mp" "$TMP/never"
printf 'tmpfs %s/mp tmpfs defaults 0 0\nnone %s/never tmpfs noauto 0 0\n' "$TMP" "$TMP" > "$TMP/fstab"
unshare -r -m sh -c "lua5.4 $D/mount.lua -a -T $TMP/fstab &&
	echo x > $TMP/mp/f &&
	grep -q ' $TMP/mp ' /proc/self/mounts &&
	! grep -q ' $TMP/never ' /proc/self/mounts &&
	lua5.4 $D/../umount/umount.lua -a 2>/dev/null
	! grep -q ' $TMP/mp ' /proc/self/mounts" || { rm -rf "$TMP"; exit 1; }
# an fstab that is not there is reported, not passed over
$MOUNT -a -T "$TMP/nosuchfstab" 2>&1 | grep -q "cannot read" || { rm -rf "$TMP"; exit 1; }
rm -rf "$TMP"
exit 0
