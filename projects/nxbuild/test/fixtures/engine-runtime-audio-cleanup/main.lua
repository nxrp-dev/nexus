-- Exercise the initialized audio path as well as the existing unused-audio cases.
local sound = audio.loadSound("tone.wav")
assert(sound, "The audio backend must load the PCM fixture")
audio.dispose(sound)
timer.performWithDelay(100, function()
    io.stderr:write("NXTEST_ENGINE_AUDIO_CLEANUP_OK\n")
    os.exit(0)
end)
