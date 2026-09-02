# The Nexus Ecosystem

Nexus is organized as a family of related Pascal projects.

## Module Map

- `NexusLib/ui`: retained-mode UI framework source, controls, layout, rendering, input routing, windows, popups, skins, tests, docs, resources, and bin.
- `NexusSchema`: schema model and generation tooling.
- `NexusLib/lsp`: standard LSP values and language-neutral server process infrastructure.
- `NexusTools/LS`: Pascal language-server executable, requests, documents, and services.
- `NexusTools/Script`: NexusScript core, artifact and CLI tooling, plus the dedicated NexusScriptLS lifecycle/document shell.
- `NexusTools`: framework-related tools, including NexusBuild, NexusTask, NexusTest, and NexusLS.
- `NexusLib`: shared JSON, JSON-RPC/LSP, persistence, command-line, and support code.
- `scripts`: repository automation used by builds, archives, notifications, and development workflow.
- `codec`: legacy or supporting code; document it only where it is intentionally part of the current architecture.

## Boundary Rule

Each module should document what it owns. Cross-module workflows belong in guides. Shared concepts belong in reference or architecture pages.

This keeps the docs useful as the repository grows: readers can find the owner of a concept without reading every page.
