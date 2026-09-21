#!/bin/sh
# SPDX-License-Identifier: ISC
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for name in insmod rmmod lsmod modprobe; do cp "$D/insmod.lua" "$TMP/$name.lua"; done

# lsmod reads /proc/modules and puts a header on it
[ -r /proc/modules ] || exit 77
lua5.4 "$TMP/lsmod.lua" | head -1 | grep -q "^Module" || exit 1
[ "$(lua5.4 "$TMP/lsmod.lua" | wc -l)" = "$(( $(wc -l < /proc/modules) + 1 ))" ] || exit 1

# usage errors, and a module nobody has
lua5.4 "$TMP/insmod.lua" 2>&1 | grep -q "usage: insmod" || exit 1
lua5.4 "$TMP/rmmod.lua" 2>&1 | grep -q "usage: rmmod" || exit 1
lua5.4 "$TMP/modprobe.lua" 2>&1 | grep -q "usage: modprobe" || exit 1
lua5.4 "$TMP/rmmod.lua" no_such_module 2>&1 | grep -q "no_such_module:" || exit 1
lua5.4 "$TMP/modprobe.lua" no_such_module_at_all 2>&1 | grep -q "no_such_module_at_all" || exit 1
# a file that is not a module says so rather than crashing
printf 'not a module\n' > "$TMP/fake.ko"
lua5.4 "$TMP/insmod.lua" "$TMP/fake.ko" 2>&1 | grep -q "fake.ko:" || exit 1
# xz and zstd are refused with the reason
: > "$TMP/x.ko.xz"
lua5.4 "$TMP/insmod.lua" "$TMP/x.ko.xz" 2>&1 | grep -q "xz or zstd" || exit 1
exit 0
