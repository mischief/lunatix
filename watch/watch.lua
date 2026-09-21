#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- watch - run a command over and over and show the last answer
local prefix = ((arg[0] or "watch"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local poll = require("posix.poll")
local time = require("posix.time")
local sys = require("luaposixcli.sys")
local term = require("luaposixcli.term")
local util = require("luaposixcli.util")

local interval, no_title, exit_on_change = 2, false, false

local function usage()
	util.die("usage: watch [-n seconds] [-tg] command...", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "n:tg") do
	if opt == "n" then interval = tonumber(optarg) or usage()
	elseif opt == "t" then no_title = true
	elseif opt == "g" then exit_on_change = true
	else usage() end
	optind = oi
end

local command = util.operands(arg, optind)
if #command == 0 then usage() end
local line = table.concat(command, " ")

-- the terminal is where this is watched from, and the keyboard with it
if unistd.isatty(1) ~= 1 then
	util.die("not a terminal")
end

local screen = term.new()
screen:raw()
screen:hide_cursor()

local function restore()
	screen:show_cursor()
	screen:restore()
end

local function run()
	local r, w = unistd.pipe()
	local child = unistd.fork()
	if child == 0 then
		unistd.close(r)
		unistd.dup2(w, 1)
		unistd.dup2(w, 2)
		unistd.close(w)
		unistd.execp("/bin/sh", { "-c", line })
		os.exit(127)
	end
	unistd.close(w)
	local out = util.slurp_fd(r) or ""
	unistd.close(r)
	require("posix.sys.wait").wait(child)
	return out
end

local last = nil
local ok, err = pcall(function()
	while true do
		local rows, cols = sys.winsize(1)
		rows = (rows and rows > 0) and rows or (tonumber(os.getenv("LINES")) or 24)
		cols = (cols and cols > 0) and cols or (tonumber(os.getenv("COLUMNS")) or 80)
		local output = run()

		if exit_on_change and last and output ~= last then break end
		last = output

		local out = { "\27[H" }
		local shown = 0
		if not no_title then
			local left = string.format("Every %.1fs: %s", interval, line)
			local right = os.date("%a %b %e %H:%M:%S %Y")
			local gap = cols - #left - #right
			out[#out + 1] = left .. string.rep(" ", gap > 1 and gap or 1) .. right
			out[#out + 1] = "\27[K\r\n\27[K\r\n"
			shown = 2
		end
		for text in util.lines(output) do
			if shown >= rows then break end
			out[#out + 1] = text:sub(1, cols) .. "\27[K\r\n"
			shown = shown + 1
		end
		for _ = shown, rows - 1 do out[#out + 1] = "\27[K\r\n" end
		screen:write(table.concat(out))

		-- a keypress ends the wait, and q ends the watching
		local ready = poll.poll({ [0] = { events = { IN = true } } },
			math.floor(interval * 1000))
		if ready and ready > 0 then
			local key = unistd.read(0, 1)
			if key == "q" or key == "\27" or key == nil or key == "" then break end
		end
	end
end)

restore()
screen:clear()
if not ok then util.die(tostring(err)) end
