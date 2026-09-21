#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- mountpoint - whether a directory is one
local prefix = ((arg[0] or "mountpoint"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local stat = require("posix.sys.stat")
local util = require("luaposixcli.util")

local quiet, want_device = false, false
local path = nil

local optind = 1
for opt, _, oi in unistd.getopt(arg, "qd") do
	if opt == "q" then quiet = true
	elseif opt == "d" then want_device = true
	else util.die("usage: mountpoint [-dq] directory", 2) end
	optind = oi
end
path = util.operands(arg, optind)[1]

if not path then util.die("usage: mountpoint [-dq] directory", 2) end

-- util-linux answers 0 for yes, 32 for no and 1 for not being able to
-- look, and scripts written against it read those
local st = stat.stat(path)
if not st then
	if not quiet then util.warn(path .. ": No such file or directory") end
	os.exit(1)
end

if want_device then
	unistd.write(1, string.format("%d:%d\n", st.st_dev >> 8, st.st_dev & 0xff))
	os.exit(0)
end

if stat.S_ISDIR(st.st_mode) == 0 then
	if not quiet then util.warn(path .. ": not a directory") end
	os.exit(1)
end

-- A directory is a mount point when it and its parent sit on different
-- devices, or when it is its own parent, which is what / looks like.
local parent = stat.stat(path .. "/..")
local is_mount = parent and (st.st_dev ~= parent.st_dev or st.st_ino == parent.st_ino)

if not quiet then
	unistd.write(1, path .. (is_mount and " is a mountpoint\n" or " is not a mountpoint\n"))
end
os.exit(is_mount and 0 or 32)
