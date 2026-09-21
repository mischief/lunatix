#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- rev - each line backwards
local prefix = ((arg[0] or "rev"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local files = {}
for _, a in ipairs(arg) do
	if a == "--" then
	elseif a:sub(1, 1) == "-" and #a > 1 then util.die("usage: rev [file...]", 2)
	else files[#files + 1] = a end
end

local status = 0
local function pour(text)
	for line in util.lines(text) do
		unistd.write(1, line:reverse() .. "\n")
	end
end

if #files == 0 then
	pour(util.slurp_fd(0) or "")
else
	for _, path in ipairs(files) do
		local data, err = util.slurp(path)
		if not data then
			util.warn(err or (path .. ": cannot read"))
			status = 1
		else
			pour(data)
		end
	end
end
os.exit(status)
