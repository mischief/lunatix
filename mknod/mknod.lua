#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- mknod - make a device node, or a fifo
local prefix = ((arg[0] or "mknod"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local stat = require("posix.sys.stat")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local kinds = {
	b = stat.S_IFBLK,
	c = stat.S_IFCHR,
	u = stat.S_IFCHR, -- unbuffered, which is the same thing on Linux
	p = stat.S_IFIFO,
}

local mode = nil

local function usage()
	util.die("usage: mknod [-m mode] name b|c|u major minor\n" ..
		"       mknod [-m mode] name p", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "m:") do
	if opt == "m" then mode = optarg
	else usage() end
	optind = oi
end
local operands = util.operands(arg, optind)

local name, kind = operands[1], operands[2]
if not name or not kind or not kinds[kind] then usage() end

-- 666 before the umask, the same as a file made by a redirect
local bits = tonumber("666", 8)
if mode then
	bits = tonumber(mode, 8) or util.die("bad mode: " .. mode)
end

local major, minor = 0, 0
if kind == "p" then
	if #operands ~= 2 then usage() end
else
	if #operands ~= 4 then usage() end
	major = tonumber(operands[3]) or util.die("bad major: " .. operands[3])
	minor = tonumber(operands[4]) or util.die("bad minor: " .. operands[4])
end

local ok, err = sys.mknod(name, kinds[kind] | bits, major, minor)
if not ok then util.die(name .. ": " .. tostring(err)) end
