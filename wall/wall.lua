#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- wall - say something to everybody who is logged in
local prefix = ((arg[0] or "wall"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local stat = require("posix.sys.stat")
local utmp = require("luaposixcli.utmp")
local util = require("luaposixcli.util")

local quiet = false

local function usage()
	util.die("usage: wall [-n] [file]", 2)
end

local optind = 1
for opt, _, oi in unistd.getopt(arg, "n") do
	if opt == "n" then quiet = true
	else usage() end
	optind = oi
end
local operands = util.operands(arg, optind)
if #operands > 1 then usage() end

local text = util.slurp(operands[1])
if not text then util.die((operands[1] or "-") .. ": cannot read") end

-- The banner every wall carries, so a message that arrives in the
-- middle of something says where it came from. -n leaves it off, which
-- is what a shutdown notice does.
local body = text
if not quiet then
	local from = os.getenv("USER") or os.getenv("LOGNAME") or tostring(unistd.getuid())
	local host = require("posix.sys.utsname").uname().nodename or ""
	body = string.format("\aBroadcast message from %s@%s (%s):\n\n%s",
		from, host, os.date("%a %b %e %H:%M:%S %Y"), text)
end
if body:sub(-1) ~= "\n" then body = body .. "\n" end

for _, rec in ipairs(utmp.users()) do
	local path = "/dev/" .. rec.line
	local st = stat.stat(path)
	-- root writes to everybody; anyone else writes to the terminals
	-- that left the group write bit on
	if st and ((st.st_mode & stat.S_IWGRP) ~= 0 or unistd.getuid() == 0) then
		local out = io.open(path, "w")
		if out then
			out:write(body)
			out:close()
		end
	end
end

-- Nothing to say it to is not a failure: a machine with nobody on it
-- still shuts down.
os.exit(0)
