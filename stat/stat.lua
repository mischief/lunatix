#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- stat - what the filesystem knows about a file
local prefix = ((arg[0] or "stat"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local sys_stat = require("posix.sys.stat")
local statvfs = require("posix.sys.statvfs")
local pwd = require("posix.pwd")
local grp = require("posix.grp")
local util = require("luaposixcli.util")

local follow, terse, filesystem = false, false, false
local format = nil
local files = {}

local function usage()
	util.die("usage: stat [-Lft] [-c format] file...", 2)
end

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "--" then
		for j = i + 1, #arg do files[#files + 1] = arg[j] end
		break
	elseif a:sub(1, 2) == "-c" then
		format = a:sub(3)
		if format == "" then
			i = i + 1
			format = arg[i] or usage()
		end
	elseif a:sub(1, 1) == "-" and #a > 1 then
		for c in a:sub(2):gmatch(".") do
			if c == "L" then follow = true
			elseif c == "t" then terse = true
			elseif c == "f" then filesystem = true
			else usage() end
		end
	else
		files[#files + 1] = a
	end
	i = i + 1
end

if #files == 0 then usage() end

local function kind(mode)
	if sys_stat.S_ISDIR(mode) ~= 0 then return "directory" end
	if sys_stat.S_ISLNK(mode) ~= 0 then return "symbolic link" end
	if sys_stat.S_ISBLK(mode) ~= 0 then return "block special file" end
	if sys_stat.S_ISCHR(mode) ~= 0 then return "character special file" end
	if sys_stat.S_ISFIFO(mode) ~= 0 then return "fifo" end
	if sys_stat.S_ISSOCK(mode) ~= 0 then return "socket" end
	return "regular file"
end

local function rwx(mode)
	local letters = { "r", "w", "x" }
	local out = {}
	for shift = 8, 0, -1 do
		local bit = 1 << shift
		out[#out + 1] = (mode & bit) ~= 0 and letters[3 - (shift % 3)] or "-"
	end
	return table.concat(out)
end

local function type_letter(mode)
	if sys_stat.S_ISDIR(mode) ~= 0 then return "d" end
	if sys_stat.S_ISLNK(mode) ~= 0 then return "l" end
	if sys_stat.S_ISBLK(mode) ~= 0 then return "b" end
	if sys_stat.S_ISCHR(mode) ~= 0 then return "c" end
	if sys_stat.S_ISFIFO(mode) ~= 0 then return "p" end
	if sys_stat.S_ISSOCK(mode) ~= 0 then return "s" end
	return "-"
end

-- The letters GNU stat takes after a %, for the ones that mean something
-- without a whole filesystem behind them.
local function expand(fmt, path, st)
	local user = pwd.getpwuid(st.st_uid)
	local group = grp.getgrgid(st.st_gid)
	local fields = {
		n = path,
		N = path,
		s = tostring(st.st_size),
		b = tostring(st.st_blocks or 0),
		B = "512",
		f = string.format("%x", st.st_mode),
		a = string.format("%o", st.st_mode & tonumber("7777", 8)),
		A = type_letter(st.st_mode) .. rwx(st.st_mode),
		u = tostring(st.st_uid),
		U = user and user.pw_name or tostring(st.st_uid),
		g = tostring(st.st_gid),
		G = group and group.gr_name or tostring(st.st_gid),
		h = tostring(st.st_nlink),
		i = tostring(st.st_ino),
		d = tostring(st.st_dev),
		D = string.format("%x", st.st_dev),
		t = string.format("%x", (st.st_rdev or 0) >> 8),
		T = string.format("%x", (st.st_rdev or 0) & 0xff),
		F = kind(st.st_mode),
		X = tostring(st.st_atime),
		Y = tostring(st.st_mtime),
		Z = tostring(st.st_ctime),
		x = os.date("%Y-%m-%d %H:%M:%S", st.st_atime),
		y = os.date("%Y-%m-%d %H:%M:%S", st.st_mtime),
		z = os.date("%Y-%m-%d %H:%M:%S", st.st_ctime),
	}
	local out = fmt:gsub("\\n", "\n"):gsub("\\t", "\t")
	out = out:gsub("%%(.)", function(c)
		if c == "%" then return "%" end
		return fields[c] or ("%" .. c)
	end)
	return out
end

local status = 0
for _, path in ipairs(files) do
	if filesystem then
		local fs = statvfs.statvfs(path)
		if not fs then
			util.warn(path .. ": cannot read the filesystem")
			status = 1
		else
			unistd.write(1, string.format("  File: \"%s\"\n", path))
			unistd.write(1, string.format("    ID: %s Namelen: %d Type: unknown\n",
				tostring(fs.f_fsid or 0), fs.f_namemax or 255))
			unistd.write(1, string.format("Block size: %d\n", fs.f_bsize))
			unistd.write(1, string.format("Blocks: Total: %d Free: %d Available: %d\n",
				fs.f_blocks, fs.f_bfree, fs.f_bavail))
			unistd.write(1, string.format("Inodes: Total: %d Free: %d\n",
				fs.f_files, fs.f_ffree))
		end
	else
		local st = follow and sys_stat.stat(path) or sys_stat.lstat(path)
		if not st then
			util.warn(path .. ": No such file or directory")
			status = 1
		elseif format then
			unistd.write(1, expand(format, path, st) .. "\n")
		elseif terse then
			unistd.write(1, expand("%n %s %b %f %u %g %D %i %h %t %T %X %Y %Z %B", path, st) .. "\n")
		else
			local user = pwd.getpwuid(st.st_uid)
			local group = grp.getgrgid(st.st_gid)
			unistd.write(1, string.format("  File: %s\n", path))
			unistd.write(1, string.format("  Size: %-10d Blocks: %-8d IO Block: %-6d %s\n",
				st.st_size, st.st_blocks or 0, st.st_blksize or 4096, kind(st.st_mode)))
			unistd.write(1, string.format("Device: %xh/%dd Inode: %-10d Links: %d\n",
				st.st_dev, st.st_dev, st.st_ino, st.st_nlink))
			unistd.write(1, string.format("Access: (%04o/%s)  Uid: (%5d/%8s)   Gid: (%5d/%8s)\n",
				st.st_mode & tonumber("7777", 8), type_letter(st.st_mode) .. rwx(st.st_mode),
				st.st_uid, user and user.pw_name or "?",
				st.st_gid, group and group.gr_name or "?"))
			unistd.write(1, string.format("Access: %s\n", os.date("%Y-%m-%d %H:%M:%S", st.st_atime)))
			unistd.write(1, string.format("Modify: %s\n", os.date("%Y-%m-%d %H:%M:%S", st.st_mtime)))
			unistd.write(1, string.format("Change: %s\n", os.date("%Y-%m-%d %H:%M:%S", st.st_ctime)))
		end
	end
end
os.exit(status)
