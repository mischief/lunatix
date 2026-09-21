#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- pidof - the process ids of a named program
local prefix = ((arg[0] or "pidof"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local list = require("ps.list")
local util = require("luaposixcli.util")

local single, omit = false, {}
local names = {}

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "-s" then single = true
	elseif a == "-o" then
		i = i + 1
		for pid in (arg[i] or ""):gmatch("%d+") do omit[tonumber(pid)] = true end
	elseif a == "-x" then -- scripts as well as programs, which is what we do anyway
	elseif a:sub(1, 1) == "-" and #a > 1 then
		util.die("usage: pidof [-s] [-o pid] name...", 2)
	else
		names[#names + 1] = a
	end
	i = i + 1
end

if #names == 0 then util.die("usage: pidof [-s] [-o pid] name...", 2) end

local procs, err = list.procs()
if not procs then util.die(err) end

-- newest first, which is what pidof answers with
table.sort(procs, function(a, b) return a.pid > b.pid end)

local found = {}
for _, name in ipairs(names) do
	local want = util.basename(name)
	for _, p in ipairs(procs) do
		if p.comm == want and not omit[p.pid] then
			found[#found + 1] = tostring(p.pid)
			if single then break end
		end
	end
	if single and #found > 0 then break end
end

if #found == 0 then os.exit(1) end
unistd.write(1, table.concat(found, " ") .. "\n")
