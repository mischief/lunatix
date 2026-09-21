#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- setsid - run a command in a session of its own
local prefix = ((arg[0] or "setsid"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local wait = require("posix.sys.wait")
local util = require("luaposixcli.util")

local wait_for_it = false
local optind = 1
for opt, _, oi in unistd.getopt(arg, "wcf") do
	if opt == "w" then wait_for_it = true
	elseif opt == "c" or opt == "f" then -- controlling terminal, fork anyway
	else util.die("usage: setsid [-w] utility [argument...]", 2) end
	optind = oi
end
local operands = util.operands(arg, optind)

local utility = operands[1]
if not utility then util.die("usage: setsid [-w] utility [argument...]", 2) end

local rest = {}
for j = 2, #operands do rest[#rest + 1] = operands[j] end

-- setsid(2) refuses when the caller already leads its session, so the
-- work happens in a child, which never does
local child = unistd.fork()
if child == 0 then
	unistd.setpid("s")
	unistd.execp(utility, rest)
	util.die(utility .. ": cannot execute", 127)
end

if not wait_for_it then os.exit(0) end

local _, reason, status
repeat
	_, reason, status = wait.wait(child)
until reason ~= nil
if reason == "killed" then os.exit(128 + status) end
os.exit(status or 0)
