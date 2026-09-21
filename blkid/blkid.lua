#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- blkid - what is on a block device: the type, the uuid and the label
local prefix = ((arg[0] or "blkid"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local probe = require("lunatix.probe")
local util = require("luaposixcli.util")

local format = "full"
local tag = nil
local by_uuid, by_label = nil, nil

local function usage()
	util.die("usage: blkid [-o full|value|device|export] [-s tag]\n" ..
		"              [-U uuid] [-L label] [device...]", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "o:s:U:L:p") do
	if opt == "o" then format = optarg
	elseif opt == "s" then tag = optarg:upper()
	elseif opt == "U" then by_uuid = optarg
	elseif opt == "L" then by_label = optarg
	elseif opt == "p" then -- probe the device rather than a cache we do not keep
	else usage() end
	optind = oi
end
local devices = util.operands(arg, optind)

-- -U and -L answer with the device carrying that tag, and say nothing
-- at all when nothing does
if by_uuid or by_label then
	local found = by_uuid and probe.find("uuid", by_uuid)
		or probe.find("label", by_label)
	if not found then os.exit(2) end
	unistd.write(1, found .. "\n")
	os.exit(0)
end

if #devices == 0 then devices = probe.devices() end

local function tags_of(info)
	local out = {}
	if info.label then out[#out + 1] = { "LABEL", info.label } end
	if info.uuid then out[#out + 1] = { "UUID", info.uuid } end
	if info.version then out[#out + 1] = { "VERSION", info.version } end
	out[#out + 1] = { "TYPE", info.type }
	return out
end

local found_any = false
for _, path in ipairs(devices) do
	local info = probe.probe(path)
	if info then
		found_any = true
		local parts = {}
		for _, pair in ipairs(tags_of(info)) do
			if not tag or tag == pair[1] then
				if format == "value" then
					parts[#parts + 1] = pair[2]
				elseif format == "export" then
					parts[#parts + 1] = pair[1] .. "=" .. pair[2]
				else
					parts[#parts + 1] = pair[1] .. "=\"" .. pair[2] .. "\""
				end
			end
		end
		if format == "device" then
			unistd.write(1, path .. "\n")
		elseif format == "export" then
			unistd.write(1, "DEVNAME=" .. path .. "\n"
				.. table.concat(parts, "\n") .. "\n\n")
		elseif format == "value" then
			if #parts > 0 then unistd.write(1, table.concat(parts, "\n") .. "\n") end
		elseif #parts > 0 then
			unistd.write(1, path .. ": " .. table.concat(parts, " ") .. "\n")
		end
	end
end

os.exit(found_any and 0 or 2)
