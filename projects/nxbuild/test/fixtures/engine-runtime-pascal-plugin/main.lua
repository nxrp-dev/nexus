-- Copyright (c) 2026 Kevin Collins.
-- SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end

local function run()
    local path = assert(os.getenv("NXTEST_PASCAL_PLUGIN"))
    local open, loadError = package.loadlib(path, "luaopen_plugin_sample")
    assert(open, loadError)
    package.preload["plugin.sample"] = open
    local sample = require("plugin.sample")
    check(type(sample.new) == "function", "Pascal plugin must export its constructor")
    local obj = sample.new()
    obj.Name = "Nexus"
    obj.Volume = 0.75
    check(obj.Name == "Nexus", "String property round trip")
    check(obj.Volume == 0.75, "Floating-point property round trip")
    check(obj:Add(20, 22) == 42, "Pascal integer method")
    check(obj:Add(-20, 22) == 2, "Signed Pascal arguments")
    check(obj:Greeting("Solar2D") == "Hello, Solar2D from Pascal", "Pascal string result")

    local pulses, tablePulses, removedPulses = 0, 0, 0
    local function onPulse(event)
        pulses = pulses + 1
        check(event.value == 6 + pulses, "Pascal event value")
        check(event.message == "Pulse from Pascal", "Pascal event string")
    end
    local tableListener = {}
    function tableListener:pulse(event)
        tablePulses = tablePulses + 1
        check(event.value == 7, "Table listener")
    end
    local selfRemoving
    selfRemoving = function(event)
        removedPulses = removedPulses + 1
        check(obj:removeEventListener("pulse", selfRemoving), "Remove listener during dispatch")
    end
    check(obj:addEventListener("pulse", onPulse), "Register function listener")
    check(obj:addEventListener("pulse", tableListener), "Register table listener")
    check(obj:addEventListener("pulse", selfRemoving), "Register self-removing listener")
    obj:Pulse(7)
    check(obj:removeEventListener("pulse", tableListener), "Remove table listener")
    obj:Pulse(8)
    check(pulses == 2 and tablePulses == 1 and removedPulses == 1, "Listener lifetimes")
    check(obj:removeEventListener("pulse", onPulse), "Remove final listener")

    obj:dispatchEvent({name = "setVolume", value = 0.25})
    check(obj.Volume == 0.25, "Lua event handled by Pascal")
    local runtimePulses = 0
    local function onRuntimePulse(event)
        runtimePulses = runtimePulses + 1
        check(event.value == 99, "Pascal event dispatched through the real engine Runtime")
    end
    Runtime:addEventListener("samplePulse", onRuntimePulse)
    obj:Broadcast(99)
    Runtime:removeEventListener("samplePulse", onRuntimePulse)
    check(runtimePulses == 1, "One runtime callback")

    obj:Reset()
    check(obj.Name == "" and obj.Volume == 1.0, "Pascal reset method")
    local add = obj.Add
    obj = nil
    collectgarbage()
    collectgarbage()
    check(add(20, 22) == 42, "Detached method retains its Pascal object")
    add = nil
    collectgarbage()
    collectgarbage()
end

local ok, message = xpcall(run, debug.traceback)
if not ok then
    io.stderr:write("NXTEST_ENGINE_PASCAL_PLUGIN_FAILED: " .. tostring(message) .. "\n")
    os.exit(1)
end
timer.performWithDelay(100, function()
    io.stderr:write("NXTEST_ENGINE_PASCAL_PLUGIN_OK: " .. checks .. " checks\n")
    os.exit(0)
end)
