-- Replacing an alert destroys a window while the main rendering context survives.
-- Leave the second alert alive to check teardown before its Lua runtime is freed.
local function listener()
    error("No dialog button should be pressed in this test")
end
assert(native.showAlert("NXTest first alert", "Replace this window", { "OK" }, listener))
timer.performWithDelay(100, function()
    assert(native.showAlert("NXTest second alert", "Release this window on exit", { "OK" }, listener))
    local label = display.newText("Rendering after dialog replacement", 160, 40, native.systemFont, 16)
    assert(label.width > 0 and label.height > 0)
    timer.performWithDelay(100, function()
        io.stderr:write("NXTEST_ENGINE_DIALOG_CLEANUP_OK\n")
        os.exit(0)
    end)
end)
