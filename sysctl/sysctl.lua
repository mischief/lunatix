#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- sysctl - the kernel knobs under /proc/sys
local prefix = ((arg[0] or "sysctl"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local dirent = require("posix.dirent")
local stat = require("posix.sys.stat")
local util = require("luaposixcli.util")

local ROOT = "/proc/sys"

local all, quiet, write_mode, names_only = false, false, false, false
local operands = {}

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "--" then
		for j = i + 1, #arg do operands[#operands + 1] = arg[j] end
		break
	elseif a:sub(1, 1) == "-" and #a > 1 then
		for c in a:sub(2):gmatch(".") do
			if c == "a" or c == "A" then all = true
			elseif c == "w" then write_mode = true
			elseif c == "q" then quiet = true
			elseif c == "N" then names_only = true
			elseif c == "e" then -- ignore what is not there, which is the default here
			else util.die("usage: sysctl [-aqwN] [name[=value]...]", 2) end
		end
	else
		operands[#operands + 1] = a
	end
	i = i + 1
end

local function path_of(name)
	return ROOT .. "/" .. name:gsub("%.", "/")
end

local function name_of(path)
	return path:sub(#ROOT + 2):gsub("/", ".")
end

local function show(name, value)
	if quiet then return end
	if names_only then
		unistd.write(1, name .. "\n")
	else
		unistd.write(1, name .. " = " .. value .. "\n")
	end
end

local function read_one(name)
	local text = util.slurp(path_of(name))
	if not text then return nil end
	return (text:gsub("\n$", ""):gsub("\n", "\t"))
end

local status = 0

if all then
	-- everything readable under /proc/sys, in the order the tree gives
	local function walk(path)
		local names = dirent.dir(path)
		if not names then return end
		table.sort(names)
		for _, entry in ipairs(names) do
			if entry ~= "." and entry ~= ".." then
				local full = path .. "/" .. entry
				local st = stat.stat(full)
				if st and stat.S_ISDIR(st.st_mode) ~= 0 then
					walk(full)
				elseif st then
					local value = util.slurp(full)
					if value then
						show(name_of(full), (value:gsub("\n$", ""):gsub("\n", "\t")))
					end
				end
			end
		end
	end
	walk(ROOT)
	os.exit(0)
end

if #operands == 0 then
	util.die("usage: sysctl [-aqwN] [name[=value]...]", 2)
end

for _, operand in ipairs(operands) do
	local name, value = operand:match("^([^=]+)=(.*)$")
	if name or write_mode then
		name = name or operand
		if not value then util.die(operand .. ": no value to set") end
		local f = io.open(path_of(name), "w")
		if not f then
			util.warn(name .. ": cannot set")
			status = 1
		else
			f:write(value)
			local ok = f:close()
			if not ok then
				util.warn(name .. ": cannot set")
				status = 1
			else
				show(name, value)
			end
		end
	else
		local current = read_one(operand)
		if not current then
			util.warn(operand .. ": cannot read")
			status = 1
		else
			show(operand, current)
		end
	end
end
os.exit(status)
