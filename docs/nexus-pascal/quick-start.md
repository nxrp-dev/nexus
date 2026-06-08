# Nexus Pascal Quick Start

This quick start is for opening a Pascal workspace in VS Code and getting Nexus
Pascal connected to the right project and toolchain context.

## 1. Open A Pascal Workspace

Open the folder that contains your Pascal sources.

For best results, open a folder that contains one or more of:

- a Lazarus `.lpi` file
- a Free Pascal program or package source tree
- a Nexus `.nxp` project file

Nexus Pascal can discover project candidates recursively, which is useful when
your VS Code workspace is larger than a single Lazarus project folder.

## 2. Select Or Confirm A Project

Use the project selection UI to choose the project Nexus Pascal should use.

When multiple project files are present, Nexus project files are preferred for
Nexus workflows. Lazarus projects remain supported for import, build, and
source-context behavior.

## 3. Configure Toolchains

Open the Nexus Pascal toolchain configuration UI and verify the relevant
toolchain:

- Lazarus for Lazarus projects and `lazbuild`
- Free Pascal for direct `fpc` workflows
- Android for future Android build and debug support

If a path is invalid, the field will explain the problem. When possible, NexusLS
will suggest a local install path or a download link.

## 4. Open Source And Navigate

Open a Pascal unit and try common language features:

- go to definition for units and symbols
- switch between routine declarations and implementations
- view document symbols
- inspect diagnostics

NexusLS uses the selected project and toolchain context to resolve units and
system paths.

## 5. Build

Use the VS Code task list or Nexus Pascal project commands to build the selected
project.

For Lazarus projects, Nexus Pascal can build through Lazarus tooling. For Nexus
projects, build behavior is expected to flow through the Nexus project model and
Nexus build tooling.
