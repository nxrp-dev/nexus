# Dependencies

This page describes the current dependency shape visible in the repository. It is a practical map, not a promise that every integration is mature.

## Internal dependency direction

- `NexusLib` is the common base layer.
- `NexusLib/packages/lsp` depends on `NexusLib/core` and does not depend on either language server.
- `NexusTools/LS` depends on `NexusLib/core` and `NexusLib/packages/lsp` for shared JSON-RPC/LSP mechanics.
- `NexusTools/Script/ls` depends on `NexusLib/packages/nxscript`, `NexusLib/core`, and `NexusLib/packages/lsp`; it does not depend on the Pascal server, the NexusScript CLI, or artifact producers.
- `NexusTools/Script/cli` depends on the reusable `NexusLib/packages/nxscript` package. The package does not depend back on its consumers.
- `NexusLib/packages/nxtest` is the reusable NexusTest framework package.
- `NexusTools/LS/NexusLSTestModule` depends on both `NexusTools/LS` source and `NexusLib/packages/nxtest` source.
- `nxtest/host` depends on `NexusLib/packages/nxtest` and `NexusLib/core`; `nxtest/ui` additionally depends on `NexusLib/packages/gui`.

The preferred direction is from tools toward shared foundations, not from shared foundations back into tools.

## External dependencies

`NexusLib` uses Free Pascal runtime units and JSON support such as `fpjson` and `jsonparser`.

`NexusTools/LS` uses Free Pascal and Lazarus CodeTools/LazUtils units for Pascal parsing, navigation, completion, syntax checks, and source buffers. Symbol indexing currently has an SQLite-backed cache through FPC database units such as `SQLDB` and `SQLite3Conn`.

`NexusLib/packages/lsp` uses `NexusLib/packages/network/external/synapse` for its shared TCP/IP transport. Both language-server executables select shared stdio or TCP/IP transports and inject their own application model into the shared host.

`NexusLib/packages/network/xmpp` uses bundled Synapse for TCP, DNS SRV, and the OpenSSL 3 TLS wrapper. OpenSSL 3 supplies SHA-256, HMAC, PBKDF2, secure random bytes, TLS, and certificate verification; it is not vendored by NexusXMPP. XMPP JID parts and authentication credentials deliberately accept ASCII only. UTF-8 stanza and message content remain transparent and do not require ICU, PRECIS, IDNA, or generated Unicode tables.

The NexusXMPP Phase 2 modules depend inward on the shared stanza, DOM,
connection-command, lifecycle, request-manager, and configuration owners. The
message model and forwarding decoder are shared only within NexusXMPP. MUC,
Carbons, MAM, receipts/chat state, ping, and discovery/capability logic remain
separate protocol owners; none depends on NexusUI, a Nexus tool, persistence, or
application/AI policy.

`NexusLib/packages/nxtest` uses Free Pascal runtime support and `NexusLib/core` for JSON-RPC command processing. The test-family build script compiles the sample module, host, and UI from their respective `test/` roots.

`NexusTestUI` uses `NexusLib/packages/gui` plus the package's fpGUI external tree. It is a client UI for test exploration, not the core NexusTest contract.

## Build outputs

The Lazarus project files place generated binaries and units under `output/...` directories. Documentation should treat those as build artifacts rather than source ownership roots.

## Dependency rule of thumb

When a feature is only meaningful for one module, keep it in that module. Move code to `NexusLib` only when more than one module can use it without importing unrelated assumptions.
