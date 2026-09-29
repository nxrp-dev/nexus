# Lua Package

This package contains the generic Lua integration shared by Nexus packages.

## Source

- `src/bindings/Lua51.pas` provides the legacy Lua 5.1 C ABI used by Solar2D.
- `src/bindings/Lua55.pas` provides Lua 5.5.1 C API declarations and macro equivalents.
- `src/Lua.Plugin.pas` provides the RTTI-backed `TLuaPlugin` bridge for the Lua 5.1 host ABI.

`Lua55` mirrors the default Lua 5.5.1 ABI (64-bit `lua_Integer`, double
`lua_Number`, pointer-sized `lua_KContext`). It declares imports by C symbol
name; consumers must link against a matching Lua 5.5 library. This package does
not bundle a Lua runtime. Upstream 5.5.1 headers are retained under `reference/`.

Solar2D-specific integration lives in the dependent
`packages/solar2d` package.