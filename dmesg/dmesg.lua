#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- dmesg - the kernel log, read from /dev/kmsg
local prefix = ((arg[0] or "dmesg"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local util = require("luaposixcli.util")

local timestamps, follow = true, false
for opt in unistd.getopt(arg, "tw") do
	if opt == "t" then timestamps = false
	elseif opt == "w" then follow = true
	else util.die("usage: dmesg [-t] [-w]") end
end

-- Each record is "priority,sequence,microseconds,flag;message". Reading
-- /dev/kmsg gives one record per read, and EAGAIN once the buffer is
-- drained, which is how a non-following dmesg knows where to stop.
local flags = fcntl.O_RDONLY
if not follow then flags = flags | fcntl.O_NONBLOCK end
local fd, err = fcntl.open("/dev/kmsg", flags)
if not fd then
	util.die(tostring(err))
end

while true do
	local record = unistd.read(fd, 8192)
	if not record or record == "" then break end
	local head, text = record:match("^([^;]*);(.*)$")
	if head then
		local _, _, us = head:match("^(%d+),(%d+),(%d+)")
		text = text:gsub("\n.*$", "")
		if timestamps and us then
			unistd.write(1, string.format("[%5d.%06d] %s\n",
				us // 1000000, us % 1000000, text))
		else
			unistd.write(1, text .. "\n")
		end
	end
end
unistd.close(fd)
