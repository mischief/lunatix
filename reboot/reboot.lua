#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- reboot, halt and poweroff. Which one it is comes from argv[0].
local prefix = ((arg[0] or "reboot"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local signal = require("posix.signal")
local unistd = require("posix.unistd")
local sys = require("luaposixcli.sys")
local util = require("luaposixcli.util")

local how = {
	reboot = sys.RB_AUTOBOOT,
	halt = sys.RB_HALT,
	poweroff = sys.RB_POWEROFF,
}

-- What init is told to do, the signals busybox's init reads.
local ask = {
	reboot = signal.SIGTERM,
	halt = signal.SIGUSR1,
	poweroff = signal.SIGUSR2,
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

unistd.sync()

-- Without -f, init owns the machine's last steps: it stops the
-- services, unmounts what it mounted and calls reboot(2) itself. -f is
-- the call with none of that, which is what to use when there is no
-- init to ask or it is not answering.
if not force and unistd.getpid() ~= 1 then
	local ok, err = signal.kill(1, ask[util.prog])
	if ok then os.exit(0) end
	util.die("cannot signal init: " .. tostring(err))
end

local ok, err = sys.reboot(cmd)
if not ok then
	util.die(tostring(err))
end
