#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- free - what the machine has done with its memory
local prefix = ((arg[0] or "free"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local unit, name = 1, "k"
for _, a in ipairs(arg) do
	if a == "-b" then unit, name = 1024, "b"
	elseif a == "-k" then unit, name = 1, "k"
	elseif a == "-m" then unit, name = 1 / 1024, "m"
	elseif a == "-g" then unit, name = 1 / 1048576, "g"
	elseif a == "-h" then unit, name = nil, "h"
	else util.die("usage: free [-bkmgh]", 2) end
end

local text = util.slurp("/proc/meminfo")
if not text then util.die("/proc/meminfo: cannot read") end

local mem = {}
for line in util.lines(text) do
	local key, value = line:match("^(%S+):%s+(%d+)")
	if key then mem[key] = tonumber(value) end
end

local function scale(kb)
	if unit then return string.format("%d", math.floor(kb * unit)) end
	-- -h picks the unit that leaves a number worth reading
	local units = { "Ki", "Mi", "Gi", "Ti" }
	local value, n = kb, 1
	while value >= 1024 and n < #units do
		value = value / 1024
		n = n + 1
	end
	return string.format("%.1f%s", value, units[n])
end

local total = mem.MemTotal or 0
local free = mem.MemFree or 0
local available = mem.MemAvailable or free
local buffers = mem.Buffers or 0
local cached = (mem.Cached or 0) + (mem.SReclaimable or 0)
-- used is what is not available, which counts the caches the kernel
-- would hand back as free rather than as used
local used = total - available
local swap_total = mem.SwapTotal or 0
local swap_free = mem.SwapFree or 0

unistd.write(1, string.format("%20s %11s %11s %11s %11s %11s\n",
	"total", "used", "free", "shared", "buff/cache", "available"))
unistd.write(1, string.format("%-8s%12s %11s %11s %11s %11s %11s\n", "Mem:",
	scale(total), scale(used), scale(free), scale(mem.Shmem or 0),
	scale(buffers + cached), scale(available)))
unistd.write(1, string.format("%-8s%12s %11s %11s\n", "Swap:",
	scale(swap_total), scale(swap_total - swap_free), scale(swap_free)))
