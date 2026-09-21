#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- su - run a shell, or one command, as another user
local prefix = ((arg[0] or "su"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path
if not package.cpath:find("build") then
	package.cpath = prefix .. "build/?.so;" .. prefix .. "lib/lua/5.4/?.so;" .. package.cpath
end

local unistd = require("posix.unistd")
local auth = require("lunatix.auth")
local util = require("luaposixcli.util")

local login_shell = false
local command = nil
local user = "root"

local i = 1
local seen_user = false
while i <= #arg do
	local a = arg[i]
	if a == "-" or a == "-l" or a == "--login" then login_shell = true
	elseif a == "-c" then i = i + 1; command = arg[i]
	elseif a:sub(1, 1) ~= "-" and not seen_user then
		user = a
		seen_user = true
	else
		util.die("usage: su [-] [-c command] [user]")
	end
	i = i + 1
end

local entry, err = auth.account(user)
if not entry then util.die(user .. ": " .. err) end

-- root is already who it needs to be; anyone else proves it
if unistd.getuid() ~= 0 then
	local password = auth.askpass("Password: ")
	if password == nil or not auth.verify(entry, password) then
		unistd.write(2, "su: Authentication failure\n")
		os.exit(1)
	end
end

local ok, berr = auth.become(entry)
if not ok then util.die(tostring(berr)) end

auth.environment(entry, not login_shell)
if login_shell then unistd.chdir(entry.pw_dir) end

local shell = auth.shell(entry)
if command then
	unistd.exec(shell, { "-c", command })
else
	local name = util.basename(shell)
	unistd.exec(shell, { [0] = login_shell and ("-" .. name) or name })
end
util.die(shell .. ": cannot execute")
