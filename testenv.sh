# SPDX-License-Identifier: ISC
# Sourced by each test: these programs use luaposixcli's modules, so both
# trees go on the path. LUAPOSIXCLI says where that tree is, and
# LUAPOSIXCLI_BUILD where its C modules were built.
LUNATIX="$(cd "$(dirname "$0")/.." && pwd)"
: "${LUAPOSIXCLI:=$LUNATIX/../os}"
: "${LUAPOSIXCLI_BUILD:=$LUAPOSIXCLI/build}"
export LUA_PATH="$LUNATIX/?.lua;$LUNATIX/?/init.lua;$LUAPOSIXCLI/?.lua;$LUAPOSIXCLI/?/init.lua;${LUA_PATH:-;}"
export LUA_CPATH="$LUAPOSIXCLI_BUILD/?.so;${LUA_CPATH:-;}"
