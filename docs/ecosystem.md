# The Nexus Ecosystem

Nexus is organized as a family of related Pascal projects.

## Module Map

- `NexusUI`: retained-mode UI framework, controls, layout, rendering, input routing, windows, popups, and skins.
- `NexusSchema`: schema model and generation tooling.
- `NexusLS`: language-server executable and LSP service implementation.
- `NexusTest`: test framework, JSON-RPC test-module contract, host client, and test UI.
- `NexusLib`: shared JSON, persistence, command-line, and support code.
- `scripts`: repository automation used by builds, archives, notifications, and development workflow.
- `codec`: legacy or supporting code; document it only where it is intentionally part of the current architecture.

## Boundary Rule

Each module should document what it owns. Cross-module workflows belong in guides. Shared concepts belong in reference or architecture pages.

This keeps the docs useful as the repository grows: readers can find the owner of a concept without reading every page.
