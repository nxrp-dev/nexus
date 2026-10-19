-- Populate the real FreeType provider and retain a text object through teardown.
local label = display.newText("NXTest font lifetime", 160, 40, native.systemFont, 16)
assert(label.width > 0 and label.height > 0)
timer.performWithDelay(100, function()
    io.stderr:write("NXTEST_ENGINE_FONT_OK\n")
    os.exit(0)
end)
