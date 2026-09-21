# Nexus

Nexus is a Pascal project family focused on practical tools and frameworks:

- `NexusLib/packages/gui` for TNX-facing GUI framework source, tests, docs, resources, and bin.
- `NexusForge` for schema-driven generation.
- `NexusTools/LS` for Pascal language-server behavior.
- `NexusTools/Script` for the NexusScript language, artifact/CLI tooling, and its dedicated language-server shell.
- `NexusLib/packages/nxtest` for the reusable test framework, with `nxtest/host` and `nxtest/ui` for host and GUI test running.
- `NexusLib` for shared runtime code, including language-neutral LSP infrastructure.

The projects are developed together, but each keeps a clear ownership boundary. Documentation should follow those boundaries instead of mixing runtime, tooling, test, and schema concepts into one pile.

## Start Here

- Use the ecosystem page for the repository map.
- Use module sections for project-specific architecture and behavior.
- Use guides for workflows that cross module boundaries.
- Use reference pages for conventions and shared facts.
