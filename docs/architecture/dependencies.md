# Dependencies

This page describes the current dependency shape visible in the repository. It is a practical map, not a promise that every integration is mature.

## Internal dependency direction

- `packages/nexus-packages` contains the shared runtime packages.
- `packages/nexus-packages/core` owns the class factory and command-line helpers; `packages/nexus-packages/binding` owns source-independent binding.
- `projects/nxbuild/src` owns the Pascal project and compiler-option models. Its consumers include the Pascal language server; packages do not depend on these project-owned models.
- `packages/nexus-packages/lsp` depends on `packages/nexus-packages/core` and does not depend on either language server.
- `NexusTools/LS` depends on `packages/nexus-packages/core` and `packages/nexus-packages/lsp` for shared JSON-RPC/LSP mechanics.
- `projects/ls/nxscript` depends on `packages/nexus-packages/nxscript`, `packages/nexus-packages/core`, and `packages/nexus-packages/lsp`; it does not depend on the Pascal server, the NexusScript CLI, or artifact producers.
- `projects/nxscript/cli` depends on the reusable `packages/nexus-packages/nxscript` package. The package does not depend back on its consumers.
- `packages/nexus-packages/nxtest` is the reusable NexusTest framework package.
- `NexusTools/LS/NexusLSTestModule` depends on both `NexusTools/LS` source and `packages/nexus-packages/nxtest` source.
- `projects/nxtest/host` depends on `packages/nexus-packages/nxtest` and `packages/nexus-packages/core`; `projects/nxtest/ui` additionally depends on `packages/nexus-packages/gui`.

The preferred direction is from tools toward shared foundations, not from shared foundations back into tools.

## External dependencies

The shared packages use Free Pascal runtime units and, where needed, JSON support such as `fpjson` and `jsonparser`.

`NexusTools/LS` uses Free Pascal and Lazarus CodeTools/LazUtils units for Pascal parsing, navigation, completion, syntax checks, and source buffers. Symbol indexing currently has an SQLite-backed cache through FPC database units such as `SQLDB` and `SQLite3Conn`.

`packages/nexus-packages/lsp` uses `packages/nexus-packages/network/external/synapse` for its shared TCP/IP transport. Both language-server executables select shared stdio or TCP/IP transports and inject their own application model into the shared host.

`packages/nexus-packages/network/xmpp` uses bundled Synapse for TCP, DNS SRV, and the OpenSSL 3 TLS wrapper. OpenSSL 3 supplies SHA-256, HMAC, PBKDF2, secure random bytes, TLS, and certificate verification; it is not vendored by NexusXMPP. XMPP JID parts and authentication credentials deliberately accept ASCII only. UTF-8 stanza and message content remain transparent and do not require ICU, PRECIS, IDNA, or generated Unicode tables.

The NexusXMPP Phase 2 modules depend inward on the shared stanza, DOM,
connection-command, lifecycle, request-manager, and configuration owners. The
message model and forwarding decoder are shared only within NexusXMPP. MUC,
Carbons, MAM, receipts/chat state, ping, and discovery/capability logic remain
separate protocol owners; none depends on NexusUI, a Nexus tool, persistence, or
application/AI policy.

`packages/nexus-packages/nxtest` uses Free Pascal runtime support and `packages/nexus-packages/core` for JSON-RPC command processing. The test-family build script compiles the sample module, host, and UI from their respective `test/` roots.

`NexusTestUI` uses `packages/nexus-packages/gui` plus the package's fpGUI external tree. It is a client UI for test exploration, not the core NexusTest contract.

## Build outputs

The Lazarus project files place generated binaries and units under `output/...` directories. Documentation should treat those as build artifacts rather than source ownership roots.

## Dependency rule of thumb

When a feature is only meaningful for one project, keep it in that project. Shared packages must not import project-specific workflows.
