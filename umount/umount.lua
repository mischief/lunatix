#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- umount - detach a filesystem
local prefix = ((arg[0] or "umount"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local all, fstype = false, nil

local function usage()
	util.die("usage: umount [-a] [-t type] target...")
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "at:") do
	if opt == "a" then all = true
	elseif opt == "t" then fstype = optarg
	else usage() end
	optind = oi
end
local targets = util.operands(arg, optind)

-- What is mounted, in the order the kernel lists it. -a works backwards
-- through this, so a filesystem mounted over another comes off first.
local function mounted()
	local list = {}
	local text = util.slurp("/proc/self/mounts") or ""
	for line in util.lines(text) do
		local target, kind = line:match("^%S+ (%S+) (%S+)")
		if target then
			-- the kernel writes a space as \040
			target = target:gsub("\\040", " ")
			list[#list + 1] = { target = target, kind = kind }
		end
	end
	return list
end

if all then
	if #targets > 0 then usage() end
	-- / and the kernel's own filesystems stay: taking them away is what
	-- reboot does, and this is not reboot.
	local keep = { ["/"] = true, ["/proc"] = true, ["/sys"] = true,
		["/dev"] = true, ["/run"] = true }
	local list = mounted()
	for n = #list, 1, -1 do
		local at = list[n]
		if not keep[at.target] and (not fstype or at.kind == fstype) then
			targets[#targets + 1] = at.target
		end
	end
elseif #targets == 0 then
	usage()
end

local status = 0
for _, target in ipairs(targets) do
	local ok, err = sys.umount(target)
	if not ok then
		util.warn(target .. ": " .. tostring(err))
		status = 1
	end
end
os.exit(status)
