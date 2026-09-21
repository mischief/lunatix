#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- which - where the shell would find a command
local prefix = ((arg[0] or "which"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local all = false
local names = {}
for _, a in ipairs(arg) do
	if a == "-a" then all = true
	elseif a:sub(1, 1) == "-" and #a > 1 then util.die("usage: which [-a] name...", 2)
	else names[#names + 1] = a end
end
if #names == 0 then util.die("usage: which [-a] name...", 2) end

local path = os.getenv("PATH") or "/bin:/usr/bin"
local status = 0

for _, name in ipairs(names) do
	local found = false
	-- a name with a slash in it is a path already, not something to look up
	if name:find("/") then
		if unistd.access(name, "x") == 0 then
			unistd.write(1, name .. "\n")
			found = true
		end
	else
		for dir in path:gmatch("[^:]+") do
			local full = dir .. "/" .. name
			if unistd.access(full, "x") == 0 then
				unistd.write(1, full .. "\n")
				found = true
				if not all then break end
			end
		end
	end
	if not found then status = 1 end
end
os.exit(status)
