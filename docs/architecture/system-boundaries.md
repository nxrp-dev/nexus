# System Boundaries

Nexus is a repository of related Pascal tools, not one monolithic runtime. The current source tree keeps the main areas in top-level folders with clear local ownership.

## Current modules

- `NexusLib` contains shared Pascal support code used by other Nexus modules. It owns JSON value helpers, JSON-RPC message handling, command-line parsing, persistence helpers, and class registration.
- `NexusLS` contains the Pascal language server. It owns LSP protocol DTOs, request dispatch, transports, document state, CodeTools integration, diagnostics, navigation, completion, symbols, and language-server test coverage.
- `NexusTest` contains a first-pass test framework and module contract. It owns test registration, suites, cases, result values, JSON-RPC test commands, a module boundary, sample host/module code, and a small UI.
- `NexusUI` contains the UI framework and examples.
- `NexusSchema` contains schema-oriented tooling.
- `docs` contains the MkDocs documentation site.

## Integration boundaries

`NexusLib` is the shared base layer. It should stay small and general enough to be reused by `NexusLS`, `NexusTest`, and other tools without absorbing their workflows.

`NexusLS` is a tool process. Its public boundary is the Language Server Protocol over stdio or TCP/IP transport. It should keep editor protocol concerns inside its protocol and service units, while relying on `NexusLib` for reusable JSON-RPC and factory behavior.

`NexusTest` is a test execution boundary. Test modules expose a small C-style ABI and exchange UTF-8 JSON-RPC text. Pascal objects, Pascal strings, records, exceptions, and caller-owned allocations do not cross that module boundary.

`NexusUI` is a UI runtime, not the owner of language-server or test-framework semantics. `NexusTestUI` can use NexusUI as a client interface, but that does not move NexusTest ownership into NexusUI.

`NexusSchema` is separate from UI, language-server, and testing concerns. Its documentation and implementation should describe schema inputs and generation behavior, not become a catch-all for other Nexus modules.

## Current direction

The repository is moving toward a documented ecosystem where modules can cooperate without hiding ownership. Shared code belongs in `NexusLib` when it is genuinely reusable. Module-specific behavior should stay near the module that owns the behavior.
