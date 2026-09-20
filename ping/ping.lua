#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- ping - send ICMP echo requests

local unistd = require("posix.unistd")
local socket = require("posix.sys.socket")
local poll = require("posix.poll")
local time = require("posix.time")
local signal = require("posix.signal")

local function usage()
	io.stderr:write("usage: ping [-c count] [-i interval] host\n")
	os.exit(1)
end

local count = 0  -- 0 = infinite
local interval = 1
local host = nil

local optind = 1
for opt, optarg, oi in unistd.getopt(arg, "c:i:") do
	if opt == "?" then usage() end
	if opt == "c" then count = tonumber(optarg) or usage() end
	if opt == "i" then interval = tonumber(optarg) or usage() end
	optind = oi
end
host = arg[optind]
if not host then usage() end

-- Resolve host
local addrs = socket.getaddrinfo(host, "0", {family = socket.AF_INET})
if not addrs or #addrs == 0 then
	io.stderr:write(string.format("ping: %s: Name or service not known\n", host))
	os.exit(2)
end
local dest_addr = addrs[1].addr

-- ICMP checksum
local function checksum(data)
	local sum = 0
	for i = 1, #data - 1, 2 do
		sum = sum + string.unpack(">I2", data, i)
	end
	if #data % 2 == 1 then
		sum = sum + string.byte(data, #data) * 256
	end
	while sum > 0xffff do
		sum = (sum & 0xffff) + (sum >> 16)
	end
	return (~sum) & 0xffff
end

-- Build ICMP echo request
local function make_echo(id, seq)
	-- 8 bytes header + 48 bytes padding = 56 bytes payload (like real ping)
	local payload = string.pack(">I2I2", id, seq) .. string.rep("\0", 48)
	local hdr = string.pack(">BBH", 8, 0, 0) .. payload
	local cs = checksum(hdr)
	return string.pack(">BBH", 8, 0, cs) .. payload
end

-- Get time in milliseconds
local function now_ms()
	local ts = time.clock_gettime(time.CLOCK_MONOTONIC)
	return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0
end

-- The unprivileged ICMP socket first: it needs no capability, but only
-- for a gid inside net.ipv4.ping_group_range, which by default holds
-- nobody at all. A raw socket is the fallback, and wants CAP_NET_RAW.
local fd, derr = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_ICMP)
local raw = false
if not fd then
	local rerr
	fd, rerr = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)
	raw = fd ~= nil
	if not fd then
		io.stderr:write("ping: cannot create an ICMP socket: " ..
			tostring(derr) .. " (datagram), " .. tostring(rerr) .. " (raw)\n")
		io.stderr:write("ping: a datagram socket needs a gid in " ..
			"net.ipv4.ping_group_range, a raw one needs CAP_NET_RAW\n")
		os.exit(2)
	end
end

local dest = {family = socket.AF_INET, addr = dest_addr, port = 0}
local id = unistd.getpid() & 0xffff
local seq = 0
local sent = 0
local received = 0
local min_ms, max_ms, sum_ms = math.huge, 0, 0

local running = true
signal.signal(signal.SIGINT, function() running = false end)

io.write(string.format("PING %s (%s): 56 data bytes\n", host, dest_addr))

while running do
	seq = seq + 1
	local pkt = make_echo(id, seq)
	local t0 = now_ms()
	socket.sendto(fd, pkt, dest)
	sent = sent + 1

	-- Wait for the reply to this request. A raw socket also hands back
	-- our own echo request and anyone else's traffic, so read until the
	-- reply turns up or the time is gone.
	local fds = {[fd] = {events = {IN = true}}}
	local deadline = t0 + 2000
	while true do
		local left = deadline - now_ms()
		if left <= 0 then break end
		local ready = poll.poll(fds, math.floor(left))
		if not ready or ready == 0 then break end
		local data = socket.recv(fd, 1500)
		if not data then break end
		local ms = now_ms() - t0
		-- a raw socket hands back the IP header as well
		local reply = data
		if raw then
			local ihl = ((string.byte(data, 1) or 0) & 0x0f) * 4
			reply = (ihl >= 20 and #data > ihl) and data:sub(ihl + 1) or ""
		end
		local typ = string.byte(reply, 1)
		-- id and sequence are the two bytes at 5 and 7. The kernel
		-- rewrites the id on a datagram socket, so only match it raw.
		local rid = (string.byte(reply, 5) or 0) * 256 + (string.byte(reply, 6) or 0)
		local rseq = (string.byte(reply, 7) or 0) * 256 + (string.byte(reply, 8) or 0)
		if typ == 0 and rseq == seq and (not raw or rid == id) then
			received = received + 1
			if ms < min_ms then min_ms = ms end
			if ms > max_ms then max_ms = ms end
			sum_ms = sum_ms + ms
			io.write(string.format("%d bytes from %s: icmp_seq=%d time=%.1f ms\n",
				#reply, dest_addr, seq, ms))
			break
		end
	end

	if count > 0 and seq >= count then break end
	if running and seq < count or count == 0 then
		unistd.sleep(interval)
	end
end

-- Summary
io.write(string.format("\n--- %s ping statistics ---\n", host))
io.write(string.format("%d packets transmitted, %d received, %d%% packet loss\n",
	sent, received, math.floor((sent - received) / sent * 100)))
if received > 0 then
	io.write(string.format("round-trip min/avg/max = %.1f/%.1f/%.1f ms\n",
		min_ms, sum_ms / received, max_ms))
end

os.exit(received > 0 and 0 or 1)
