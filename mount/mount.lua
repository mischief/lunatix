#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- mount - attach a filesystem. With no arguments, say what is mounted.
local prefix = ((arg[0] or "mount"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

-- Names for the flags an -o option can set. Anything not here is passed
-- to the filesystem as data, which is where fs-specific options belong.
local flag_names = {
	ro = sys.MS_RDONLY,
	rw = 0,
	nosuid = sys.MS_NOSUID,
	nodev = sys.MS_NODEV,
	noexec = sys.MS_NOEXEC,
	noatime = sys.MS_NOATIME,
	remount = sys.MS_REMOUNT,
	bind = sys.MS_BIND,
	defaults = 0,
}

local fstype, options = nil, nil
local operands = {}

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "--" then
		for j = i + 1, #arg do operands[#operands + 1] = arg[j] end
		break
	elseif a:sub(1, 2) == "-t" or a:sub(1, 2) == "-o" then
		local which = a:sub(2, 2)
		local value = a:sub(3)
		if value == "" then
			i = i + 1
			value = arg[i]
		end
		if not value then util.die("usage: mount [-t type] [-o options] source target") end
		if which == "t" then fstype = value else options = value end
	elseif a:sub(1, 1) == "-" and #a > 1 then
		util.die("usage: mount [-t type] [-o options] source target")
	else
		operands[#operands + 1] = a
	end
	i = i + 1
end

-- with nothing to do, report what the kernel says is mounted
if #operands == 0 then
	local data = util.slurp("/proc/self/mounts") or util.slurp("/proc/mounts")
	if not data then util.die("nothing to mount, and /proc/mounts is not readable") end
	for line in util.lines(data) do
		local source, target, kind, opts = line:match("^(%S+) (%S+) (%S+) (%S+)")
		if source then
			unistd.write(1, string.format("%s on %s type %s (%s)\n",
				source, target, kind, opts))
		end
	end
	os.exit(0)
end

if #operands ~= 2 then
	util.die("usage: mount [-t type] [-o options] source target")
end

local source, target = operands[1], operands[2]
local flags, data = 0, {}
for opt in (options or ""):gmatch("[^,]+") do
	local flag = flag_names[opt]
	if flag then
		flags = flags | flag
	else
		data[#data + 1] = opt
	end
end

local ok, err = sys.mount(source, target, fstype or "auto", flags,
	#data > 0 and table.concat(data, ",") or nil)
if not ok then
	util.die(target .. ": " .. tostring(err))
end
