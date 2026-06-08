# Nexus Pascal Installation

Nexus Pascal is installed as a VS Code extension and works with local Pascal
toolchains such as Free Pascal and Lazarus.

## Install The Extension

Install Nexus Pascal from your local development package or the published
extension channel when available.

After installation, open a folder containing Pascal source, a Lazarus project,
or a Nexus project. Nexus Pascal starts NexusLS when Pascal language features
are needed.

## Install Pascal Tools

Nexus Pascal can help configure tools, but the tools themselves still need to
exist on the machine.

Common Windows installs include:

- Lazarus in `C:\lazarus`
- Free Pascal bundled under a Lazarus install
- standalone Free Pascal in `C:\FPC` or `C:\PP`

For many developers, installing Lazarus is the easiest first step because it
includes Free Pascal and the Lazarus build tools.

## Configure Toolchains

Use the Nexus Pascal toolchain configuration command in VS Code to review and
save toolchain settings.

The toolchain UI is driven by NexusLS. It can show fields for supported
toolchains, validate each field, and offer suggestions such as:

- a local Lazarus install path
- a local Free Pascal compiler path
- a Java or Android SDK location
- a download URL when a required install is missing

Toolchain settings may be saved even if some fields still need attention. This
lets you save a partial setup and return after installing missing tools.

## First Checks

After installing and configuring tools, verify:

- NexusLS starts without connection errors
- the selected project appears in the Nexus Pascal status UI
- units such as `SysUtils` resolve when a valid Free Pascal source path is known
- build tasks appear for the project you intend to work on
