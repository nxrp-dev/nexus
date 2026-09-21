# Lua Package

This package contains the generic Lua integration shared by Nexus packages.

## Source

- `src/Lua51.pas` provides the Lua 5.1 C ABI declarations.
- `src/Lua.Plugin.pas` provides the generic RTTI-backed `TLuaPlugin` bridge.

Solar2D-specific integration lives in the dependent
`NexusLib/packages/solar2d` package.