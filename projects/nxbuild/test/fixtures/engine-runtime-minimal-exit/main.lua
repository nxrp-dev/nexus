print("NXBUILD_ENGINE_RUNTIME_OK")
local r=display.newRect(40,40,20,20)
assert(r.width==20)
timer.performWithDelay(100,function() print("NXBUILD_ENGINE_RUNTIME_DONE");os.exit(0) end)
