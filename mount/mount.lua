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
local all = false
local fstab = "/etc/fstab"
local operands = {}

local function usage()
	util.die("usage: mount [-a] [-T fstab] [-t type] [-o options] source target")
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "at:o:T:") do
	if opt == "a" then all = true
	elseif opt == "t" then fstype = optarg
	elseif opt == "o" then options = optarg
	elseif opt == "T" then fstab = optarg
	else usage() end
	optind = oi
end
operands = util.operands(arg, optind)

-- The flags an -o list names, and whatever is left for the filesystem
local function split_options(text)
	local flags, data = 0, {}
	for opt in (text or ""):gmatch("[^,]+") do
		local flag = flag_names[opt]
		if flag then
			flags = flags | flag
		else
			data[#data + 1] = opt
		end
	end
	return flags, #data > 0 and table.concat(data, ",") or nil
end

local function already_mounted(target)
	local text = util.slurp("/proc/self/mounts") or ""
	for line in util.lines(text) do
		local at = line:match("^%S+ (%S+)")
		if at == target then return true end
	end
	return false
end

-- -a mounts what fstab says to, in the order it says it, skipping what
-- is mounted already and what is marked noauto.
if all then
	local text = util.slurp(fstab)
	if not text then util.die(fstab .. ": cannot read") end
	local status = 0
	for line in util.lines(text) do
		line = line:gsub("#.*$", "")
		local source, target, kind, opts = line:match("^%s*(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
		if source and kind ~= "swap" and target ~= "none" then
			local skip = opts:find("noauto", 1, true) ~= nil
			if fstype and kind ~= fstype then skip = true end
			if not skip and not already_mounted(target) then
				local flags, data = split_options(opts ~= "" and opts or nil)
				local ok, err = sys.mount(source, target, kind, flags, data)
				if not ok then
					util.warn(target .. ": " .. tostring(err))
					status = 1
				end
			end
		end
	end
	os.exit(status)
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

if #operands ~= 2 then usage() end

local source, target = operands[1], operands[2]
local flags, data_text = split_options(options)
local data = data_text and { data_text } or {}

local ok, err = sys.mount(source, target, fstype or "auto", flags,
	#data > 0 and table.concat(data, ",") or nil)
if not ok then
	util.die(target .. ": " .. tostring(err))
end
