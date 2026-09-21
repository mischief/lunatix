#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- nproc - how many processors this machine will run things on
local prefix = ((arg[0] or "nproc"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local all = false
for _, a in ipairs(arg) do
	if a == "--all" then all = true
	else util.die("usage: nproc [--all]", 2) end
end

-- The list the kernel keeps, which counts what is online rather than
-- what is fitted; --all is the other one.
local which = all and "present" or "online"
local text = util.slurp("/sys/devices/system/cpu/" .. which)
local count = 0
if text then
	for range in text:gmatch("[^,%s]+") do
		local from, to = range:match("^(%d+)-(%d+)$")
		if from then
			count = count + (tonumber(to) - tonumber(from) + 1)
		elseif range:match("^%d+$") then
			count = count + 1
		end
	end
end

if count == 0 then
	local cpuinfo = util.slurp("/proc/cpuinfo") or ""
	for _ in cpuinfo:gmatch("\nprocessor%s*:") do count = count + 1 end
	if cpuinfo:match("^processor%s*:") then count = count + 1 end
end

unistd.write(1, tostring(count > 0 and count or 1) .. "\n")
