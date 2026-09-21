#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- sha1sum, sha256sum and sha512sum. Which one it is comes from argv[0].
local prefix = ((arg[0] or "sha256sum"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local algorithms = {
	sha1sum = "sha1",
	sha256sum = "sha256",
	sha512sum = "sha512",
}

local name = algorithms[util.prog]
if not name then
	util.die("call me as sha1sum, sha256sum or sha512sum")
end
local hash = require("lunatix.crypto." .. name)

local check, files = false, {}
for _, a in ipairs(arg) do
	if a == "-c" then check = true
	elseif a == "-" or a:sub(1, 1) ~= "-" then files[#files + 1] = a
	else util.die("usage: " .. util.prog .. " [-c] [file...]") end
end

local function digest(data)
	return (hash.hash(data):gsub(".", function(c)
		return string.format("%02x", c:byte())
	end))
end

local status = 0

-- -c reads the output of an earlier run and says whether each file still
-- hashes to what it did.
if check then
	if #files == 0 then files = { "-" } end
	for _, list in ipairs(files) do
		local data, err = util.slurp(list)
		if not data then
			util.warn(err or (list .. ": cannot read"))
			status = 1
		else
			for line in util.lines(data) do
				local want, path = line:match("^(%x+)%s+%*?(.+)$")
				if want and path then
					local content, cerr = util.slurp(path)
					if not content then
						util.warn(cerr or (path .. ": cannot read"))
						status = 1
					elseif digest(content) == want then
						unistd.write(1, path .. ": OK\n")
					else
						unistd.write(1, path .. ": FAILED\n")
						status = 1
					end
				end
			end
		end
	end
	os.exit(status)
end

if #files == 0 then files = { "-" } end
for _, path in ipairs(files) do
	local data, err = util.slurp(path)
	if not data then
		util.warn(err or (path .. ": cannot read"))
		status = 1
	else
		unistd.write(1, digest(data) .. "  " .. (path == "-" and "-" or path) .. "\n")
	end
end
os.exit(status)
