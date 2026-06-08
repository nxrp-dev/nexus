# Nexus Pascal Building

Nexus Pascal is intended to make Pascal builds discoverable and repeatable from
inside VS Code.

## Build Context

Build behavior depends on project context.

Nexus Pascal can work with:

- Nexus project files
- Lazarus `.lpi` projects
- Free Pascal compiler workflows

When a Nexus project is present, it should be treated as the primary build
context for Nexus workflows. Lazarus and Free Pascal projects remain supported
for import and build behavior.

## Lazarus Builds

Lazarus projects build through Lazarus tooling such as `lazbuild`.

The Lazarus toolchain configuration identifies the Lazarus install directory.
From that, NexusLS can derive related paths such as `lazbuild`, Lazarus source,
and bundled Free Pascal directories.

## Free Pascal Builds

Free Pascal builds use the configured Free Pascal install or compiler path.

Nexus Pascal can derive a compiler path from a Free Pascal install directory and
derive a source directory when the install layout supports it.

## NexusBuild

NexusBuild is the command-line build direction for Nexus project files. It is
intended to understand a Nexus project and produce the correct work and command
lines for tools such as `fpc` and `lazbuild`.

The extension should eventually use this project model rather than forcing users
to hand-maintain every task detail.

## Cross Compilation

Cross compilation requires more than a target CPU and OS. It also needs a
configured compiler, target libraries, source paths, toolchain-specific options,
and sometimes packaging tools.

Nexus Pascal treats cross-target support as a toolchain and project capability.
Android support, for example, requires Android SDK, NDK, Java, compiler support,
packaging, and debugger integration.
