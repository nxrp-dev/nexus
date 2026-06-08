# Nexus Pascal Project Types

Nexus Pascal supports several Pascal project shapes. The goal is to make each
shape usable in VS Code while allowing Nexus project files to become the clean
project model for Nexus workflows.

## Nexus Projects

Nexus projects use `.nxp` files as their project description.

The `.nxp` file is intended to describe how a Nexus Pascal project should build,
run, and relate to supporting project files. Over time, this becomes the
preferred project format for Nexus workflows.

When a Nexus project and a Lazarus project sit side by side, Nexus Pascal should
treat the Nexus project as the primary project context.

## Lazarus Projects

Lazarus projects use `.lpi` files and are important for existing Free Pascal
applications, packages, build modes, forms, and Lazarus-specific workflows.

Nexus Pascal supports Lazarus projects for:

- project discovery
- import into Nexus project workflows
- build behavior through Lazarus tooling
- language-server context such as paths, target settings, and unit resolution

## Free Pascal Projects

Free Pascal projects may be simple source trees, command-line programs, or
manual `fpc` build workflows.

Nexus Pascal supports Free Pascal toolchain configuration and direct compiler
context so a workspace can work without requiring a Lazarus project file.

## Future Targets

The project model is designed to grow toward additional targets such as Android
and Nexus UI applications. These targets require more than compiler paths: they
need toolchains, packaging rules, launch behavior, and debug integration.

Nexus Pascal treats those as project and toolchain concerns, not random editor
settings.
