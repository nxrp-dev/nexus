# Dependencies

This page describes the current dependency shape visible in the repository. It is a practical map, not a promise that every integration is mature.

## Internal dependency direction

- `NexusLib` is the common base layer.
- `NexusLib/lsp` depends on `NexusLib/core` and does not depend on either language server.
- `NexusTools/LS` depends on `NexusLib/core` and `NexusLib/lsp` for shared JSON-RPC/LSP mechanics.
- `NexusTools/Script/ls` depends on `NexusTools/Script/core`, `NexusLib/core`, and `NexusLib/lsp`; it does not depend on the Pascal server, the NexusScript CLI, or artifact producers.
- `NexusTools/Script/artifact` and `NexusTools/Script/cli` depend on the NexusScript core. The core does not depend back on its consumers.
- `NexusTools/Test` depends on `NexusLib`.
- `NexusTools/LS/NexusLSTestModule` depends on both `NexusTools/LS` source and `NexusTools/Test` source.
- `NexusTools/Test/NexusTestUI` depends on NexusTest, `NexusLib/core`, and `NexusLib/ui`.

The preferred direction is from tools toward shared foundations, not from shared foundations back into tools.

## External dependencies

`NexusLib` uses Free Pascal runtime units and JSON support such as `fpjson` and `jsonparser`.

`NexusTools/LS` uses Free Pascal and Lazarus CodeTools/LazUtils units for Pascal parsing, navigation, completion, syntax checks, and source buffers. Symbol indexing currently has an SQLite-backed cache through FPC database units such as `SQLDB` and `SQLite3Conn`.

`NexusLib/lsp` uses `lib/synapse` for its shared TCP/IP transport. Both language-server executables select shared stdio or TCP/IP transports and inject their own application model into the shared host.

`NexusLib/net/src/xmpp` uses bundled Synapse for TCP, DNS SRV, and the OpenSSL 3 TLS wrapper. The XMPP-specific Unicode adapter dynamically loads the operating-system ICU C API for NFC, Unicode properties, case mapping, bidi data, and UTS #46 IDNA; checked-in IANA Unicode 6.3 PRECIS ranges provide the protocol-specific derived-property classification. OpenSSL 3 supplies SHA-256, HMAC, PBKDF2, secure random bytes, TLS, and certificate verification. Neither ICU nor OpenSSL is vendored by NexusXMPP.

`NexusTools/Test` uses Free Pascal runtime support, `DynLibs` for loading test modules from a host, and `NexusLib` for JSON-RPC command processing. The sample Linux/macOS-ish build script compiles the sample test module and host with `NexusTools/Test/src` and `../../NexusLib/core/src`.

`NexusTestUI` uses `NexusLib/ui` plus SDL-related unit paths from the common tree. It is a client UI for test exploration, not the core NexusTest contract.

## Build outputs

The Lazarus project files place generated binaries and units under `output/...` directories. Documentation should treat those as build artifacts rather than source ownership roots.

## Dependency rule of thumb

When a feature is only meaningful for one module, keep it in that module. Move code to `NexusLib` only when more than one module can use it without importing unrelated assumptions.
