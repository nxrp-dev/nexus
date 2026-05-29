# Dependencies

This page describes the current dependency shape visible in the repository. It is a practical map, not a promise that every integration is mature.

## Internal dependency direction

- `NexusLib` is the common base layer.
- `NexusLS` depends on `NexusLib`.
- `NexusTest` depends on `NexusLib`.
- `NexusLS/NexusLSTestModule` depends on both `NexusLS` source and `NexusTest` source.
- `NexusTest/NexusTestUI` depends on `NexusTest`, `NexusLib`, and `NexusUI`.

The preferred direction is from tools toward shared foundations, not from shared foundations back into tools.

## External dependencies

`NexusLib` uses Free Pascal runtime units and JSON support such as `fpjson` and `jsonparser`.

`NexusLS` uses Free Pascal and Lazarus CodeTools/LazUtils units for Pascal parsing, navigation, completion, syntax checks, and source buffers. Its project file also includes `lib/synapse`, and the source has stdio and TCP/IP transport implementations. Symbol indexing currently has an SQLite-backed cache through FPC database units such as `SQLDB` and `SQLite3Conn`.

`NexusTest` uses Free Pascal runtime support, `DynLibs` for loading test modules from a host, and `NexusLib` for JSON-RPC command processing. The sample Linux/macOS-ish build script compiles the sample test module and host with `NexusTest/src` and `../NexusLib/src`.

`NexusTestUI` uses `NexusUI` plus SDL-related unit paths from the common tree. It is a client UI for test exploration, not the core NexusTest contract.

## Build outputs

The Lazarus project files place generated binaries and units under `output/...` directories. Documentation should treat those as build artifacts rather than source ownership roots.

## Dependency rule of thumb

When a feature is only meaningful for one module, keep it in that module. Move code to `NexusLib` only when more than one module can use it without importing unrelated assumptions.
