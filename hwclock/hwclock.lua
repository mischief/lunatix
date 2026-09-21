#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- hwclock - the clock on the board, which keeps time while the machine
-- is off. The kernel starts with no idea what time it is.
local prefix = ((arg[0] or "hwclock"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local ptime = require("posix.time")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local device = "/dev/rtc0"
local show, to_system, to_hardware = false, false, false
local local_time = false

local function usage()
	util.die("usage: hwclock [-r] [-s] [-w] [-u|-l] [-f device]", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "rswulf:") do
	if opt == "r" then show = true
	elseif opt == "s" then to_system = true
	elseif opt == "w" then to_hardware = true
	elseif opt == "u" then local_time = false
	elseif opt == "l" then local_time = true
	elseif opt == "f" then device = optarg
	else usage() end
	optind = oi
end
if #util.operands(arg, optind) > 0 then usage() end
if not (show or to_system or to_hardware) then show = true end
if (to_system and to_hardware) then usage() end

-- struct rtc_time is nine ints: the fields of a struct tm, with the
-- month counted from zero and the year from 1900.
local RTC_TIME = "i4i4i4i4i4i4i4i4i4"

local function open_rtc()
	local fd, err = fcntl.open(device, fcntl.O_RDONLY)
	if not fd then util.die(tostring(err)) end
	return fd
end

-- The fields the clock holds, read as the zone the machine keeps it in.
-- A clock set to UTC and one set to local time hold the same nine
-- numbers; only the machine's own idea of which it is tells them apart.
local function fields_to_epoch(sec, min, hour, mday, mon, year)
	local tm = { tm_sec = sec, tm_min = min, tm_hour = hour,
		tm_mday = mday, tm_mon = mon, tm_year = year, tm_isdst = -1 }
	local when = ptime.mktime(tm)
	if not when then util.die("the clock holds no date") end
	if not local_time then
		-- mktime read it as local time, so take the zone back out. The
		-- UTC fields carry isdst false; dropping it lets mktime work the
		-- flag out for that date, or the answer is an hour out all
		-- summer.
		local there = os.date("!*t", when)
		there.isdst = nil
		when = when + (when - os.time(there))
	end
	return when
end

local function read_clock()
	local fd = open_rtc()
	local data, err = sys.ioctlbuf(fd, sys.RTC_RD_TIME, 36)
	unistd.close(fd)
	if not data then util.die(tostring(err)) end
	local sec, min, hour, mday, mon, year = string.unpack(RTC_TIME, data)
	return fields_to_epoch(sec, min, hour, mday, mon, year)
end

local function write_clock(when)
	local t = os.date(local_time and "*t" or "!*t", when)
	local data = string.pack(RTC_TIME, t.sec, t.min, t.hour, t.day,
		t.month - 1, t.year - 1900, 0, 0, 0)
	local fd, err = fcntl.open(device, fcntl.O_WRONLY)
	if not fd then util.die(tostring(err)) end
	local ok, ierr = sys.ioctlbuf(fd, sys.RTC_SET_TIME, data)
	unistd.close(fd)
	if not ok then util.die(tostring(ierr)) end
end

if to_hardware then
	write_clock(os.time())
elseif to_system then
	local ok, err = sys.settime(read_clock())
	if not ok then util.die(tostring(err)) end
else
	local when = read_clock()
	unistd.write(1, os.date("%a %b %e %H:%M:%S %Y", when) .. "\n")
end
