-- SPDX-License-Identifier: ISC
-- lunatix/auth.lua - what login, su and getty all need: an account, the
-- password that goes with it, and becoming that user.
local unistd = require("posix.unistd")
local pwd = require("posix.pwd")
local termio = require("posix.termio")

local M = {}

-- The hash lives in /etc/shadow where there is one, and in the passwd
-- entry where there is not. luaposix has no shadow binding, so the file
-- is read here; it is three fields deep and only the second matters.
local function shadow_hash(name)
	local f = io.open("/etc/shadow", "r")
	if not f then return nil end
	for line in f:lines() do
		local user, hash = line:match("^([^:]*):([^:]*)")
		if user == name then
			f:close()
			return hash
		end
	end
	f:close()
	return nil
end

-- An account, or nil and why not
function M.account(name)
	local entry = pwd.getpwnam(name)
	if not entry then return nil, "no such user" end
	local hash = entry.pw_passwd
	if hash == "x" or hash == "" or hash == nil then
		hash = shadow_hash(name) or hash
	end
	entry.hash = hash
	return entry
end

-- Whether a password matches. An empty hash means no password at all; a
-- hash of "*" or "!" is an account that cannot be logged into.
function M.verify(entry, password)
	local hash = entry.hash
	if hash == nil or hash == "" then return true end
	if hash == "*" or hash:sub(1, 1) == "!" then return false end
	-- "x" and anything else too short to be a hash means the real one is
	-- somewhere this process cannot read, so nothing can match it
	local salt = hash:match("^(%$[^$]+%$[^$]*%$)")
	if not salt then
		if #hash < 13 then return false end
		salt = hash:sub(1, 2)
	end
	local ok, result = pcall(unistd.crypt, password, salt)
	return ok and result == hash
end

-- Read a line with the terminal not showing it
function M.askpass(prompt)
	unistd.write(2, prompt)
	local attrs = termio.tcgetattr(0)
	local restore = nil
	if attrs then
		restore = attrs.lflag
		attrs.lflag = attrs.lflag & ~termio.ECHO
		termio.tcsetattr(0, termio.TCSANOW, attrs)
	end
	local answer = io.read("l")
	if attrs then
		attrs.lflag = restore
		termio.tcsetattr(0, termio.TCSANOW, attrs)
	end
	unistd.write(2, "\n")
	return answer
end

-- Become the account: group first, because after setuid there is no
-- privilege left to change it with.
function M.become(entry)
	local ok, err = unistd.setpid("g", entry.pw_gid)
	if not ok or ok == -1 then return nil, err or "cannot set the group" end
	ok, err = unistd.setpid("u", entry.pw_uid)
	if not ok or ok == -1 then return nil, err or "cannot set the user" end
	return true
end

-- The environment a session starts with
function M.environment(entry, keep)
	local stdlib = require("posix.stdlib")
	if not keep then
		stdlib.setenv("HOME", entry.pw_dir)
		stdlib.setenv("SHELL", entry.pw_shell ~= "" and entry.pw_shell or "/bin/sh")
		stdlib.setenv("USER", entry.pw_name)
		stdlib.setenv("LOGNAME", entry.pw_name)
		stdlib.setenv("PATH", entry.pw_uid == 0
			and "/usr/sbin:/usr/bin:/sbin:/bin" or "/usr/bin:/bin")
	end
end

function M.shell(entry)
	local shell = entry.pw_shell
	if shell == nil or shell == "" then shell = "/bin/sh" end
	return shell
end

return M
