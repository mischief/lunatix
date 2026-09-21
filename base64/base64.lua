#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- base64 - bytes as text, and back
local prefix = ((arg[0] or "base64"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local util = require("luaposixcli.util")

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local decode, wrap, ignore_garbage = false, 76, false
local files = {}

local function usage()
	util.die("usage: base64 [-d] [-i] [-w cols] [file]", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "diw:") do
	if opt == "d" then decode = true
	elseif opt == "i" then ignore_garbage = true
	elseif opt == "w" then wrap = tonumber(optarg) or usage()
	else usage() end
	optind = oi
end
files = util.operands(arg, optind)

if #files > 1 then usage() end

local data, err = util.slurp(files[1])
if not data then util.die(err or (files[1] .. ": cannot read")) end

if not decode then
	local out = {}
	for at = 1, #data, 3 do
		local a, b, c = data:byte(at, at + 2)
		local n = a << 16 | (b or 0) << 8 | (c or 0)
		local chunk = ALPHABET:sub((n >> 18 & 63) + 1, (n >> 18 & 63) + 1)
			.. ALPHABET:sub((n >> 12 & 63) + 1, (n >> 12 & 63) + 1)
			.. (b and ALPHABET:sub((n >> 6 & 63) + 1, (n >> 6 & 63) + 1) or "=")
			.. (c and ALPHABET:sub((n & 63) + 1, (n & 63) + 1) or "=")
		out[#out + 1] = chunk
	end
	local text = table.concat(out)
	if wrap > 0 then
		local lines = {}
		for at = 1, #text, wrap do lines[#lines + 1] = text:sub(at, at + wrap - 1) end
		text = table.concat(lines, "\n")
	end
	if #text > 0 then unistd.write(1, text .. "\n") end
	os.exit(0)
end

-- decoding: the newlines an encoder put in are not garbage, anything
-- else is unless -i says to skip it
local values = {}
for n = 1, #ALPHABET do values[ALPHABET:sub(n, n)] = n - 1 end

local bits, held, out = 0, 0, {}
for at = 1, #data do
	local c = data:sub(at, at)
	local value = values[c]
	if value then
		held = (held << 6) | value
		bits = bits + 6
		if bits >= 8 then
			bits = bits - 8
			out[#out + 1] = string.char((held >> bits) & 0xff)
		end
	elseif c == "=" or c:match("%s") then
		-- padding and line breaks are part of the encoding
	elseif not ignore_garbage then
		util.die("invalid input")
	end
end
unistd.write(1, table.concat(out))
