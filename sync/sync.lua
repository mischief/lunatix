#!/usr/bin/env lua5.4
-- SPDX-License-Identifier: ISC
-- sync - flush what the kernel is holding
local unistd = require("posix.unistd")

if #arg > 0 then
	unistd.write(2, "usage: sync\n")
	os.exit(2)
end
unistd.sync()
