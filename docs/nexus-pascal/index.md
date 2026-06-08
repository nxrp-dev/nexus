# Nexus Pascal

Nexus Pascal is the Visual Studio Code development layer for Pascal projects.
It brings Free Pascal, Lazarus, and Nexus project workflows into one editor
experience backed by NexusLS, the Nexus Pascal language server.

The goal is simple: open a Pascal workspace, select the project or toolchain
context you care about, and get useful editor behavior without constantly
switching between disconnected tools.

## What Nexus Pascal Is For

Nexus Pascal is aimed at developers who want VS Code to understand Pascal
projects as projects, not just loose source files.

It is designed to help with:

- Free Pascal and Lazarus source navigation
- Lazarus project discovery and import
- Nexus project creation and build workflows
- language-server-backed diagnostics and code intelligence
- toolchain configuration for Free Pascal, Lazarus, and future targets
- build and debug task generation from project context

Nexus Pascal is not intended to replace Free Pascal or Lazarus. It sits beside
them and gives VS Code a Pascal-aware workflow.

## Core Capabilities

### Project-aware editing

Nexus Pascal can discover Pascal project files in a workspace, surface project
choices in the editor, and pass that context to NexusLS. This gives the language
server the information it needs for unit resolution, system paths, and
project-specific behavior.

### Code intelligence

NexusLS provides Pascal-aware navigation, symbols, diagnostics, completion, and
editor intelligence. The current focus is practical source understanding:
finding units, switching between declarations and implementations, and making
common Pascal workflows feel natural inside VS Code.

### Toolchain configuration

The extension asks NexusLS what toolchains are supported and what fields those
toolchains need. NexusLS validates the fields, derives related paths, and can
suggest local installs or download locations when a required tool cannot be
found.

### Build workflows

Nexus Pascal supports project-driven build behavior for Free Pascal, Lazarus,
and Nexus project files. The long-term direction is for Nexus project files to
become the primary project description for Nexus workflows while still allowing
existing Lazarus and Free Pascal projects to be imported and built.

### Debugging workflows

Debugging is intended to work through VS Code launch configurations and
Pascal-aware project context. Nexus Pascal focuses on making build outputs,
debug targets, and debugger settings easier to coordinate.

## Where To Start

- [Installation](installation.md) explains the extension and toolchain setup.
- [Quick Start](quick-start.md) walks through the first project workflow.
- [Configuration](configuration.md) explains toolchains and settings.
- [Building](building.md) explains build behavior.
- [Code Intelligence](code-intelligence.md) explains editor features.
- [Troubleshooting](troubleshooting.md) lists common problems and fixes.
