-- Copyright (c) 2026 Kevin Collins.
-- SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
-- Regression: the Linux simulator aborts while destroying its app from os.exit.
local rectangle = display.newRect(40, 40, 20, 20)
assert(rectangle.width == 20)
timer.performWithDelay(100, function()
    io.stderr:write("NXTEST_ENGINE_LUA_REACHED\n")
    io.stderr:flush()
    os.exit(0)
end)
