local sample = require("plugin.sample")

local obj = sample.new()

obj.Name = "Nexus"
obj.Volume = 0.75

print(obj.Name)
print(obj.Volume)
print(obj:Add(20, 22))
print(obj:Greeting("Solar2D"))

local function onPulse(event)
    print("local pulse", event.value, event.message)
end

local tableListener = {}
function tableListener:pulse(event)
    print("table pulse", event.value)
end

local selfRemoving
selfRemoving = function(event)
    print("self-removing pulse", event.value)
    assert(obj:removeEventListener("pulse", selfRemoving))
end

assert(obj:addEventListener("pulse", onPulse))
assert(obj:addEventListener("pulse", tableListener))
assert(obj:addEventListener("pulse", selfRemoving))
obj:Pulse(7)
assert(obj:removeEventListener("pulse", tableListener))
obj:Pulse(8)

obj:dispatchEvent({ name = "setVolume", value = 0.25 })
print("volume after Lua event", obj.Volume)

local function onRuntimePulse(event)
    print("runtime pulse", event.value)
end

Runtime:addEventListener("samplePulse", onRuntimePulse)
obj:Broadcast(99)
Runtime:removeEventListener("samplePulse", onRuntimePulse)

-- A link closure retains the userdata, so this remains safe after the
-- original Lua variable is released. It can be called either bound or detached.
local add = obj.Add
obj = nil
collectgarbage()
collectgarbage()
print("retained link", add(20, 22))
add = nil
collectgarbage()
collectgarbage()
