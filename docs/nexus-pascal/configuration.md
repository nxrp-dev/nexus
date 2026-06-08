# Nexus Pascal Configuration

Nexus Pascal configuration is split between VS Code storage and NexusLS-owned
behavior.

VS Code stores settings. NexusLS defines what the settings mean.

## Toolchain Configuration

Toolchains are configured through a Nexus Pascal UI backed by NexusLS.

The extension asks NexusLS:

- which toolchains are supported
- which fields are needed
- which fields are valid
- which local paths or download URLs can be suggested

Current toolchain kinds include:

- Lazarus
- Free Pascal
- Android

## Lazarus

The Lazarus toolchain is based on the Lazarus install directory.

From that directory, NexusLS can derive:

- `lazbuild`
- Lazarus source directory
- bundled Free Pascal directory

## Free Pascal

The Free Pascal toolchain may use either an install directory or an explicit
compiler path.

From a Free Pascal install directory, NexusLS can derive:

- compiler path
- Free Pascal source directory

## Android

Android configuration tracks the Android SDK, Android NDK, and Java Home.

Android support is a future-facing toolchain area. Even before full Android
build/debug support is complete, configuring these fields gives Nexus Pascal a
clear place to validate and explain the required environment.

## Saving Partial Settings

Nexus Pascal allows saving partial or currently invalid toolchain settings.

This is intentional. A user may know one required path before installing another
tool. Validation messages and suggestions should make the missing pieces clear
without blocking the user from saving progress.

## VS Code Settings

The user-facing configuration UI is preferred for toolchains.

Raw VS Code settings remain available for direct inspection and workspace
management, but the main workflow should be the Nexus Pascal toolchain UI.
