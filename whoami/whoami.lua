#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- whoami - the name behind the effective user id
local prefix = ((arg[0] or "whoami"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local pwd = require("posix.pwd")
local util = require("luaposixcli.util")

if #arg > 0 then util.die("usage: whoami", 2) end

local uid = unistd.geteuid()
local entry = pwd.getpwuid(uid)
if not entry then
	util.die("cannot find a name for user id " .. uid)
end
unistd.write(1, entry.pw_name .. "\n")
