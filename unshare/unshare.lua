#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- unshare - run a command with namespaces of its own
local prefix = ((arg[0] or "unshare"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local wait = require("posix.sys.wait")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local flags, fork_first, map_root = 0, false, false

local names = {
	m = "CLONE_NEWNS", u = "CLONE_NEWUTS", i = "CLONE_NEWIPC",
	n = "CLONE_NEWNET", p = "CLONE_NEWPID", U = "CLONE_NEWUSER",
	C = "CLONE_NEWCGROUP",
}

local i = 1
while i <= #arg do
	local a = arg[i]
	if a:sub(1, 1) == "-" and #a > 1 then
		for c in a:sub(2):gmatch(".") do
			if names[c] then
				flags = flags | (sys[names[c]] or 0)
			elseif c == "f" then fork_first = true
			elseif c == "r" then
				map_root = true
				flags = flags | (sys.CLONE_NEWUSER or 0)
			else
				util.die("usage: unshare [-muinpUCfr] utility [argument...]", 2)
			end
		end
	else
		break
	end
	i = i + 1
end

if flags == 0 then flags = sys.CLONE_NEWNS or 0 end

local uid, gid = unistd.geteuid(), unistd.getegid()

local ok, err = sys.unshare(flags)
if not ok then util.die(tostring(err)) end

-- -r says to be root inside the new user namespace, which is two files
-- and has to happen before anything else is tried
if map_root then
	local deny = io.open("/proc/self/setgroups", "w")
	if deny then deny:write("deny"); deny:close() end
	local umap = io.open("/proc/self/uid_map", "w")
	if umap then umap:write("0 " .. uid .. " 1"); umap:close() end
	local gmap = io.open("/proc/self/gid_map", "w")
	if gmap then gmap:write("0 " .. gid .. " 1"); gmap:close() end
end

local utility = arg[i] or os.getenv("SHELL") or "/bin/sh"
local rest = {}
for j = i + 1, #arg do rest[#rest + 1] = arg[j] end

-- a new pid namespace only takes effect for a child, so -f, and a pid
-- namespace without it would leave the command as pid 1 of nothing
if fork_first or (flags & (sys.CLONE_NEWPID or 0)) ~= 0 then
	local child = unistd.fork()
	if child ~= 0 then
		local _, reason, status
		repeat
			_, reason, status = wait.wait(child)
		until reason ~= nil
		os.exit(reason == "killed" and (128 + status) or (status or 0))
	end
end

unistd.execp(utility, rest)
util.die(utility .. ": cannot execute", 127)
