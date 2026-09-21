#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- install - copy a file into place with the mode and owner it should have
local prefix = ((arg[0] or "install"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local stat = require("posix.sys.stat")
local pwd = require("posix.pwd")
local grp = require("posix.grp")
local util = require("luaposixcli.util")

local make_dirs, mode, owner, group = false, nil, nil, nil
local operands = {}

local function usage()
	util.die("usage: install [-d] [-m mode] [-o owner] [-g group] source... target")
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "dDpcvsm:o:g:") do
	if opt == "d" then make_dirs = true
	elseif opt == "D" or opt == "p" or opt == "c" or opt == "v" or opt == "s" then
		-- -D makes the leading directories, which is done anyway; the
		-- rest are about preserving, verbosity and stripping
	elseif opt == "m" then mode = optarg
	elseif opt == "o" then owner = optarg
	elseif opt == "g" then group = optarg
	else usage() end
	optind = oi
end
operands = util.operands(arg, optind)

if #operands == 0 then usage() end

local function parse_mode(text)
	local n = tonumber(text, 8)
	if not n then util.die("bad mode: " .. text) end
	return n
end

-- every directory on the way, the way mkdir -p does it. The mode from -m
-- belongs to the file being installed, not to the directories leading to
-- it: a directory made 644 is one nothing can be written into.
local function mkdirs(path, dir_mode)
	local made = path:sub(1, 1) == "/" and "/" or ""
	for part in path:gmatch("[^/]+") do
		made = made == "/" and ("/" .. part) or (made == "" and part or made .. "/" .. part)
		if not stat.stat(made) then
			local ok, err = stat.mkdir(made, dir_mode or tonumber("755", 8))
			if not ok then return nil, err end
		end
	end
	return true
end

local function own(path)
	if not owner and not group then return end
	local uid = -1
	local gid = -1
	if owner then
		local entry = pwd.getpwnam(owner) or (tonumber(owner) and { pw_uid = tonumber(owner) })
		if not entry then util.die("no such user: " .. owner) end
		uid = entry.pw_uid
	end
	if group then
		local entry = grp.getgrnam(group) or (tonumber(group) and { gr_gid = tonumber(group) })
		if not entry then util.die("no such group: " .. group) end
		gid = entry.gr_gid
	end
	local ok, err = unistd.chown(path, uid, gid)
	if not ok then util.warn(path .. ": " .. tostring(err)) end
end

if make_dirs then
	for _, path in ipairs(operands) do
		local ok, err = mkdirs(path, mode and parse_mode(mode) or nil)
		if not ok then util.die(path .. ": " .. tostring(err)) end
		own(path)
	end
	os.exit(0)
end

if #operands < 2 then usage() end

local target = operands[#operands]
local sources = {}
for n = 1, #operands - 1 do sources[#sources + 1] = operands[n] end

local target_stat = stat.stat(target)
local into_dir = target_stat and stat.S_ISDIR(target_stat.st_mode) ~= 0

if #sources > 1 and not into_dir then
	util.die(target .. ": not a directory")
end

for _, source in ipairs(sources) do
	local data, err = util.slurp(source)
	if not data then util.die(err or (source .. ": cannot read")) end
	local dest = into_dir and (target .. "/" .. util.basename(source)) or target
	local parent = dest:match("^(.*)/[^/]*$")
	if parent and parent ~= "" and not stat.stat(parent) then mkdirs(parent) end

	local f, werr = io.open(dest, "wb")
	if not f then util.die(werr or (dest .. ": cannot write")) end
	f:write(data)
	f:close()
	local st = stat.stat(source)
	stat.chmod(dest, mode and parse_mode(mode)
		or (st and (st.st_mode & tonumber("7777", 8))) or tonumber("755", 8))
	own(dest)
end
