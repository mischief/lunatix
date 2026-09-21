#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- findmnt - what is mounted, as a tree, from /proc/self/mountinfo
local prefix = ((arg[0] or "findmnt"):match("(.+/)") or "./") .. "../"
package.path = prefix .. "?.lua;" .. prefix .. "share/lua/5.4/?.lua;" .. package.path

local unistd = require("posix.unistd")
local probe = require("lunatix.probe")
local util = require("luaposixcli.util")

local mountinfo = "/proc/self/mountinfo"

local flat, no_header, ascii = false, false, false
local want_type, want_source, holds_path = nil, nil, nil
local columns = { "TARGET", "SOURCE", "FSTYPE", "OPTIONS" }

local function usage()
	util.die("usage: findmnt [-lnA] [-o columns] [-t type] [-S source]\n" ..
		"                [-T path] [-F file] [target]", 2)
end

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "lnAo:t:S:T:F:") do
	if opt == "l" then flat = true
	elseif opt == "n" then no_header = true
	elseif opt == "A" then ascii = true
	elseif opt == "o" then
		columns = {}
		for name in optarg:gmatch("[^,]+") do
			columns[#columns + 1] = name:upper()
		end
	elseif opt == "t" then want_type = optarg
	elseif opt == "S" then want_source = optarg
	elseif opt == "T" then holds_path = optarg
	elseif opt == "F" then mountinfo = optarg
	else usage() end
	optind = oi
end
local operands = util.operands(arg, optind)
if #operands > 1 then usage() end
local want_target = operands[1]

-- The kernel writes a space, a tab, a newline and a backslash as their
-- octal escapes, so a mount point with a space in it stays one field.
local function unescape(text)
	return (text:gsub("\\(%d%d%d)", function(n) return string.char(tonumber(n, 8)) end))
end

-- A mountinfo line: id parent major:minor root target options
-- [tags...] - fstype source superoptions. The optional tags are what
-- the dash is there to mark the end of.
local function parse(line)
	local id, parent, dev, root, target, opts, rest =
		line:match("^(%d+) (%d+) (%S+) (%S+) (%S+) (%S+) (.*)$")
	if not id then return nil end
	local tail = rest:match("^.- %- (.*)$") or rest:match("^%- (.*)$")
	if not tail then return nil end
	local fstype, source, superopts = tail:match("^(%S+) (%S+) (%S*)$")
	if not fstype then return nil end
	-- The two option lists are shown as one. Both start with ro or rw,
	-- and the mount is read-only if either of them says so: a read-write
	-- mount of a read-only superblock still writes nothing.
	local extra = superopts:gsub("^r[wo],?", "")
	local readonly = opts:match("^ro") or superopts:match("^ro")
	opts = opts:gsub("^r[wo]", readonly and "ro" or "rw")
	return {
		id = tonumber(id),
		parent = tonumber(parent),
		dev = dev,
		root = unescape(root),
		target = unescape(target),
		fstype = fstype,
		source = unescape(source),
		options = extra ~= "" and (opts .. "," .. extra) or opts,
	}
end

local function read_mounts()
	local out = {}
	local text = util.slurp(mountinfo)
	if not text then util.die(mountinfo .. ": cannot read") end
	for line in util.lines(text) do
		local mount = parse(line)
		if mount then out[#out + 1] = mount end
	end
	return out
end

local mounts = read_mounts()

-- -S takes a device, and UUID= or LABEL= where a device would do
if want_source then
	want_source = probe.resolve(want_source) or want_source
end

-- -T names a file rather than a mount point: the answer is the mount it
-- is on, which is the longest target that is a prefix of it
local function holding(path)
	local best = nil
	for _, mount in ipairs(mounts) do
		local at = mount.target
		if path == at or at == "/" or path:sub(1, #at + 1) == at .. "/" then
			if not best or #at > #best.target then best = mount end
		end
	end
	return best
end

local selected = {}
if holds_path then
	local one = holding(holds_path)
	if one then selected[1] = one end
else
	for _, mount in ipairs(mounts) do
		local keep = true
		if want_target and mount.target ~= want_target then keep = false end
		if want_source and mount.source ~= want_source then keep = false end
		if want_type and mount.fstype ~= want_type then keep = false end
		if keep then selected[#selected + 1] = mount end
	end
end

if #selected == 0 then os.exit(1) end

-- A column is one field of a mount, and the ones that are not in
-- mountinfo come off the device itself
local function field(mount, name)
	if name == "TARGET" then return mount.target
	elseif name == "SOURCE" then return mount.source
	elseif name == "FSTYPE" then return mount.fstype
	elseif name == "OPTIONS" then return mount.options
	elseif name == "MAJ:MIN" then return mount.dev
	elseif name == "UUID" or name == "LABEL" then
		local info = probe.probe(mount.source)
		return info and info[name:lower()] or ""
	end
	util.die("unknown column: " .. name, 2)
end

-- The tree findmnt draws, from the parent each mount records. A mount
-- whose parent is not in the selection is a root of what is shown.
local GLYPHS = {
	utf8 = { branch = "\u{251c}\u{2500}", last = "\u{2514}\u{2500}",
		down = "\u{2502} ", blank = "  " },
	ascii = { branch = "|-", last = "`-", down = "| ", blank = "  " },
}

local rows = {}

local function add_row(mount, indent)
	local cells = {}
	for i, name in ipairs(columns) do
		local text = field(mount, name)
		if i == 1 then text = indent .. text end
		cells[i] = text
	end
	rows[#rows + 1] = cells
end

if flat or holds_path or want_target or want_source or want_type then
	for _, mount in ipairs(selected) do add_row(mount, "") end
else
	local children = {}
	local shown = {}
	for _, mount in ipairs(selected) do shown[mount.id] = mount end
	for _, mount in ipairs(selected) do
		-- an initramfs records / as its own parent, and a mount whose
		-- parent is not shown has nothing here to sit under: both are
		-- roots, and a mount made its own child is a tree with no top
		local under = 0
		if mount.parent ~= mount.id and shown[mount.parent] then
			under = mount.parent
		end
		children[under] = children[under] or {}
		table.insert(children[under], mount)
	end
	-- the file is in no particular order; the ids are the order the
	-- mounts were made in, which is the order findmnt shows them
	for _, kids in pairs(children) do
		table.sort(kids, function(a, b) return a.id < b.id end)
	end

	local glyph = ascii and GLYPHS.ascii or GLYPHS.utf8
	local walked = {}
	local function walk(id, indent)
		local kids = children[id]
		if not kids or walked[id] then return end
		walked[id] = true
		for n, mount in ipairs(kids) do
			local last = (n == #kids)
			if id == 0 then
				add_row(mount, "")
				walk(mount.id, "")
			else
				add_row(mount, indent .. (last and glyph.last or glyph.branch))
				walk(mount.id, indent .. (last and glyph.blank or glyph.down))
			end
		end
	end
	walk(0, "")
end

-- Every column is as wide as the widest thing in it, and the last one
-- is not padded at all
local widths = {}
for i, name in ipairs(columns) do
	widths[i] = no_header and 0 or utf8.len(name)
end
for _, cells in ipairs(rows) do
	for i, text in ipairs(cells) do
		local width = utf8.len(text) or #text
		if width > widths[i] then widths[i] = width end
	end
end

local function put(cells)
	local parts = {}
	for i, text in ipairs(cells) do
		if i == #cells then
			parts[i] = text
		else
			local pad = widths[i] - (utf8.len(text) or #text)
			parts[i] = text .. string.rep(" ", pad > 0 and pad or 0)
		end
	end
	unistd.write(1, table.concat(parts, " ") .. "\n")
end

if not no_header then put(columns) end
for _, cells in ipairs(rows) do put(cells) end
