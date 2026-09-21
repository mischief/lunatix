#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- hexdump and xxd: bytes as hex, and with xxd -r back again.
local prefix = ((arg[0] or "hexdump"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local prog = util.prog
local canonical = (prog == "xxd")
local reverse, plain = false, false
local columns = 16
local length, skip = nil, 0
local files = {}

local function usage()
	if prog == "xxd" then
		util.die("usage: xxd [-r] [-p] [-c cols] [-l len] [-s skip] [file]", 2)
	end
	util.die("usage: hexdump [-C] [-n len] [-s skip] [file...]", 2)
end

local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "--" then
		for j = i + 1, #arg do files[#files + 1] = arg[j] end
		break
	elseif a:sub(1, 2) == "-c" or a:sub(1, 2) == "-l" or a:sub(1, 2) == "-s"
		or a:sub(1, 2) == "-n" then
		local which = a:sub(2, 2)
		local value = a:sub(3)
		if value == "" then
			i = i + 1
			value = arg[i] or usage()
		end
		local n = tonumber(value) or tonumber(value, 16) or usage()
		if which == "c" then columns = n
		elseif which == "s" then skip = n
		else length = n end
	elseif a:sub(1, 1) == "-" and #a > 1 then
		for c in a:sub(2):gmatch(".") do
			if c == "r" then reverse = true
			elseif c == "p" then plain = true
			elseif c == "C" then canonical = true
			else usage() end
		end
	else
		files[#files + 1] = a
	end
	i = i + 1
end

local data, err = util.slurp(files[1])
if not data then util.die(err or (tostring(files[1]) .. ": cannot read")) end

-- xxd -r reads back what xxd wrote, which is how a file gets edited as text
if reverse then
	local out = {}
	for line in util.lines(data) do
		local body = plain and line or (line:match("^%x+:%s*(.*)$") or line)
		if not plain then body = body:gsub("  .*$", "") end
		for byte in body:gmatch("%x%x") do
			out[#out + 1] = string.char(tonumber(byte, 16))
		end
	end
	unistd.write(1, table.concat(out))
	os.exit(0)
end

if skip > 0 then data = data:sub(skip + 1) end
if length then data = data:sub(1, length) end

if plain then
	local out = {}
	for at = 1, #data do
		out[#out + 1] = string.format("%02x", data:byte(at))
		if at % (columns == 16 and 30 or columns) == 0 then out[#out + 1] = "\n" end
	end
	unistd.write(1, table.concat(out) .. "\n")
	os.exit(0)
end

local function printable(c)
	local b = c:byte()
	return (b >= 32 and b < 127) and c or "."
end

-- xxd writes the bytes in pairs with a space after each pair; hexdump
-- writes them one at a time with an extra gap in the middle of the line.
local function hex_of(chunk)
	local out = {}
	for n = 1, #chunk do
		out[#out + 1] = string.format("%02x", chunk:byte(n))
		if prog == "xxd" then
			if n % 2 == 0 then out[#out + 1] = " " end
		else
			out[#out + 1] = " "
			if n == 8 then out[#out + 1] = " " end
		end
	end
	return table.concat(out)
end

for at = 1, #data, columns do
	local chunk = data:sub(at, at + columns - 1)
	local text = {}
	for n = 1, #chunk do text[#text + 1] = printable(chunk:sub(n, n)) end
	local hex_text = hex_of(chunk)
	if prog == "xxd" then
		local width = columns * 2 + columns // 2
		unistd.write(1, string.format("%08x: %-" .. width .. "s %s\n",
			skip + at - 1, hex_text, table.concat(text)))
	else
		local width = columns * 3 + 1
		unistd.write(1, string.format("%08x  %-" .. width .. "s |%s|\n",
			skip + at - 1, hex_text, table.concat(text)))
	end
end

-- hexdump ends with the offset it stopped at; xxd does not
if prog ~= "xxd" then
	unistd.write(1, string.format("%08x\n", skip + #data))
end
