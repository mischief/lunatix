-- SPDX-License-Identifier: ISC
-- lunatix/probe.lua - what a filesystem says it is. Every filesystem
-- writes a magic number and, these days, a UUID and a label at a fixed
-- place near the front of the device. Reading those is all blkid does,
-- and all anyone needs to mount by UUID.
local M = {}

local function read_at(f, offset, length)
	if not f:seek("set", offset) then return nil end
	local data = f:read(length)
	if not data or #data < length then return nil end
	return data
end

-- A UUID as it is written down: 16 bytes in the usual five groups
local function uuid_of(bytes)
	if not bytes or #bytes ~= 16 or bytes == string.rep("\0", 16) then return nil end
	local hex = (bytes:gsub(".", function(c) return string.format("%02x", c:byte()) end))
	return hex:sub(1, 8) .. "-" .. hex:sub(9, 12) .. "-" .. hex:sub(13, 16)
		.. "-" .. hex:sub(17, 20) .. "-" .. hex:sub(21, 32)
end

local function text_of(bytes)
	if not bytes then return nil end
	local s = bytes:gsub("%z.*$", ""):gsub("%s+$", "")
	-- what mkfs.vfat writes when nobody named the volume
	if s == "" or s == "NO NAME" then return nil end
	return s
end

-- ext2, ext3 and ext4 share a superblock at 1024 bytes in. Which of the
-- three it is comes from the feature flags: a journal makes it ext3, and
-- extents or the 64bit flag make it ext4.
local function probe_ext(f)
	local sb = read_at(f, 1024, 264)
	if not sb then return nil end
	if string.unpack("<I2", sb, 57) ~= 0xEF53 then return nil end
	local compat = string.unpack("<I4", sb, 93)
	local incompat = string.unpack("<I4", sb, 97)
	local kind = "ext2"
	if (compat & 0x0004) ~= 0 then kind = "ext3" end
	if (incompat & (0x0040 | 0x0080)) ~= 0 then kind = "ext4" end
	return {
		type = kind,
		uuid = uuid_of(sb:sub(105, 120)),
		label = text_of(sb:sub(121, 136)),
	}
end

-- A swap area keeps its signature at the end of the first page and its
-- uuid and label just past the boot block.
local function probe_swap(f)
	local magic = read_at(f, 4096 - 10, 10)
	if magic ~= "SWAPSPACE2" and magic ~= "SWAP-SPACE" then return nil end
	local head = read_at(f, 1024, 44)
	if not head then return { type = "swap" } end
	return {
		type = "swap",
		uuid = uuid_of(head:sub(13, 28)),
		label = text_of(head:sub(29, 44)),
	}
end

-- FAT has no uuid, only a volume id, which blkid writes as XXXX-XXXX.
-- Where the id and the label sit depends on which FAT it is.
local function probe_vfat(f)
	local boot = read_at(f, 0, 512)
	if not boot then return nil end
	-- the jump instruction every FAT boot sector starts with
	local first = boot:byte(1)
	if first ~= 0xEB and first ~= 0xE9 then return nil end
	local id_at, label_at, kind
	if boot:sub(83, 87) == "FAT32" then
		id_at, label_at, kind = 68, 72, "FAT32"
	elseif boot:sub(55, 57) == "FAT" then
		id_at, label_at, kind = 40, 44, text_of(boot:sub(55, 62)) or "FAT"
	else
		return nil
	end
	local id = boot:sub(id_at, id_at + 3)
	local a, b = string.unpack("<I2I2", id)
	return {
		type = "vfat",
		version = kind,
		uuid = string.format("%04X-%04X", b, a),
		label = text_of(boot:sub(label_at, label_at + 10)),
	}
end

-- xfs and btrfs put theirs further in, and both keep the uuid whole
local function probe_xfs(f)
	local sb = read_at(f, 0, 128)
	if not sb or sb:sub(1, 4) ~= "XFSB" then return nil end
	return {
		type = "xfs",
		uuid = uuid_of(sb:sub(33, 48)),
		label = text_of(sb:sub(109, 120)),
	}
