# System Boundaries

Nexus is a repository of related Pascal tools, not one monolithic runtime. The current source tree keeps the main areas in top-level folders with clear local ownership.

## Current modules

- `NexusLib` contains shared Pascal support code used by other Nexus modules. It owns core helpers plus library families such as `core`, `lsp`, `ui`, and `net`. `NexusLib/lsp` owns only standard LSP values and language-neutral transport, dispatch, outbound-request, and server-host mechanics.
- `NexusTools/LS` contains the Pascal language server. It owns Pascal documents, CodeTools integration, custom project/toolchain/refactoring protocol values, concrete requests, diagnostics, navigation, completion, symbols, and Pascal language-server test coverage.
- `NexusTools/Script` owns the NexusScript language core, artifact production, CLI, and the separate `NexusScriptLS` process. Its language server currently owns only lifecycle and full-text open-document state; editor intelligence is not implemented in this restructuring pass.
- `NexusTools/Test` contains NexusTest, a first-pass test framework and module contract. It owns test registration, suites, cases, result values, JSON-RPC test commands, a module boundary, sample host/module code, and a small UI.
- `NexusSchema` contains schema-oriented tooling.
- `docs` contains the MkDocs documentation site.

## Integration boundaries

`NexusLib` is the shared base layer. It should stay small and general enough to be reused by `NexusTools/LS`, `NexusTools/Test`, and other tools without absorbing their workflows.

`NexusTools/LS` and `NexusScriptLS` are independent tool processes. Each owns its request registration, application model, documents, and language behavior while consuming the same language-neutral `NexusLib/lsp` process infrastructure. Neither server depends on the other.

`NexusTest` is a test execution boundary. Test modules expose a small C-style ABI and exchange UTF-8 JSON-RPC text. Pascal objects, Pascal strings, records, exceptions, and caller-owned allocations do not cross that module boundary.

`NexusLib/ui` is a UI runtime library. It owns UI source, tests, docs, resources, and bin output conventions, but not language-server or test-framework semantics. `NexusTestUI` can use it as a client interface, but that does not move NexusTest ownership into the UI library.

`NexusSchema` is separate from UI, language-server, and testing concerns. Its documentation and implementation should describe schema inputs and generation behavior, not become a catch-all for other Nexus modules.

## Current direction

The repository is moving toward a documented ecosystem where modules can cooperate without hiding ownership. Shared code belongs in `NexusLib` when it is genuinely reusable. Module-specific behavior should stay near the module that owns the behavior.
