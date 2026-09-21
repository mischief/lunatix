#!/bin/sh
# SPDX-License-Identifier: ISC
# Nothing here logs anybody in: what can be tested without privilege is
# that a wrong password is refused and that usage errors are caught.
D="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/../testenv.sh"
LOGIN="lua5.4 $D/login.lua"

$LOGIN --bogus 2>&1 | grep -q "usage: login" || exit 1
# a name nobody has, answered with a password, is refused three times
out=$(printf 'nosuchuser\nx\nnosuchuser\nx\nnosuchuser\nx\n' | $LOGIN 2>&1)
echo "$out" | grep -q "Login incorrect" || exit 1
# and the account lookup itself says no
lua5.4 -e 'local a = require("lunatix.auth")
local e, why = a.account("definitely-no-such-user")
assert(e == nil and why == "no such user")
local mine = a.account(os.getenv("USER") or "root")
assert(mine == nil or type(mine.pw_uid) == "number")' || exit 1
exit 0
