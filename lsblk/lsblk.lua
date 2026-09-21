#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- lsblk - the block devices the kernel has, read out of /sys/block
local prefix = ((arg[0] or "lsblk"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local dirent = require("posix.dirent")
local stat = require("posix.sys.stat")
local probe = require("lunatix.probe")
local util = require("luaposixcli.util")

local sysroot = ""

local flat, no_header, ascii, show_all, in_bytes = false, false, false, false, false
local columns = { "NAME", "MAJ:MIN", "RM", "SIZE", "RO", "TYPE", "MOUNTPOINTS" }

local function usage()
	util.die("usage: lsblk [-lnabA] [-o columns] [-R sysroot] [device...]", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "lnabAo:R:") do
	if opt == "l" then flat = true
	elseif opt == "n" then no_header = true
	elseif opt == "a" then show_all = true
	elseif opt == "b" then in_bytes = true
	elseif opt == "A" then ascii = true
	elseif opt == "R" then sysroot = optarg
	elseif opt == "o" then
		columns = {}
		for name in optarg:gmatch("[^,]+") do columns[#columns + 1] = name:upper() end
	else usage() end
	optind = oi
end
local wanted = util.operands(arg, optind)

local function first_line(path)
	local text = util.slurp(path)
	return text and (text:gsub("%s+$", "")) or nil
end

local function dir_of(path)
	local ok, names = pcall(dirent.dir, path)
	if not ok or not names then return {} end
	local out = {}
	for _, name in ipairs(names) do
		if name ~= "." and name ~= ".." then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

-- Where each device is mounted, by the major:minor the kernel gives it
local mountpoints = {}
do
	local text = util.slurp(sysroot .. "/proc/self/mountinfo") or ""
	for line in util.lines(text) do
		local dev, target = line:match("^%d+ %d+ (%S+) %S+ (%S+) ")
		if dev then
			target = target:gsub("\\(%d%d%d)",
				function(n) return string.char(tonumber(n, 8)) end)
			mountpoints[dev] = mountpoints[dev] or {}
			table.insert(mountpoints[dev], target)
		end
	end
	-- a swap area is not mounted anywhere, and lsblk says so in its own way
	local swaps = util.slurp(sysroot .. "/proc/swaps") or ""
	for line in util.lines(swaps) do
		local path = line:match("^(/%S+)")
		if path then
			local st = stat.stat(path)
			if st then
				local dev = string.format("%d:%d",
					require("luaposixcli.sys").major(st.st_rdev),
					require("luaposixcli.sys").minor(st.st_rdev))
				mountpoints[dev] = mountpoints[dev] or {}
				table.insert(mountpoints[dev], "[SWAP]")
			end
		end
	end
end

-- 512 byte sectors, shown the way every disk tool shows them
local function size_of(sectors)
	local bytes = (tonumber(sectors) or 0) * 512
	if in_bytes then return tostring(bytes) end
	if bytes == 0 then return "0B" end
	local units = { "B", "K", "M", "G", "T", "P" }
	local n = 1
	local value = bytes
	while value >= 1024 and n < #units do
		value = value / 1024
		n = n + 1
	end
	local text = string.format("%.1f", value)
	text = text:gsub("%.0$", "")
	return text .. units[n]
end

-- What a device is, which sysfs says by what it puts beside it
local function kind_of(path, name, is_part)
	if is_part then return "part" end
	if stat.stat(path .. "/dm/uuid") then
		local uuid = first_line(path .. "/dm/uuid") or ""
		local head = uuid:match("^(%u+)") or ""
		if head == "LVM" then return "lvm" end
		if head == "CRYPT" then return "crypt" end
		return "dm"
	end
	if name:match("^loop%d") then return "loop" end
	if name:match("^sr%d") then return "rom" end
	return "disk"
end

local devices = {}

local function make(path, name, parent, is_part)
	local dev = first_line(path .. "/dev")
	if not dev then return nil end
	local shown = name
	if stat.stat(path .. "/dm/name") then
		shown = first_line(path .. "/dm/name") or name
	end
	local one = {
		name = shown,
		sysname = name,
		path = path,
		dev = dev,
		size = first_line(path .. "/size") or "0",
		removable = first_line(path .. "/removable") or "0",
		readonly = first_line(path .. "/ro") or "0",
		kind = kind_of(path, name, is_part),
		parent = parent,
		children = {},
	}
	devices[#devices + 1] = one
	return one
end

-- The disks, their partitions, and whatever is stacked on top of those
local by_sysname = {}
for _, name in ipairs(dir_of(sysroot .. "/sys/block")) do
	local path = sysroot .. "/sys/block/" .. name
	local one = make(path, name, nil, false)
	if one then
		by_sysname[name] = one
		for _, entry in ipairs(dir_of(path)) do
			local sub = path .. "/" .. entry
			if stat.stat(sub .. "/partition") then
				local part = make(sub, entry, one, true)
				if part then
					by_sysname[entry] = part
					table.insert(one.children, part)
				end
			end
		end
	end
end

-- A device mapper target sits under what it is made of, which sysfs
-- records as the slaves of the one and the holders of the other
for _, one in ipairs(devices) do
	if one.parent == nil then
		local slaves = dir_of(one.path .. "/slaves")
		local under = by_sysname[slaves[1]]
		if under and under ~= one then
			one.parent = under
			table.insert(under.children, one)
		end
	end
end

local function mounts_of(one)
	local list = mountpoints[one.dev]
	return list and table.concat(list, "\n") or ""
end

local function field(one, name)
	if name == "NAME" then return one.name
	elseif name == "MAJ:MIN" then
		-- lsblk lines the majors up and lets the minors run on
		local major, minor = one.dev:match("^(%d+):(%d+)$")
		return string.format("%3s:%-3s", major or one.dev, minor or "")
	elseif name == "RM" then return one.removable
	elseif name == "RO" then return one.readonly
	elseif name == "SIZE" then return size_of(one.size)
	elseif name == "TYPE" then return one.kind
	elseif name == "MOUNTPOINT" or name == "MOUNTPOINTS" then return mounts_of(one)
	elseif name == "FSTYPE" or name == "UUID" or name == "LABEL" then
		local info = probe.probe("/dev/" .. one.sysname)
		if not info then return "" end
		if name == "FSTYPE" then return info.type end
		return info[name:lower()] or ""
	end
	util.die("unknown column: " .. name, 2)
end

-- An empty loop device is a device with nothing behind it, and lsblk
-- leaves those out unless asked for everything
local function interesting(one)
	if show_all then return true end
	if one.kind == "loop" and (tonumber(one.size) or 0) == 0 then return false end
	return true
end

local selected = {}
if #wanted > 0 then
	for _, path in ipairs(wanted) do
		local name = util.basename(path)
		local one = by_sysname[name]
		if not one then util.die(path .. ": not a block device", 32) end
		selected[#selected + 1] = one
	end
else
	for _, one in ipairs(devices) do
		if one.parent == nil and interesting(one) then
			selected[#selected + 1] = one
		end
	end
	-- sysfs hands them over in name order; the kernel's own order is
	-- the device number, which is what lsblk shows
	table.sort(selected, function(a, b)
		local amaj, amin = a.dev:match("^(%d+):(%d+)$")
		local bmaj, bmin = b.dev:match("^(%d+):(%d+)$")
		amaj, amin = tonumber(amaj), tonumber(amin)
		bmaj, bmin = tonumber(bmaj), tonumber(bmin)
		if amaj ~= bmaj then return amaj < bmaj end
		return amin < bmin
	end)
end

local GLYPHS = {
	utf8 = { branch = "\u{251c}\u{2500}", last = "\u{2514}\u{2500}",
		down = "\u{2502} ", blank = "  " },
	ascii = { branch = "|-", last = "`-", down = "| ", blank = "  " },
}
local glyph = ascii and GLYPHS.ascii or GLYPHS.utf8

local rows = {}

-- The tree is drawn down the NAME column wherever that column sits,
-- and down the first one when no name was asked for
local tree_column = nil
for i, name in ipairs(columns) do
	if name == "NAME" then
		tree_column = i
		break
	end
end
-- with no name to draw it beside, there is no tree
if not tree_column then flat = true end

local function add_row(one, indent)
	local cells = {}
	for i, name in ipairs(columns) do
		local text = field(one, name)
		if i == tree_column then text = indent .. text end
		cells[i] = text
	end
	rows[#rows + 1] = cells
end

local function walk(one, indent, prefix_text)
	add_row(one, prefix_text)
	local kids = {}
	for _, kid in ipairs(one.children) do
		if interesting(kid) then kids[#kids + 1] = kid end
	end
	table.sort(kids, function(a, b) return a.name < b.name end)
	for n, kid in ipairs(kids) do
		local last = (n == #kids)
		walk(kid, indent .. (last and glyph.blank or glyph.down),
			indent .. (last and glyph.last or glyph.branch))
	end
end

-- Which device comes first, by the number the kernel gave it
local function before(a, b)
	local amaj, amin = a.dev:match("^(%d+):(%d+)$")
	local bmaj, bmin = b.dev:match("^(%d+):(%d+)$")
	amaj, amin = tonumber(amaj) or 0, tonumber(amin) or 0
	bmaj, bmin = tonumber(bmaj) or 0, tonumber(bmin) or 0
	if amaj ~= bmaj then return amaj < bmaj end
	return amin < bmin
end

if flat then
	-- a list has no parents to sit under, so it is one run of devices
	-- in device number order
	local all = {}
	local function gather(one)
		all[#all + 1] = one
		for _, kid in ipairs(one.children) do
			if interesting(kid) then gather(kid) end
		end
	end
	for _, one in ipairs(selected) do gather(one) end
	table.sort(all, before)
	for _, one in ipairs(all) do add_row(one, "") end
else
	for _, one in ipairs(selected) do walk(one, "", "") end
end

-- Every column is as wide as the widest thing in it. NAME is padded on
-- the right and the numbers on the left, which is what lsblk does.
local RIGHT = { RM = true, SIZE = true, RO = true }

-- Each column is as wide as the widest thing in it, heading included.
-- The numbers sit to the right of their column; everything else to the
-- left, and a trailing column that is empty still leaves its spaces.
local widths = {}
for i, name in ipairs(columns) do

	widths[i] = no_header and 0 or #name
end
for _, cells in ipairs(rows) do
	for i, text in ipairs(cells) do
		local width = utf8.len(text) or #text
		if width > widths[i] then widths[i] = width end
	end
end

local function pad_to(text, width, right)
	local short = width - (utf8.len(text) or #text)
	if short < 0 then short = 0 end
	if right then return string.rep(" ", short) .. text end
	return text .. string.rep(" ", short)
end

local function put(cells)
	local parts = {}
	for i, text in ipairs(cells) do
		-- the last column is padded on the left if it is a number and
		-- never on the right, so a row with nothing in it ends where
		-- its text ends
		local right = RIGHT[columns[i]]
		if i == #cells and not right then
			parts[i] = text
		else
			parts[i] = pad_to(text, widths[i], right)
		end
	end
	unistd.write(1, table.concat(parts, " ") .. "\n")
end

if not no_header then
	local head = {}
	for i, name in ipairs(columns) do
		head[i] = pad_to(name, widths[i], RIGHT[name])
	end
	unistd.write(1, (table.concat(head, " "):gsub("%s+$", "")) .. "\n")
end
for _, cells in ipairs(rows) do put(cells) end
