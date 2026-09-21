#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
LSBLK="lua5.4 $D/lsblk.lua"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

$LSBLK -Z 2>/dev/null && exit 1
$LSBLK -R "$TMP" /dev/nosuchdevice 2>/dev/null && exit 1

# A sysfs of our own: one disk with two partitions, a volume on the
# second, and an empty loop device that should not be shown.
S="$TMP/sys/block"
mkdir -p "$S/sdz/sdz1" "$S/sdz/sdz2" "$S/dm-9/dm" "$S/dm-9/slaves/sdz2" "$S/loop9"
printf '8:0\n' > "$S/sdz/dev"; printf '2097152\n' > "$S/sdz/size"
printf '0\n' > "$S/sdz/removable"; printf '0\n' > "$S/sdz/ro"
printf '8:1\n' > "$S/sdz/sdz1/dev"; printf '2048\n' > "$S/sdz/sdz1/size"
printf '1\n' > "$S/sdz/sdz1/partition"
printf '8:2\n' > "$S/sdz/sdz2/dev"; printf '1048576\n' > "$S/sdz/sdz2/size"
printf '2\n' > "$S/sdz/sdz2/partition"
printf '254:9\n' > "$S/dm-9/dev"; printf '524288\n' > "$S/dm-9/size"
printf '0\n' > "$S/dm-9/removable"; printf '0\n' > "$S/dm-9/ro"
printf 'vg-data\n' > "$S/dm-9/dm/name"
printf 'LVM-abcdef\n' > "$S/dm-9/dm/uuid"
printf '7:9\n' > "$S/loop9/dev"; printf '0\n' > "$S/loop9/size"
printf '0\n' > "$S/loop9/removable"; printf '0\n' > "$S/loop9/ro"
mkdir -p "$TMP/proc/self"
printf '1 0 8:2 / /data rw,relatime shared:1 - ext4 /dev/sdz2 rw\n' > "$TMP/proc/self/mountinfo"
R="$LSBLK -R $TMP"

# the tree: partitions under their disk, the volume under its partition
[ "$($R -n -o NAME | sed -n 1p)" = "sdz" ] || exit 1
[ "$($R -n -o NAME | sed -n 2p)" = "├─sdz1" ] || exit 1
[ "$($R -n -o NAME | sed -n 4p)" = "  └─vg-data" ] || exit 1
# a device mapper target is named by dm/name and typed by dm/uuid
$R -n -o NAME,TYPE | sed -n 4p | grep -q "^  └─vg-data *lvm$" || exit 1
# a partition is a part and a whole disk is a disk
$R -n -o NAME,TYPE | sed -n 1p | grep -q "^sdz *disk$" || exit 1
$R -n -o NAME,TYPE | sed -n 2p | grep -q "^├─sdz1 *part$" || exit 1
# an empty loop device is left out until -a asks for it
$R -n -o NAME | grep -q loop9 && exit 1
$R -a -n -o NAME | grep -q loop9 || exit 1
# sizes are 512 byte sectors, in bytes with -b and in units without
$R -n -b -o NAME,SIZE | sed -n 1p | grep -q "^sdz  *1073741824$" || exit 1
$R -n -o SIZE | sed -n 1p | grep -q "^ *1G$" || exit 1
$R -n -o SIZE | sed -n 2p | grep -q "^ *1M$" || exit 1
# a mount point comes from the mount table, by device number
$R -n -o NAME,MOUNTPOINTS | sed -n 3p | grep -q "^└─sdz2 *.data$" || exit 1
# -l is the same devices with no tree
[ "$($R -l -n -o NAME | sed -n 2p)" = "sdz1" ] || exit 1
# -A draws the tree without the box characters
$R -A -n -o NAME | grep -q '^|-sdz1$' || exit 1
# a column nobody has is an error rather than a blank
$R -o NOSUCHCOLUMN 2>/dev/null && exit 1

# and what util-linux says about this machine's real devices
if command -v lsblk >/dev/null 2>&1 && [ -d /sys/block ]; then
	[ "$($LSBLK)" = "$(lsblk)" ] || exit 1
	[ "$($LSBLK -l)" = "$(lsblk -l)" ] || exit 1
	[ "$($LSBLK -o NAME,SIZE,TYPE)" = "$(lsblk -o NAME,SIZE,TYPE)" ] || exit 1
fi
exit 0
