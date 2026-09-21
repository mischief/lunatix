#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- cpio, newc format: the one an initramfs is made of.
--
--   cpio -o -H newc < list > archive
--   cpio -i [-d] < archive
--   cpio -t < archive
local prefix = ((arg[0] or "cpio"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local stat = require("posix.sys.stat")
local util = require("luaposixcli.util")

local MAGIC = "070701"
local TRAILER = "TRAILER!!!"

local mode, verbose, make_dirs, keep_times = nil, false, false, false
local format = "newc"

local function usage()
	util.die("usage: cpio -o|-i|-t [-dvm] [-H newc]", 2)
end

local i = 1
while i <= #arg do
	local a = arg[i]
	if a:sub(1, 2) == "-H" then
		local value = a:sub(3)
		if value == "" then
			i = i + 1
			value = arg[i] or usage()
		end
		format = value
	elseif a:sub(1, 1) == "-" and #a > 1 then
		for c in a:sub(2):gmatch(".") do
			if c == "o" then mode = "create"
			elseif c == "i" then mode = "extract"
			elseif c == "t" then mode = "list"
			elseif c == "d" then make_dirs = true
			elseif c == "v" then verbose = true
			elseif c == "m" then keep_times = true
			else usage() end
		end
	else
		usage()
	end
	i = i + 1
end

if not mode then usage() end
if format ~= "newc" and format ~= "sv4cpio" then
	util.die(format .. ": only the newc format is here")
end

-- Every number in a newc header is eight hex digits, and the header and
-- the name together are padded to four bytes, as is the data after them.
local function pad(n)
	return (4 - n % 4) % 4
end

local function header(fields, name)
	local out = { MAGIC }
	for _, value in ipairs(fields) do
		out[#out + 1] = string.format("%08X", value)
	end
	local text = table.concat(out) .. name .. "\0"
	return text .. string.rep("\0", pad(#text))
end

if mode == "create" then
	-- the names come in on standard input, one to a line, which is what
	-- find | cpio -o means
	local list = util.slurp_fd(0) or ""
	local written = 0
	for name in util.lines(list) do
		-- find writes ./x; the archive holds x, the way cpio stores it,
		-- except for "." itself which stays as the directory it names
		local stored = name == "." and "." or name:gsub("^%./", "")
		if name ~= "" and stored ~= "" then
			local st = stat.lstat(name)
			if not st then
				util.warn(name .. ": No such file or directory")
			else
				local data = ""
				if stat.S_ISREG(st.st_mode) ~= 0 then
					data = util.slurp(name) or ""
				elseif stat.S_ISLNK(st.st_mode) ~= 0 then
					data = unistd.readlink(name) or ""
				end
				unistd.write(1, header({
					st.st_ino, st.st_mode, st.st_uid, st.st_gid,
					st.st_nlink, st.st_mtime, #data,
					0, 0, 0, 0, #stored + 1, 0,
				}, stored))
				if #data > 0 then
					unistd.write(1, data .. string.rep("\0", pad(#data)))
				end
				written = written + #data
				if verbose then unistd.write(2, name .. "\n") end
			end
		end
	end
	unistd.write(1, header({ 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, #TRAILER + 1, 0 }, TRAILER))
	unistd.write(2, string.format("%d blocks\n", (written + 511) // 512))
	os.exit(0)
end

local archive = util.slurp_fd(0) or ""
if #archive < 110 or archive:sub(1, 6) ~= MAGIC then
	util.die("not a newc archive")
end

local pos = 1
local status = 0

while pos + 110 <= #archive + 1 do
	local head = archive:sub(pos, pos + 109)
	if head:sub(1, 6) ~= MAGIC then
		util.die("not a newc archive, or lost the place in it")
	end
	local function field(n)
		return tonumber(head:sub(6 + (n - 1) * 8 + 1, 6 + n * 8), 16) or 0
	end
	local file_mode, uid, gid = field(2), field(3), field(4)
	local mtime, size, namesize = field(6), field(7), field(12)
	local name = archive:sub(pos + 110, pos + 110 + namesize - 2)
	pos = pos + 110 + namesize
	pos = pos + pad(110 + namesize)
	local data = archive:sub(pos, pos + size - 1)
	pos = pos + size + pad(size)

	if name == TRAILER then break end

	if mode == "list" then
		unistd.write(1, name .. "\n")
	else
		if verbose then unistd.write(2, name .. "\n") end
		local parent = name:match("^(.*)/[^/]*$")
		if parent and parent ~= "" and make_dirs and not stat.stat(parent) then
			local made = ""
			for part in parent:gmatch("[^/]+") do
				made = made == "" and part or (made .. "/" .. part)
				if not stat.stat(made) then stat.mkdir(made, tonumber("755", 8)) end
			end
		end
		if stat.S_ISDIR(file_mode) ~= 0 then
			if not stat.stat(name) then
				stat.mkdir(name, file_mode & tonumber("7777", 8))
			end
		elseif stat.S_ISLNK(file_mode) ~= 0 then
			unistd.unlink(name)
			local ok = unistd.link(data, name, true)
			if ok ~= 0 then
				util.warn(name .. ": cannot make the link")
				status = 1
			end
		else
			local fd = fcntl.open(name, fcntl.O_WRONLY | fcntl.O_CREAT | fcntl.O_TRUNC,
				file_mode & tonumber("7777", 8))
			if not fd then
				util.warn(name .. ": cannot create")
				status = 1
			else
				if #data > 0 then unistd.write(fd, data) end
				unistd.close(fd)
				stat.chmod(name, file_mode & tonumber("7777", 8))
				if keep_times then
					require("posix.utime").utime(name, mtime, mtime)
				end
			end
		end
		if unistd.geteuid() == 0 then unistd.chown(name, uid, gid) end
	end
end

os.exit(status)
