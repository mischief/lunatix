#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- insmod, rmmod, lsmod and modprobe. Which one it is comes from argv[0].
local prefix = ((arg[0] or "insmod"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local prog = util.prog

-- What the running kernel has, from /proc/modules: name, size, use count,
-- then who is using it.
local function loaded()
	local out, by_name = {}, {}
	local text = util.slurp("/proc/modules")
	if not text then return nil, "/proc/modules: cannot read" end
	for line in util.lines(text) do
		local name, size, used, users = line:match("^(%S+) (%S+) (%S+) (%S+)")
		if name then
			local entry = {
				name = name,
				size = tonumber(size) or 0,
				used = tonumber(used) or 0,
				users = users ~= "-" and users:gsub(",$", "") or "",
			}
			out[#out + 1] = entry
			by_name[name] = entry
		end
	end
	return out, by_name
end

local function module_name(path)
	return (util.basename(path):gsub("%.ko.*$", ""):gsub("-", "_"))
end

-- The module file, decompressed if it needs to be. The kernel takes a
-- compressed module through finit_module only where it was built to;
-- handing it the bytes is what always works.
local function module_image(path)
	if path:match("%.gz$") then
		local ok, gzip = pcall(require, "luaposixcli.zlib.gzip")
		if not ok then return nil, "cannot read a compressed module" end
		local data, err = util.slurp(path)
		if not data then return nil, err end
		return gzip.decompress(data)
	end
	if path:match("%.xz$") or path:match("%.zst$") then
		return nil, path .. ": compressed with xz or zstd, which is not here"
	end
	return util.slurp(path)
end

local function insert(path, params)
	local image, err = module_image(path)
	if not image then return nil, err end
	local ok, ierr = sys.init_module(image, params or "")
	if not ok then return nil, ierr end
	return true
end

if prog == "lsmod" then
	local mods, err = loaded()
	if not mods then util.die(err) end
	unistd.write(1, string.format("%-24s %8s  %s\n", "Module", "Size", "Used by"))
	for _, m in ipairs(mods) do
		unistd.write(1, string.format("%-24s %8d %d %s\n",
			m.name, m.size, m.used, m.users))
	end
	os.exit(0)
end

if prog == "rmmod" then
	local names = {}
	for _, a in ipairs(arg) do
		if a:sub(1, 1) ~= "-" then names[#names + 1] = module_name(a) end
	end
	if #names == 0 then util.die("usage: rmmod module...") end
	local status = 0
	for _, name in ipairs(names) do
		local ok, err = sys.delete_module(name)
		if not ok then
			util.warn(name .. ": " .. tostring(err))
			status = 1
		end
	end
	os.exit(status)
end

if prog == "insmod" then
	local path = arg[1]
	if not path then util.die("usage: insmod file [parameters]") end
	local params = {}
	for i = 2, #arg do params[#params + 1] = arg[i] end
	local ok, err = insert(path, table.concat(params, " "))
	if not ok then util.die(util.basename(path) .. ": " .. tostring(err)) end
	os.exit(0)
end

-- modprobe: the name rather than the path, and whatever it depends on
-- first. modules.dep lists each module with the ones it needs, deepest
-- last, all relative to the module directory.
local function release()
	local f = io.popen("uname -r 2>/dev/null")
	local r = f and f:read("l")
	if f then f:close() end
	if r and r ~= "" then return r end
	local text = util.slurp("/proc/sys/kernel/osrelease")
	return text and text:gsub("%s+$", "")
end

local remove = false
local wanted = {}
for _, a in ipairs(arg) do
	if a == "-r" then remove = true
	elseif a:sub(1, 1) == "-" and #a > 1 then
		util.die("usage: modprobe [-r] module...")
	else
		wanted[#wanted + 1] = a
	end
end
if #wanted == 0 then util.die("usage: modprobe [-r] module...") end

local dir = "/lib/modules/" .. (release() or "")
local deps = {}
local dep_text = util.slurp(dir .. "/modules.dep")
if dep_text then
	for line in util.lines(dep_text) do
		local path, rest = line:match("^([^:]+):%s*(.*)$")
		if path then
			local needs = {}
			for need in (rest or ""):gmatch("%S+") do needs[#needs + 1] = need end
			deps[module_name(path)] = { path = path, needs = needs }
		end
	end
end

local status = 0
for _, name in ipairs(wanted) do
	name = name:gsub("-", "_")
	if remove then
		local ok, err = sys.delete_module(name)
		if not ok then
			util.warn(name .. ": " .. tostring(err))
			status = 1
		end
	else
		local entry = deps[name]
		if not entry then
			util.warn(name .. ": not found in " .. dir .. "/modules.dep")
			status = 1
		else
			local _, by_name = loaded()
			-- what it needs, deepest first
			for i = #entry.needs, 1, -1 do
				local need = entry.needs[i]
				if not (by_name or {})[module_name(need)] then
					insert(dir .. "/" .. need, "")
				end
			end
			if not (by_name or {})[name] then
				local ok, err = insert(dir .. "/" .. entry.path, "")
				if not ok then
					util.warn(name .. ": " .. tostring(err))
					status = 1
				end
			end
		end
	end
end
os.exit(status)
