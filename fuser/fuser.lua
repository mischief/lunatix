#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- fuser - which processes hold a file open. What umount blames.
local prefix = ((arg[0] or "fuser"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local dirent = require("posix.dirent")
local stat = require("posix.sys.stat")
local pwd = require("posix.pwd")
local signal = require("posix.signal")
local util = require("luaposixcli.util")

local signals = {
	HUP = signal.SIGHUP, INT = signal.SIGINT, QUIT = signal.SIGQUIT,
	KILL = signal.SIGKILL, TERM = signal.SIGTERM, USR1 = signal.SIGUSR1,
	USR2 = signal.SIGUSR2, STOP = signal.SIGSTOP, CONT = signal.SIGCONT,
}

local kill_them, silent, on_mount, show_user = false, false, false, false
local sig = signal.SIGKILL

local function usage()
	util.die("usage: fuser [-kmsu] [-SIGNAL] file...", 2)
end

-- -SIGKILL and -9 name a signal, which getopt has no way to describe.
-- They come off the front before getopt sees the rest.
local kept = {}
for i = 1, #arg do
	local a = arg[i]
	local name = a:match("^%-(%a+)$")
	local number = a:match("^%-(%d+)$")
	if name and signals[name:upper():gsub("^SIG", "")] then
		sig = signals[name:upper():gsub("^SIG", "")]
	elseif number then
		sig = tonumber(number)
	else
		kept[#kept + 1] = a
	end
end
kept[0] = arg[0]

local optind = 1
for opt, _, oi in unistd.getopt(kept, "kmsuv") do
	if opt == "k" then kill_them = true
	elseif opt == "m" then on_mount = true
	elseif opt == "s" then silent = true
	elseif opt == "u" then show_user = true
	elseif opt == "v" then -- verbose, which this is not
	else usage() end
	optind = oi
end
local files = util.operands(kept, optind)
if #files == 0 then usage() end

-- The file a name stands for, as the kernel sees it: the device and the
-- inode, since a name can reach the same file more than one way.
local function identity(path)
	local st = stat.stat(path)
	if not st then return nil end
	return st.st_dev, st.st_ino, stat.S_ISDIR(st.st_mode) ~= 0
end

-- dirent.dir raises where it cannot read, and half of /proc belongs to
-- somebody else
local function dir(path)
	local ok, names = pcall(dirent.dir, path)
	if ok and names then return names end
	return {}
end

local function pids()
	local out = {}
	for _, name in ipairs(dir("/proc")) do
		local pid = tonumber(name)
		if pid then out[#out + 1] = pid end
	end
	table.sort(out)
	return out
end

-- What a process has open: its descriptors, and the three the kernel
-- keeps beside them. A process we may not look at gives nothing, which
-- is not an error: fuser run by anyone but root sees only its own.
local function holdings(pid)
	local paths = {}
	local base = "/proc/" .. pid
	for _, name in ipairs({ "cwd", "root", "exe" }) do
		local ok, to = pcall(unistd.readlink, base .. "/" .. name)
		if not ok then to = nil end
		if to then paths[#paths + 1] = to end
	end
	for _, fd in ipairs(dir(base .. "/fd")) do
		if fd ~= "." and fd ~= ".." then
			local ok, to = pcall(unistd.readlink, base .. "/fd/" .. fd)
			if not ok then to = nil end
			if to then paths[#paths + 1] = to end
		end
	end
	return paths
end

local function user_of(pid)
	local st = stat.stat("/proc/" .. pid)
	if not st then return "?" end
	local pw = pwd.getpwuid(st.st_uid)
	return pw and pw.pw_name or tostring(st.st_uid)
end

local status = 1
local all = pids()

for _, file in ipairs(files) do
	local dev, ino = identity(file)
	if not dev then
		if not silent then util.warn(file .. ": No such file or directory") end
	else
		local found = {}
		for _, pid in ipairs(all) do
			local hit = false
			for _, path in ipairs(holdings(pid)) do
				local pdev, pino = identity(path)
				-- -m asks who is on the filesystem, not who holds the one
				-- file, which is what umount needs to know
				if pdev == dev and (on_mount or pino == ino) then hit = true end
				if hit then break end
			end
			if hit then found[#found + 1] = pid end
		end

		if #found > 0 then
			status = 0
			if not silent then
				local out = {}
				for _, pid in ipairs(found) do
					out[#out + 1] = show_user
						and (pid .. "(" .. user_of(pid) .. ")") or tostring(pid)
				end
				unistd.write(2, file .. ":")
				unistd.write(1, " " .. table.concat(out, " ") .. "\n")
			end
			if kill_them then
				for _, pid in ipairs(found) do
					if pid ~= unistd.getpid() then signal.kill(pid, sig) end
				end
			end
		end
	end
end

os.exit(status)
