#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- getty - open a terminal, put a session on it, and hand it to login
local prefix = ((arg[0] or "getty"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local termio = require("posix.termio")
local stdlib = require("posix.stdlib")
local util = require("luaposixcli.util")

local operands = {}
for _, a in ipairs(arg) do
	if a:sub(1, 1) == "-" and #a > 1 then
		-- a baud rate written as an option, which agetty takes and
		-- which nothing here can act on: the line speed is the
		-- kernel's business
	else
		operands[#operands + 1] = a
	end
end

-- agetty is called either way round, so take whichever operand looks
-- like a device
local device, term
for _, a in ipairs(operands) do
	if a:sub(1, 1) == "/" or a:match("^tty") or a:match("^console") then
		device = device or a
	elseif not a:match("^%d+$") then
		term = term or a
	end
end

if not device then
	util.die("usage: getty [baud] tty [term]")
end
if device:sub(1, 1) ~= "/" then device = "/dev/" .. device end

-- A new session, so that opening the terminal makes it the controlling
-- one: that is what lets a shell here take a signal from the keyboard.
unistd.setpid("s")

local fd, err = fcntl.open(device, fcntl.O_RDWR)
if not fd then util.die(device .. ": " .. tostring(err)) end
unistd.dup2(fd, 0)
unistd.dup2(fd, 1)
unistd.dup2(fd, 2)
if fd > 2 then unistd.close(fd) end

-- cooked, echoing, signals on: what a person expects to type into
local attrs = termio.tcgetattr(0)
if attrs then
	attrs.iflag = attrs.iflag | termio.ICRNL | termio.BRKINT
	attrs.oflag = attrs.oflag | termio.OPOST | termio.ONLCR
	attrs.lflag = attrs.lflag | termio.ICANON | termio.ECHO | termio.ECHOE
		| termio.ISIG | termio.IEXTEN
	termio.tcsetattr(0, termio.TCSANOW, attrs)
end

stdlib.setenv("TERM", term or os.getenv("TERM") or "vt100")

local login = "/bin/login"
if unistd.access(login, "x") ~= 0 then login = "/usr/bin/login" end
unistd.exec(login, {})
util.die(login .. ": cannot execute")
