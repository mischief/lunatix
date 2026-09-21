#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- reboot, halt and poweroff. Which one it is comes from argv[0].
local prefix = ((arg[0] or "reboot"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local how = {
	reboot = sys.RB_AUTOBOOT,
	halt = sys.RB_HALT,
	poweroff = sys.RB_POWEROFF,
}

local cmd = how[util.prog]
if not cmd then
	util.die("call me as reboot, halt or poweroff")
end

local force = false
for _, a in ipairs(arg) do
	if a == "-f" then force = true
	else util.die("usage: " .. util.prog .. " [-f]") end
end

-- Without -f this is the last thing before the kernel goes, so give the
-- disks their chance; the call itself syncs as well.
if not force then unistd.sync() end

local ok, err = sys.reboot(cmd)
if not ok then
	util.die(tostring(err))
end
