# Naming and Ownership

Nexus uses top-level module folders for ownership and shorter lower-case slugs for documentation paths.

## Module names

- `packages/nexus-packages`: shared Pascal packages, including core helpers, source-independent binding, serialization, networking, GUI, and LSP.
- `projects/nxbuild`: Pascal project/build models and NexusScript project-building behavior.
- `NexusTools/LS`: Pascal language server.
- `projects/nxscript`: NexusScript core, artifact producers, CLI, and dedicated language server.
- `packages/nexus-packages/nxtest`: reusable NexusTest framework and module protocol.
- `projects/nxtest/host`: NexusTest command-line host and sample module.
- `projects/nxtest/ui`: NexusTest GUI runner.
- `NexusForge`: schema tooling.

Documentation slugs should stay readable and stable:

- `docs/nexus-lib`
- `docs/nexus-ls`
- `docs/nexus-test`
- `docs/nexus-ui`
- `docs/nexus-forge`

## Source naming patterns

The current Pascal source uses a few common prefixes:

- `obNX...` for object-oriented units and classes.
- `tpNX...` for shared types, constants, and top-level module definitions.
- `tsNX...` for test suite units.
- `utNX...` for utility/helper units.
- `frm...` and `ui...` for UI-facing units.

These are current conventions visible in the source tree. They should be followed when adding nearby code unless a module has a more specific local pattern.

## Ownership rules

Each top-level module or library family owns its own source, examples, tests, and module-specific documentation. Cross-module pages should describe boundaries and dependency direction instead of taking ownership away from the source module.

Packages must not depend on project-owned implementation. General core helpers and source-independent binding remain package-owned; the Pascal build models belong to nxbuild.

Standard LSP values and language-neutral process mechanics belong to `packages/nexus-packages/lsp`. Concrete requests, documents, lifecycle state, analysis, and language-specific protocol extensions belong to the server that implements them. NexusScript language semantics belong to `packages/nexus-packages/nxscript`, not in the shared LSP library.

Documentation should not invent maturity. If a module is early, experimental, or a current direction, describe it that way.
