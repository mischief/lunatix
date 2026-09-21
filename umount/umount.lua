#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- umount - detach a filesystem
local prefix = ((arg[0] or "umount"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local targets = {}
for _, a in ipairs(arg) do
	if a == "--" then
	elseif a:sub(1, 1) == "-" and #a > 1 then
		util.die("usage: umount target...")
	else
		targets[#targets + 1] = a
	end
end

if #targets == 0 then
	util.die("usage: umount target...")
end

local status = 0
for _, target in ipairs(targets) do
	local ok, err = sys.umount(target)
	if not ok then
		util.warn(target .. ": " .. tostring(err))
		status = 1
	end
end
os.exit(status)
