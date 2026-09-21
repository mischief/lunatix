#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- swapon, swapoff and mkswap. Which one it is comes from argv[0].
local prefix = ((arg[0] or "swapon"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local stat = require("posix.sys.stat")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local prog = util.prog

if prog == "mkswap" then
	local device = arg[1]
	if not device or device:sub(1, 1) == "-" then
		util.die("usage: mkswap device", 2)
	end
	local st = stat.stat(device)
	if not st then util.die(device .. ": No such file or directory") end

	-- The header the kernel looks for: version 1, the page count, and
	-- the signature at the end of the first page. A page is 4096 here,
	-- which is what every machine this runs on uses.
	local page = 4096
	local size = st.st_size
	if size == 0 then
		-- a block device has no size in stat, so ask by seeking
		local fd = fcntl.open(device, fcntl.O_RDONLY)
		if fd then
			size = tonumber(util.slurp("/sys/class/block/" ..
				util.basename(device) .. "/size") or "0") * 512
			unistd.close(fd)
		end
	end
	local pages = size // page
	if pages < 10 then util.die(device .. ": too small to be swap") end

	-- the uuid is what blkid names the area by; zeros would make every
	-- swap area on the machine the same one
	local uuid = string.rep("\0", 16)
	local f_urandom = io.open("/dev/urandom", "rb")
	if f_urandom then
		uuid = f_urandom:read(16) or uuid
		f_urandom:close()
	end

	local header = string.rep("\0", 1024)
		.. string.pack("<I4I4I4", 1, pages - 1, 0)
		.. uuid
		.. string.rep("\0", 1024 - 12 - 16)
	local f, err = io.open(device, "r+b")
	if not f then
		f, err = io.open(device, "wb")
		if not f then util.die(err or (device .. ": cannot write")) end
	end
	f:seek("set", 0)
	f:write(header)
	f:seek("set", page - 10)
	f:write("SWAPSPACE2")
	f:close()
	unistd.write(1, string.format("Setting up swapspace version 1, size = %d bytes\n",
		(pages - 1) * page))
	os.exit(0)
end

-- swapon with nothing to do says what is in use, from /proc/swaps
if prog == "swapon" and #arg == 0 then
	local text = util.slurp("/proc/swaps")
	if not text then util.die("/proc/swaps: cannot read") end
	unistd.write(1, text)
	os.exit(0)
end

local devices = {}
local all = false
for _, a in ipairs(arg) do
	if a == "-a" then all = true
	elseif a:sub(1, 1) == "-" and #a > 1 then
		util.die("usage: " .. prog .. " [-a] [device...]", 2)
	else
		devices[#devices + 1] = a
	end
end

-- -a is everything /etc/fstab calls swap
if all then
	local text = util.slurp("/etc/fstab") or ""
	for line in util.lines(text) do
		local device, kind = line:match("^%s*(%S+)%s+%S+%s+(%S+)")
		if kind == "swap" then devices[#devices + 1] = device end
	end
end

if #devices == 0 then
	util.die("usage: " .. prog .. " [-a] [device...]", 2)
end

local status = 0
for _, device in ipairs(devices) do
	local ok, err
	if prog == "swapoff" then
		ok, err = sys.swapoff(device)
	else
		ok, err = sys.swapon(device, 0)
	end
	if not ok then
		util.warn(device .. ": " .. tostring(err))
		status = 1
	end
end
os.exit(status)
