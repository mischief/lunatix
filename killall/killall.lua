#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- killall and pkill - signal processes by name. killall wants the whole
-- name, pkill takes a pattern, which is the difference between them.
local prefix = ((arg[0] or "killall"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local signal = require("posix.signal")
local unistd = require("posix.unistd")
local list = require("ps.list")
local util = require("luaposixcli.util")

local signals = {
	HUP = signal.SIGHUP, INT = signal.SIGINT, QUIT = signal.SIGQUIT,
	KILL = signal.SIGKILL, TERM = signal.SIGTERM, USR1 = signal.SIGUSR1,
	USR2 = signal.SIGUSR2, STOP = signal.SIGSTOP, CONT = signal.SIGCONT,
}

local sig = signal.SIGTERM
local names = {}
local quiet = false

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "-l" then
		local out = {}
		for k in pairs(signals) do out[#out + 1] = k end
		table.sort(out)
		unistd.write(1, table.concat(out, " ") .. "\n")
		os.exit(0)
	elseif a == "-q" then
		quiet = true
	elseif a:sub(1, 1) == "-" and #a > 1 then
		local spec = a:sub(2):upper()
		spec = spec:gsub("^SIG", "")
		local n = tonumber(a:sub(2)) or signals[spec]
		if not n then util.die("unknown signal: " .. a) end
		sig = n
	else
		names[#names + 1] = a
	end
	i = i + 1
end

if #names == 0 then
	util.die("usage: " .. util.prog .. " [-signal] [-q] name...")
end

local procs, err = list.procs()
if not procs then util.die(err) end

local me = unistd.getpid()
local matched = false
local pattern = (util.prog == "pkill")

for _, name in ipairs(names) do
	for _, p in ipairs(procs) do
		local hit
		if pattern then
			hit = p.comm:find(name) ~= nil
		else
			hit = p.comm == name
		end
		if hit and p.pid ~= me then
			matched = true
			local ok, kerr = signal.kill(p.pid, sig)
			if not ok and not quiet then
				util.warn(name .. " (" .. p.pid .. "): " .. tostring(kerr))
			end
		end
	end
end

if not matched then
	if not quiet then util.warn(names[1] .. ": no process found") end
	os.exit(1)
end
