#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- chroot - run a command with a different root directory
local prefix = ((arg[0] or "chroot"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local dir = arg[1]
if not dir then
	util.die("usage: chroot directory [command [argument...]]")
end

local ok, err = sys.chroot(dir)
if not ok then util.die(dir .. ": " .. tostring(err)) end
-- chroot moves the root but not the working directory, and a process
-- left standing outside it can walk back out
unistd.chdir("/")

local command = arg[2] or os.getenv("SHELL") or "/bin/sh"
local rest = {}
for i = 3, #arg do rest[#rest + 1] = arg[i] end
unistd.execp(command, rest)
util.die(command .. ": cannot execute")
