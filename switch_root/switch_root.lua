#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- switch_root and pivot_root: hand the machine to the real root.
--
-- switch_root is what an initramfs runs: it moves the mounts it needs,
-- makes the new root the root, empties the old one and execs the new
-- init. pivot_root is the syscall on its own, for a caller with its own
-- plan for the old root.
local prefix = ((arg[0] or "switch_root"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local stat = require("posix.sys.stat")
local dirent = require("posix.dirent")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

if util.prog == "pivot_root" then
	local new_root, put_old = arg[1], arg[2]
	if not new_root or not put_old then
		util.die("usage: pivot_root new_root put_old")
	end
	local ok, err = sys.pivot_root(new_root, put_old)
	if not ok then util.die(tostring(err)) end
	os.exit(0)
end

local new_root = arg[1]
local init = arg[2] or "/sbin/init"
if not new_root then
	util.die("usage: switch_root new_root [init [argument...]]")
end

local st = stat.stat(new_root)
if not st or stat.S_ISDIR(st.st_mode) == 0 then
	util.die(new_root .. ": not a directory")
end
if not stat.stat(new_root .. init) then
	util.die(new_root .. init .. ": not there, so nothing would run")
end

-- what the new root needs before it can run anything
for _, point in ipairs({ "/dev", "/proc", "/sys", "/run" }) do
	if stat.stat(point) and stat.stat(new_root .. point) then
		local ok, err = sys.mount(point, new_root .. point, "none", sys.MS_MOVE or 8192)
		if not ok then util.warn("moving " .. point .. ": " .. tostring(err)) end
	end
end

-- Everything left on the old root goes, because the point of this is to
-- free the memory the initramfs is holding. Only this filesystem: a
-- mount below it belongs to whoever made it.
local root_dev = (stat.stat("/") or {}).st_dev

local function empty(path)
	for _, name in ipairs(dirent.dir(path) or {}) do
		if name ~= "." and name ~= ".." then
			local full = (path == "/" and "" or path) .. "/" .. name
			local entry = stat.lstat(full)
			if entry and entry.st_dev == root_dev then
				if stat.S_ISDIR(entry.st_mode) ~= 0 then
					empty(full)
					unistd.rmdir(full)
				else
					unistd.unlink(full)
				end
			end
		end
	end
end

local ok, err = unistd.chdir(new_root)
if not ok then util.die(new_root .. ": " .. tostring(err)) end

-- move the new root over / and follow it, which is what leaves the old
-- one unreferenced
ok, err = sys.mount(".", "/", "none", sys.MS_MOVE or 8192)
if not ok then util.die("cannot move the new root over /: " .. tostring(err)) end
ok, err = sys.chroot(".")
if not ok then util.die("chroot: " .. tostring(err)) end
unistd.chdir("/")

local rest = {}
for i = 3, #arg do rest[#rest + 1] = arg[i] end
unistd.exec(init, rest)
util.die(init .. ": cannot execute")
