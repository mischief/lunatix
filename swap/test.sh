#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for name in swapon swapoff mkswap; do cp "$D/swapon.lua" "$TMP/$name.lua"; done

# swapon with nothing to do reports what is in use
lua5.4 "$TMP/swapon.lua" | head -1 | grep -q Filename || exit 1
lua5.4 "$TMP/swapoff.lua" 2>/dev/null && exit 1
lua5.4 "$TMP/mkswap.lua" 2>/dev/null && exit 1
lua5.4 "$TMP/swapon.lua" -Z 2>/dev/null && exit 1

# mkswap writes a header a swap reader would accept
dd if=/dev/zero of="$TMP/file" bs=4096 count=64 2>/dev/null
lua5.4 "$TMP/mkswap.lua" "$TMP/file" >/dev/null || exit 1
[ "$(dd if="$TMP/file" bs=1 skip=4086 count=10 2>/dev/null)" = "SWAPSPACE2" ] || exit 1
# and the kernel agrees, where it will tell us
if command -v file >/dev/null 2>&1; then
	file "$TMP/file" | grep -qi swap || exit 1
fi
# a file too small to hold anything is refused
dd if=/dev/zero of="$TMP/tiny" bs=1024 count=1 2>/dev/null
lua5.4 "$TMP/mkswap.lua" "$TMP/tiny" 2>/dev/null && exit 1
# turning it on needs privilege; without it, say so
if [ "$(id -u)" != "0" ]; then
	lua5.4 "$TMP/swapon.lua" "$TMP/file" 2>&1 | grep -q "swapon:" || exit 1
fi
exit 0
