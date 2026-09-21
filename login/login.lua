#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- login - ask who this is, check the password, and become them
local prefix = ((arg[0] or "login"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local auth = require("lunatix.auth")
local util = require("luaposixcli.util")

local keep_env = false
local user = nil

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "-p" then keep_env = true
	elseif a == "-f" then i = i + 1; user = arg[i]
	elseif a:sub(1, 1) ~= "-" then user = a
	else util.die("usage: login [-p] [user]") end
	i = i + 1
end

local function banner(path)
	local text = util.slurp(path)
	if text then unistd.write(1, text) end
end

local tries = 0
while tries < 3 do
	tries = tries + 1
	local name = user
	user = nil
	if not name then
		banner("/etc/issue")
		unistd.write(2, "login: ")
		name = io.read("l")
		if not name then os.exit(1) end
	end

	local entry = auth.account(name)
	-- The password is asked for even when the account does not exist, so
	-- a wrong name and a wrong password look the same from outside.
	local password = auth.askpass("Password: ")
	if password == nil then os.exit(1) end

	if entry and auth.verify(entry, password) then
		local ok, err = auth.become(entry)
		if not ok then util.die(tostring(err)) end
		auth.environment(entry, keep_env)
		unistd.chdir(entry.pw_dir)
		banner("/etc/motd")
		local shell = auth.shell(entry)
		-- a login shell is told so by the dash on its name
		unistd.exec(shell, { [0] = "-" .. util.basename(shell) })
		util.die(shell .. ": cannot execute")
	end

	unistd.write(2, "Login incorrect\n")
	unistd.sleep(2)
end

os.exit(1)
