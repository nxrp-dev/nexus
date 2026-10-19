-- Exercise the real LinuxPlatform locale-preference copy path.
-- Run the engine under AddressSanitizer to detect expired temporary strings.
for _, preference in ipairs({ "language", "country", "identifier" }) do
    local value = system.getPreference("locale", preference)
    assert(type(value) == "string" and #value > 0, preference)
end
io.stderr:write("NXTEST_ENGINE_PREFERENCES_OK\n")
os.exit(0)
