#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
FINDMNT="lua5.4 $D/findmnt.lua"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

$FINDMNT -Z 2>/dev/null && exit 1
$FINDMNT one two 2>/dev/null && exit 1
$FINDMNT -F /no/such/file 2>&1 | grep -q "cannot read" || exit 1

# A table of our own, so what is asserted below is the program rather
# than this machine. Fields: id parent maj:min root target opts - type
# source superopts.
cat > "$TMP/mountinfo" <<'EOF'
1 0 8:1 / / rw,relatime shared:1 - ext4 /dev/sda1 rw
2 1 0:20 / /proc rw,nosuid,nodev,noexec,relatime shared:2 - proc proc rw
9 1 0:21 / /mnt/late rw,relatime shared:9 - tmpfs none rw,size=1k
5 1 0:22 / /mnt/early ro,relatime shared:5 - tmpfs none rw,size=2k
6 5 0:23 / /mnt/early/under rw,relatime shared:6 - tmpfs none ro,size=3k
7 1 0:24 /sub /spaced\040name rw shared:7 - tmpfs none rw
EOF
F="$FINDMNT -F $TMP/mountinfo"

# the tree: a child sits under its parent, and the order is the order
# the mounts were made in rather than the order of the file
[ "$($F -n -o TARGET | sed -n 3p)" = "├─/mnt/early" ] || exit 1
[ "$($F -n -o TARGET | sed -n 4p)" = "│ └─/mnt/early/under" ] || exit 1
[ "$($F -n -o TARGET | sed -n 6p)" = "└─/mnt/late" ] || exit 1
# -A draws the same tree without the box characters
$F -A -n -o TARGET | grep -q '^| `-/mnt/early/under$' || exit 1
# -l is the same mounts with no tree at all
[ "$($F -l -n -o TARGET | grep -c '^/')" = "6" ] || exit 1

# read-only wins whichever list says it: the mount for /mnt/early, the
# superblock for /mnt/early/under
[ "$($F -n -o OPTIONS /mnt/early)" = "ro,relatime,size=2k" ] || exit 1
[ "$($F -n -o OPTIONS /mnt/early/under)" = "ro,relatime,size=3k" ] || exit 1
[ "$($F -n -o OPTIONS /)" = "rw,relatime" ] || exit 1

# a mount point with a space in it comes back whole
[ "$($F -n -o TARGET -t tmpfs | grep -c 'spaced name')" = "1" ] || exit 1

# -T answers with the mount a file is on, not the file
[ "$($F -n -o TARGET -T /mnt/early/under/deep/file)" = "/mnt/early/under" ] || exit 1
[ "$($F -n -o TARGET -T /etc/passwd)" = "/" ] || exit 1
# -S takes a source, -t a type
[ "$($F -n -o TARGET -S /dev/sda1)" = "/" ] || exit 1
[ "$($F -n -o TARGET -t proc)" = "/proc" ] || exit 1
# nothing matching is exit 1 and no output
[ -z "$($F -t nosuchfs)" ] || exit 1
$F -t nosuchfs && exit 1

# and what util-linux says about this machine's real mounts
if command -v findmnt >/dev/null 2>&1 && [ -r /proc/self/mountinfo ]; then
	[ "$($FINDMNT)" = "$(findmnt)" ] || exit 1
	[ "$($FINDMNT -l)" = "$(findmnt -l)" ] || exit 1
	[ "$($FINDMNT -n -o TARGET,FSTYPE /)" = "$(findmnt -n -o TARGET,FSTYPE /)" ] || exit 1
fi
exit 0
