# NexusLS

NexusLS is the Pascal language-server module in the Nexus repository. It lives under `NexusTools/LS` and provides Pascal document state and language services backed by Free Pascal and Lazarus CodeTools. Standard LSP values and language-neutral process mechanics live in `NexusLib/lsp` and are shared with the separate NexusScriptLS process.

## Source layout

- `nexusls.lpr` is the main server entry point.
- `src` contains settings and the Pascal server/model units.
- `src/protocol` contains concrete Pascal request classes, command names, and custom project, toolchain, and refactoring protocol values.
- `src/service` contains lifecycle, document, workspace, diagnostics, navigation, completion, refactoring, editor, command, inactive-region, and symbol services.
- `testclient` contains a Lazarus client for sending sample requests to the server.
- `NexusLSTestModule` contains NexusTest-based language-server tests.

## Runtime shape

The server registers command-line flags for `/mode`, `/host`, and `/port`. The default mode is stdio. TCP/IP mode is available through the shared transport factory.

Incoming messages are parsed as JSON-RPC 2.0, dispatched by method name through the class factory, and executed by request classes. Notifications do not produce responses. Requests return success or JSON-RPC error responses.

The LSP model owns open documents, initialization state, settings, effective FPC options, workspace paths, and service instances. Document state is represented as file URIs, local paths, versions, text, and CodeTools buffers.

## Current language services

The source currently includes services for:

- lifecycle and initialization
- full text document sync
- diagnostics and inactive regions
- navigation and references
- completion and editor intelligence
- refactoring and command execution
- document and workspace symbols
- workspace folder updates

Some services are still pragmatic and CodeTools-driven. Symbol indexing includes a fallback scanner and an SQLite-backed cache named `symbols.sqlite`.

## Boundaries

NexusLS depends on `NexusLib/core` for JSON-RPC support and `NexusLib/lsp` for standard LSP values, transport, dispatch, outbound request matching, and the injected server host. Pascal requests, documents, analysis, services, and indexes remain inside `NexusTools/LS`. NexusLS does not host NexusScript or depend on `NexusTools/Script`.

NexusScript uses a separate `NexusScriptLS` executable under `NexusTools/Script/ls`. The two servers share process infrastructure, not document or analysis code.

The test client and test module are development support surfaces. They do not redefine the server's public boundary, which remains LSP over the configured transport.
