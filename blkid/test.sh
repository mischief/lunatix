#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
BLKID="lua5.4 $D/blkid.lua"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

$BLKID -Z 2>/dev/null && exit 1
# a file with nothing on it is not a filesystem, and says so by exiting 2
truncate -s 1M "$TMP/empty.img" 2>/dev/null || exit 77
$BLKID "$TMP/empty.img"; [ $? = 2 ] || exit 1

made=0
check() {
	# $1 image, $2 expected type, $3 expected label
	$BLKID "$TMP/$1" | grep -q "TYPE=\"$2\"" || exit 1
	[ -n "$3" ] && { $BLKID "$TMP/$1" | grep -q "LABEL=\"$3\"" || exit 1; }
	# the uuid on its own, which is what an fstab is written from
	UUID=$($BLKID -s UUID -o value "$TMP/$1")
	[ -n "$UUID" ] || exit 1
	# and what the system blkid reads out of the same bytes
	if command -v blkid >/dev/null 2>&1; then
		[ "$UUID" = "$(blkid -s UUID -o value "$TMP/$1")" ] || exit 1
	fi
	made=$((made + 1))
}

if command -v mke2fs >/dev/null 2>&1; then
	truncate -s 16M "$TMP/ext.img"
	mke2fs -q -t ext4 -L extlabel "$TMP/ext.img" 2>/dev/null && check ext.img ext4 extlabel
fi
if command -v mkswap >/dev/null 2>&1; then
	truncate -s 16M "$TMP/swap.img"
	mkswap -L swaplabel "$TMP/swap.img" >/dev/null 2>&1 && check swap.img swap swaplabel
fi
if command -v mkfs.vfat >/dev/null 2>&1; then
	truncate -s 16M "$TMP/vfat.img"
	mkfs.vfat -n VFATLABEL "$TMP/vfat.img" >/dev/null 2>&1 && check vfat.img vfat VFATLABEL
fi
[ "$made" -gt 0 ] || exit 77

# UUID= and LABEL= resolve to the device carrying them
lua5.4 -e '
local probe = require("lunatix.probe")
local images = { "'"$TMP"'/ext.img", "'"$TMP"'/swap.img", "'"$TMP"'/vfat.img" }
-- stand in for /proc/partitions: the images we just made
probe.devices = function() return images end
local first = probe.probe(images[1]) or probe.probe(images[2]) or probe.probe(images[3])
assert(first, "nothing probed")
assert(probe.resolve("UUID=" .. first.uuid) == first.device, "uuid did not resolve")
assert(probe.resolve("LABEL=" .. first.label) == first.device, "label did not resolve")
assert(probe.resolve("UUID=nothing-like-this") == nil, "a uuid nobody has resolved")
assert(probe.resolve("/dev/sda1") == "/dev/sda1", "a plain name was changed")
' || exit 1
exit 0
