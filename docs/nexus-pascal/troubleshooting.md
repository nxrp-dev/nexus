# Nexus Pascal Troubleshooting

This page lists common Nexus Pascal setup and workflow problems.

## The Language Server Does Not Start

Check the Nexus Pascal output channel in VS Code.

Useful things to verify:

- the NexusLS executable exists
- the extension is pointing at the expected NexusLS build
- the language server process is not locked by another VS Code window
- initialization options contain the expected toolchain settings

## Units Do Not Resolve

If project units or system units do not resolve, check project and toolchain
context first.

Common causes:

- no selected project context
- workspace root is above the actual project folder
- Free Pascal source directory is missing
- Lazarus project paths were not discovered
- toolchain settings are saved but invalid

Use the project selector and toolchain configuration UI to confirm what NexusLS
is using.

## System Units Do Not Resolve

System units such as `SysUtils`, `Classes`, and `Contnrs` require Free Pascal
source paths.

Configure Lazarus or Free Pascal so NexusLS can derive the Free Pascal source
directory. If the install layout is nonstandard, configure the explicit paths
that match your toolchain.

## Build Tasks Are Missing

Build task availability depends on project discovery and project kind.

Check whether Nexus Pascal detected:

- a `.nxp` project file
- a Lazarus `.lpi` project
- a Free Pascal source/project context

When a Nexus project and Lazarus project are both present, Nexus Pascal should
prefer the Nexus project for Nexus workflows.

## Toolchain Fields Need Attention

A field warning means the setting was saved but NexusLS does not consider that
field ready.

Open the toolchain configuration UI and review:

- the field message
- local path suggestions
- download URL suggestions

Saving partial settings is allowed, but builds and language features may remain
limited until required fields are corrected.

## Debugging Does Not Launch

Debugging requires a valid build output and launch configuration.

Verify:

- the project builds successfully
- the debug executable path exists
- the working directory is correct
- debug information is enabled in the build
- the selected debugger supports the target platform
