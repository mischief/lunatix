#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- hostname - say what this machine is called, or name it
local prefix = ((arg[0] or "hostname"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local utsname = require("posix.sys.utsname")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local from_file = nil
local name = nil

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "-F" or a == "-f" then
		i = i + 1
		from_file = arg[i] or util.die("usage: hostname [-F file] [name]")
	elseif a:sub(1, 1) == "-" and #a > 1 then
		util.die("usage: hostname [-F file] [name]")
	else
		name = a
	end
	i = i + 1
end

if from_file then
	local text = util.slurp(from_file)
	if not text then util.die(from_file .. ": cannot read") end
	name = text:match("^%s*(%S+)")
end

if not name then
	unistd.write(1, (utsname.uname().nodename or "") .. "\n")
	os.exit(0)
end

local ok, err = sys.sethostname(name)
if not ok then util.die(tostring(err)) end