end

local function probe_btrfs(f)
	local sb = read_at(f, 0x10000, 0x200)
	if not sb or sb:sub(65, 72) ~= "_BHRfS_M" then return nil end
	return {
		type = "btrfs",
		uuid = uuid_of(sb:sub(33, 48)),
		label = text_of(sb:sub(300, 355)),
	}
end

-- NTFS keeps a serial number rather than a uuid, written as sixteen
-- hex digits
local function probe_ntfs(f)
	local boot = read_at(f, 0, 512)
	if not boot or boot:sub(4, 11) ~= "NTFS    " then return nil end
	local serial = boot:sub(73, 80)
	local hex = {}
	for i = #serial, 1, -1 do
		hex[#hex + 1] = string.format("%02X", serial:byte(i))
	end
	return { type = "ntfs", uuid = table.concat(hex) }
end

-- An LVM physical volume carries a label in the second sector and its
-- uuid as 32 characters, which LVM writes in groups
local function probe_lvm(f)
	local label = read_at(f, 512, 32)
	if not label or label:sub(1, 8) ~= "LABELONE" then return nil end
	if label:sub(25, 32) ~= "LVM2 001" then return nil end
	local pv = read_at(f, 512 + 32, 32)
	if not pv then return { type = "LVM2_member" } end
	local parts = { pv:sub(1, 6), pv:sub(7, 10), pv:sub(11, 14),
		pv:sub(15, 18), pv:sub(19, 22), pv:sub(23, 26), pv:sub(27, 32) }
	return { type = "LVM2_member", uuid = table.concat(parts, "-") }
end

-- LUKS writes its uuid as text, in both header versions
local function probe_luks(f)
	local head = read_at(f, 0, 208)
	if not head or head:sub(1, 6) ~= "LUKS\186\190" then return nil end
	return { type = "crypto_LUKS", uuid = text_of(head:sub(169, 208)) }
end

local function probe_iso(f)
	local vd = read_at(f, 0x8000, 128)
	if not vd or vd:sub(2, 6) ~= "CD001" then return nil end
	return { type = "iso9660", label = text_of(vd:sub(41, 72)) }
end

local probes = {
	probe_ext, probe_swap, probe_vfat, probe_xfs, probe_btrfs, probe_ntfs,
	probe_lvm, probe_luks, probe_iso,
}

-- What is on a device, or nil for something with nothing on it
function M.probe(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local found = nil
	for _, one in ipairs(probes) do
		local ok, result = pcall(one, f)
		if ok and result then
			found = result
			break
		end
	end
	f:close()
	if found then found.device = path end
	return found
end

-- The block devices this machine has, as /proc/partitions lists them.
-- The whole disks come before their partitions there, which is the
-- order blkid reports them in.
function M.devices()
	local out = {}
	local f = io.open("/proc/partitions", "r")
	if not f then return out end
	for line in f:lines() do
		local name = line:match("^%s*%d+%s+%d+%s+%d+%s+(%S+)$")
		if name then out[#out + 1] = "/dev/" .. name end
	end
	f:close()
	return out
end

-- The device carrying a tag, for the UUID= and LABEL= an fstab is
-- written with
function M.find(tag, value)
	tag = tag:lower()
	for _, path in ipairs(M.devices()) do
		local info = M.probe(path)
		if info and info[tag] == value then return path end
	end
	return nil
end

-- "UUID=xxx" and "LABEL=xxx" name a device without saying where it is
-- plugged in, which is the only way to write an fstab that survives a
-- disk being moved.
function M.resolve(spec)
	local tag, value = spec:match("^(%u+)=(.*)$")
	if not tag then return spec end
	if tag == "UUID" or tag == "LABEL" then
		return M.find(tag, value)
	end
	return spec
end

return M
