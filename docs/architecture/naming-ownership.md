# Naming and Ownership

Nexus uses top-level module folders for ownership and shorter lower-case slugs for documentation paths.

## Module names

- `NexusLib`: shared Pascal support library.
- `NexusLS`: Pascal language server.
- `NexusTest`: test framework, module protocol, host, sample tests, and test UI.
- `NexusUI`: retained-mode UI framework.
- `NexusSchema`: schema tooling.

Documentation slugs should stay readable and stable:

- `docs/nexus-lib`
- `docs/nexus-ls`
- `docs/nexus-test`
- `docs/nexus-ui`
- `docs/nexus-schema`

## Source naming patterns

The current Pascal source uses a few common prefixes:

- `obNX...` for object-oriented units and classes.
- `tpNX...` for shared types, constants, and top-level module definitions.
- `tsNX...` for test suite units.
- `utNX...` for utility/helper units.
- `frm...` and `ui...` for UI-facing units.

These are current conventions visible in the source tree. They should be followed when adding nearby code unless a module has a more specific local pattern.

## Ownership rules

Each top-level module owns its own source, examples, tests, and module-specific documentation. Cross-module pages should describe boundaries and dependency direction instead of taking ownership away from the source module.

`NexusLib` should avoid depending on higher-level modules. A dependency from `NexusLib` into `NexusLS`, `NexusTest`, `NexusUI`, or `NexusSchema` would make the shared layer harder to reuse.

Documentation should not invent maturity. If a module is early, experimental, or a current direction, describe it that way.
