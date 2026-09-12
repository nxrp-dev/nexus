# Build notes

This archive contains source for the bridge and sample; it does not contain a prebuilt Solar2D plugin.

## Units

- `src/Lua51.pas` — minimal Lua 5.1 C ABI declarations used by the bridge.
- `src/Lua.Plugin.pas` — generic RTTI-backed `TLuaPlugin` object bridge.
- `src/Solar2D.Corona.pas` — Solar2D `CoronaLibrary` / `CoronaLua` C API declarations used by the Solar2D layer.
- `src/Solar2D.Plugin.pas` — `TSolarPlugin`, Solar2D library creation, and event integration.

The final link must resolve both the Lua 5.1 symbols used by `Lua51.pas` and the Solar2D Native symbols used by `Solar2D.Corona.pas`.

Solar2D's current native headers define `CoronaLibraryNew()` in `CoronaLibrary.h` and the event/ref helpers in `CoronaLua.h`. The engine repository currently carries the Lua 5.1 ABI.

For Windows, the FPC link needs the Solar2D Native import library or equivalent imports. For ELF/Mach-O/static targets, use the target's normal Solar2D Native link inputs.

## Quick validation order

1. Compile and run `tests/TestPublishedRTTI.pas`. It has no Lua/Solar2D link dependency and proves the required published RTTI/`Invoke()` behavior for the chosen FPC target.
2. Build `sample/plugin_sample.lpr` with `src` and `sample` on the unit path and the target Solar2D/Lua link inputs available.
3. Export `luaopen_plugin_sample` exactly as shown in the sample library project.
4. Load `sample/main.lua` under Solar2D and verify the link/property and event output.
5. Repeat the RTTI invoke check for every supported CPU/ABI. FPC can require a platform-specific invocation manager on targets where direct RTTI invocation is unavailable.

## Verification status

The bridge and sample compile on the local FPC 3.2.2 Win64 toolchain with linking disabled. The published-link RTTI test compiles and passes. A native Solar2D runtime test still requires the matching target compiler and link inputs.
