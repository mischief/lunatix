#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- uptime - how long the machine has been up, and how busy it is
local prefix = ((arg[0] or "uptime"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local pretty = false
for _, a in ipairs(arg) do
	if a == "-p" then pretty = true
	elseif a == "-s" then pretty = "since"
	else util.die("usage: uptime [-p] [-s]", 2) end
end

local text = util.slurp("/proc/uptime")
if not text then util.die("/proc/uptime: cannot read") end
local seconds = math.floor(tonumber(text:match("^(%S+)")) or 0)

local days = seconds // 86400
local hours = (seconds % 86400) // 3600
local minutes = (seconds % 3600) // 60

if pretty == "since" then
	unistd.write(1, os.date("%Y-%m-%d %H:%M:%S", os.time() - seconds) .. "\n")
	os.exit(0)
end

local function plural(n, word)
	return n .. " " .. word .. (n == 1 and "" or "s")
end

if pretty then
	-- procps counts in weeks once there are enough days for one
	local parts = {}
	local weeks = days // 7
	if weeks > 0 then
		parts[#parts + 1] = plural(weeks, "week")
		days = days % 7
	end
	if days > 0 then parts[#parts + 1] = plural(days, "day") end
	if hours > 0 then parts[#parts + 1] = plural(hours, "hour") end
	parts[#parts + 1] = plural(minutes, "minute")
	unistd.write(1, "up " .. table.concat(parts, ", ") .. "\n")
	os.exit(0)
end

local load = (util.slurp("/proc/loadavg") or ""):match("^(%S+%s+%S+%s+%S+)") or "0.00 0.00 0.00"
load = load:gsub("%s+", ", ")

local how_long
if days > 0 then
	how_long = plural(days, "day") .. ", " .. string.format("%2d:%02d", hours, minutes)
else
	how_long = string.format("%2d:%02d", hours, minutes)
end

unistd.write(1, string.format(" %s up %s,  load average: %s\n",
	os.date("%H:%M:%S"), how_long, load))
