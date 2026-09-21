#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- losetup - put a file behind a block device, so it can be mounted
local prefix = ((arg[0] or "losetup"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local stat = require("posix.sys.stat")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local detach, find_free, show = false, false, false
local operands = {}

local function usage()
	util.die("usage: losetup [-d device] [-f] [-a] [device file]", 2)
end

local optind = 1
for opt, _, oi in unistd.getopt(arg, "dfa") do
	if opt == "d" then detach = true
	elseif opt == "f" then find_free = true
	elseif opt == "a" then show = true
	else usage() end
	optind = oi
end
operands = util.operands(arg, optind)

-- what /sys says is in use, which is where the kernel keeps it
local function backing(device)
	local name = util.basename(device)
	local text = util.slurp("/sys/block/" .. name .. "/loop/backing_file")
	return text and text:gsub("%s+$", "")
end

local function each_loop()
	local names = {}
	for _, name in ipairs(require("posix.dirent").dir("/sys/block") or {}) do
		if name:match("^loop%d+$") then names[#names + 1] = name end
	end
	table.sort(names)
	return names
end

if show then
	for _, name in ipairs(each_loop()) do
		local file = backing("/dev/" .. name)
		if file and file ~= "" then
			unistd.write(1, "/dev/" .. name .. ": " .. file .. "\n")
		end
	end
	os.exit(0)
end

-- -f asks the kernel for a device nothing is using
local function free_device()
	local control = fcntl.open("/dev/loop-control", fcntl.O_RDWR)
	if control then
		local n = sys.ioctl(control, sys.LOOP_CTL_GET_FREE, 0)
		unistd.close(control)
		if n and n >= 0 then return "/dev/loop" .. n end
	end
	for _, name in ipairs(each_loop()) do
		local file = backing("/dev/" .. name)
		if not file or file == "" then return "/dev/" .. name end
	end
	return nil
end

if detach then
	local device = operands[1] or usage()
	local fd, err = fcntl.open(device, fcntl.O_RDWR)
	if not fd then util.die(err or (device .. ": cannot open")) end
	local ok, ierr = sys.ioctl(fd, sys.LOOP_CLR_FD, 0)
	unistd.close(fd)
	if not ok then util.die(device .. ": " .. tostring(ierr)) end
	os.exit(0)
end

if find_free and #operands == 0 then
	local device = free_device()
	if not device then util.die("no free loop device") end
	unistd.write(1, device .. "\n")
	os.exit(0)
end

local device, file
if find_free then
	device = free_device()
	if not device then util.die("no free loop device") end
	file = operands[1]
else
	device, file = operands[1], operands[2]
end

if not device then usage() end

-- with only a device, say what is behind it
if not file then
	local behind = backing(device)
	if not behind or behind == "" then os.exit(1) end
	unistd.write(1, device .. ": " .. behind .. "\n")
	os.exit(0)
end

if not stat.stat(file) then util.die(file .. ": No such file or directory") end

local backing_fd, ferr = fcntl.open(file, fcntl.O_RDWR)
if not backing_fd then util.die(ferr or (file .. ": cannot open")) end
local device_fd, derr = fcntl.open(device, fcntl.O_RDWR)
if not device_fd then
	unistd.close(backing_fd)
	util.die(derr or (device .. ": cannot open"))
end

local ok, err = sys.ioctl(device_fd, sys.LOOP_SET_FD, backing_fd)
unistd.close(backing_fd)
unistd.close(device_fd)
if not ok then util.die(device .. ": " .. tostring(err)) end
if find_free then unistd.write(1, device .. "\n") end
