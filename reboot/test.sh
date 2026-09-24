#!/bin/sh
# SPDX-License-Identifier: ISC
# Nothing here calls reboot(2). What can be tested is the argument
# handling, and that without -f the machine's last step is asked of
# init rather than taken.
D="$(dirname "$0")"
. "$(dirname "$0")/../testenv.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

lua5.4 "$D/reboot.lua" --bogus 2>&1 | grep -q "usage: reboot" || exit 1
cp "$D/reboot.lua" "$TMP/notaname.lua"
lua5.4 "$TMP/notaname.lua" 2>&1 | grep -q "call me as reboot" || exit 1

command -v unshare >/dev/null 2>&1 || exit 77
unshare -r -p -f true 2>/dev/null || exit 77

# an init that only says which signal reached it
cat > "$TMP/init.lua" <<'EOF'
local signal = require("posix.signal")
local unistd = require("posix.unistd")
local wait = require("posix.sys.wait")
local got
local names = { [signal.SIGTERM] = "reboot", [signal.SIGUSR1] = "halt",
	[signal.SIGUSR2] = "poweroff" }
for sig, name in pairs(names) do
	signal.signal(sig, function() got = name end)
end
local pid = unistd.fork()
if pid == 0 then
	unistd.execp("lua5.4", { arg[1] })
	os.exit(127)
end
-- a signal cuts the wait short: nil with EINTR is not an exit status
local status
repeat
	local who, how, st = wait.wait(pid)
	if who == pid and (how == "exited" or how == "killed") then status = st end
until status ~= nil
for _ = 1, 100 do
	if got then break end
	require("posix.time").nanosleep({ tv_sec = 0, tv_nsec = 10000000 })
end
print((got or "nothing") .. " " .. tostring(status))
EOF

for name in poweroff halt reboot; do
	cp "$D/reboot.lua" "$TMP/$name.lua"
	out=$(unshare -r -p -f lua5.4 "$TMP/init.lua" "$TMP/$name.lua" 2>&1)
	[ "$out" = "$name 0" ] || { echo "$name: init saw [$out]"; exit 1; }
done
exit 0
