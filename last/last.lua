#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- last - the logins the machine remembers, newest first
local prefix = ((arg[0] or "last"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local utmp = require("luaposixcli.utmp")
local util = require("luaposixcli.util")

local limit = nil
local file = utmp.WTMP

local function usage()
	util.die("usage: last [-n count] [-f file] [name | tty]...", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "n:f:") do
	if opt == "n" then limit = tonumber(optarg) or usage()
	elseif opt == "f" then file = optarg
	else usage() end
	optind = oi
end
local wanted = util.operands(arg, optind)

-- -5 is the other spelling of -n 5, and getopt has no way to say so
for i = #wanted, 1, -1 do
	local n = wanted[i]:match("^%-(%d+)$")
	if n then
		limit = tonumber(n)
		table.remove(wanted, i)
	end
end

local records = utmp.read(file)
if #records == 0 then util.die(file .. ": cannot read") end

-- A session with no logout record is either one that is still going,
-- which the live records say so, or one the machine lost track of.
local live = {}
for _, rec in ipairs(utmp.users()) do
	live[rec.line .. " " .. rec.time] = true
end

local function matches(rec)
	if #wanted == 0 then return true end
	for _, name in ipairs(wanted) do
		if rec.user == name or rec.line == name then return true end
	end
	return false
end

local function span(from, to)
	local seconds = to - from
	if seconds < 0 then return "" end
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return string.format("(%d+%02d:%02d)", days, hours, minutes)
	end
	return string.format("(%02d:%02d)", hours, minutes)
end

-- A session ends when a DEAD_PROCESS lands on the same line, or a boot
-- record says the machine went down under it. Working backwards means
-- the end of a session is seen before its start.
local ends = {}
local out = {}
local shown = 0
local down = nil
local shutdown_at = nil

-- A session that has not ended has no end time to put a dash between,
-- so the words go where the time would have been.
local function add(user, line, host, from, how, still)
	out[#out + 1] = string.format("%-8s %-12s %-16s %s %s%s",
		user, line, host, os.date("%a %b %e %H:%M", from),
		still and "  " or "- ", how)
	shown = shown + 1
	return not limit or shown < limit
end

local function ended(at, from)
	return string.format("%s %8s", os.date("%H:%M", at), span(from, at))
end

for i = #records, 1, -1 do
	local rec = records[i]
	if rec.type == utmp.RUN_LVL then
		shutdown_at = rec.time
	elseif rec.type == utmp.BOOT_TIME then
		if matches({ user = "reboot", line = "system boot" }) then
			local how = shutdown_at and ended(shutdown_at, rec.time) or "still running"
			if not add("reboot", "system boot", rec.host, rec.time, how,
				shutdown_at == nil) then break end
		end
		-- everything before a boot belongs to the machine's last life
		down = rec.time
		shutdown_at = nil
		ends = {}
	elseif rec.type == utmp.DEAD_PROCESS then
		ends[rec.line] = rec.time
	elseif rec.type == utmp.USER_PROCESS and rec.user ~= "" and matches(rec) then
		local finish, how = ends[rec.line], nil
		if finish then
			how = ended(finish, rec.time)
		elseif down then
			how = string.format("down %9s", span(rec.time, down))
		elseif live[rec.line .. " " .. rec.time] then
			how = "still logged in"
		else
			-- one space further along than the other two, which is
			-- where last has always put it
			how = " gone - no logout"
		end
		ends[rec.line] = nil
		if not add(rec.user, rec.line, rec.host, rec.time, how,
			finish == nil and down == nil) then break end
	end
end

for _, line in ipairs(out) do unistd.write(1, line .. "\n") end

if #records > 0 then
	unistd.write(1, "\n" .. util.basename(file) .. " begins " ..
		os.date("%a %b %e %H:%M:%S %Y", records[1].time) .. "\n")
end
