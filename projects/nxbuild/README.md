# nxbuild

nxbuild compiles a NexusScript project description into the existing typed
Pascal project/build options, plans its compiler invocation, and optionally
runs it. It does not use Forge or define packages.

Build the executable with `lazbuild projects/nxbuild/nxbuild.lpi`. On Win64 it
is written to `output/nxbuild/x86_64-win64/nxbuild.exe`.

```powershell
output/nxbuild/x86_64-win64/nxbuild.exe /action=plan /project=projects/nxbuild/examples/Hello.nxp
output/nxbuild/x86_64-win64/nxbuild.exe /action=build /project=projects/nxbuild/examples/Hello.nxp
```

## Input

A `.nxp` file now contains NexusScript, not JSON. Other filenames work when
passed explicitly. Declare the project-owned dialect
`language/nxbuild.Language.nxscript` and exactly one `Project` root.
See `examples/Hello.nxp` and `examples/Lazarus.nxp`.

NexusCode discovers `.nxp` files (including `.nexus/project.nxp`) and sends
them to nxbuild without attempting to parse them as JSON. Its project list
uses descriptor filenames for labels, or the folder for `project.nxp`.

The VS Code new-project and Lazarus-import commands generate the same
NexusScript format. NexusLS locates the nxbuild dialect under its enclosing
Nexus root and emits a dialect path relative to the destination folder
(absolute when the destination is on another drive). The existing explicit
project root/filename and build/output settings are retained.

The root label supplies the project name; an explicit `Name` property can
override it. Existing published project fields remain available. Owned object
properties are child sections with their property name as the definition kind:
`Toolchain`, `TargetPlatform`, `FPCBuildOptions`, and each compiler option
section. Each section can occur at most once. String lists are unnamed text
arrays; `Variables` entries use `"name=value"`.

Enums use their Pascal names without the three-letter prefix: `FPC`,
`Lazarus`, `Program`, `ObjFPC`, `Enabled`, `Disabled`, `Unset`, and so
on. Booleans and integers are validated as such. Unknown fields, unknown
sections and invalid enum choices are rejected before planning.

Normal NexusScript scalar references and expressions are compiled by the
common compiler. Native Live values are copied directly into the typed project;
there is no intermediate JSON artifact or retained compiler ownership.

## Existing build behavior

The descriptor's folder defaults to `ProjectRoot`; `ProjectFileName` defaults
to the descriptor's absolute filename. Existing `$(Variable)` substitution,
relative build paths, output directory preparation and FPC/Lazarus planning
are unchanged.

The existing model makes `Toolchain.CompilerPath` authoritative over
`FPCBuildOptions.CompilerPath`, and `TargetPlatform.TargetOS` authoritative
over `FPCBuildOptions.Target.OperatingSystem`. Those rules remain unchanged.
If no compiler is specified, FPC uses the `PP` environment variable or `fpc`;
Lazarus uses `Toolchain.LazarusRoot`, `LAZARUSDIR`, `LAZBUILD`, or `lazbuild`.
The Lazarus example sets a local example variable; adjust it for your machine.

Tests: `lazbuild projects/nxbuild/test/nxbuildTests.lpi`, then run
`output/nxbuildTests/x86_64-win64/nxbuildTests.exe` from the repository root.
