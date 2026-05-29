# NexusLS

NexusLS is the Pascal language-server module in the Nexus repository. It provides an LSP process with stdio and TCP/IP transports, JSON-RPC request dispatch, protocol DTOs, document state, and language services backed by Free Pascal and Lazarus CodeTools.

## Source layout

- `nexusls.lpr` is the main server entry point.
- `src` contains transport, logging, settings, dispatch, project, and server/model units.
- `src/protocol` contains LSP protocol objects, params, request classes, and command names.
- `src/service` contains lifecycle, document, workspace, diagnostics, navigation, completion, refactoring, editor, command, inactive-region, and symbol services.
- `testclient` contains a Lazarus client for sending sample requests to the server.
- `NexusLSTestModule` contains NexusTest-based language-server tests.

## Runtime shape

The server registers command-line flags for `/mode`, `/host`, and `/port`. The default mode is stdio. TCP/IP mode is available through the transport factory.

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

NexusLS depends on `NexusLib` for shared JSON, JSON-RPC, command-line, and class-factory behavior. It should keep LSP protocol and editor behavior inside `NexusLS`.

The test client and test module are development support surfaces. They do not redefine the server's public boundary, which remains LSP over the configured transport.
