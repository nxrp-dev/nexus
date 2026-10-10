# nxbuild

nxbuild compiles a NexusScript project description into the existing typed
Pascal project/build options, plans its compiler invocation, and optionally
runs it. It does not use Forge or define packages.

The native project model and FPC option sections live in this project's
source folder: obNXPascalProject.pas and obNXFPCBuildOptions.pas.

Build the executable with `lazbuild projects/nxbuild/nxbuild.lpi`. On Win64 it
is written to `output/nxbuild/x86_64-win64/nxbuild.exe`.

```powershell
output/nxbuild/x86_64-win64/nxbuild.exe /action=plan /project=projects/nxbuild/examples/Hello.nxproject
output/nxbuild/x86_64-win64/nxbuild.exe /action=build /project=projects/nxbuild/examples/Hello.nxproject
```

## Input

A `.nxproject` file now contains NexusScript, not JSON. Other filenames work when
passed explicitly. Declare the project-owned dialect
`language/nxbuild.Language.nxscript` and exactly one `Project` root.
See `examples/Hello.nxproject` and `examples/Lazarus.nxproject`.

NexusCode discovers `.nxproject` files (including `.nexus/project.nxproject`) and sends
them to nxbuild without attempting to parse them as JSON. Its project list
uses descriptor filenames for labels, or the folder for `project.nxproject`.

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
arrays.

Enums use their Pascal names without the three-letter prefix: `FPC`,
`Lazarus`, `Program`, `ObjFPC`, `Enabled`, `Disabled`, `Unset`, and so
on. Booleans and integers are validated as such. Unknown fields, unknown
sections and invalid enum choices are rejected before planning.

C-style operators are enabled by default for FPC builds (`-Sc`), even when
the `Syntax` section is omitted. To disable them explicitly:

```nexusscript
FPCBuildOptions Compiler {
    Syntax Options { COperators: Disabled; }
}
```

`Enabled` emits `-Sc`; `Disabled` emits `-Sc-`. An explicit `Unset` emits
neither switch and leaves the choice to the compiler configuration.

Use normal NexusScript scalar references and expressions for shared values:

```nexusscript
Project Example {
    OutputRoot: "output";
    FPCBuildOptions Compiler {
        OutputFile: @Example.OutputRoot + "/example.exe";
        Files Paths { UnitOutputPath: @Example.OutputRoot + "/units"; }
    }
}
```

These expressions are compiled by the common compiler. Native Live values
are copied directly into the typed project;
there is no intermediate JSON artifact or retained compiler ownership.

## Existing build behavior

The descriptor's folder defaults to `ProjectRoot`; `ProjectFileName` defaults
to the descriptor's absolute filename. Relative build paths, including a
`Toolchain.CompilerPath` containing a directory, resolve against `ProjectRoot`.
A bare compiler name remains available for lookup through `PATH`.

Project scripts and generators use native references and expressions. The build
model consumes their compiled values and resolves filesystem paths; it performs
no additional variable substitution.

The existing model makes `Toolchain.CompilerPath` authoritative over
`FPCBuildOptions.CompilerPath`, and `TargetPlatform.TargetOS` authoritative
over `FPCBuildOptions.Target.OperatingSystem`. Those rules remain unchanged.
If no compiler is specified, FPC uses the `PP` environment variable or `fpc`;
Lazarus uses `Toolchain.LazarusRoot`, `LAZARUSDIR`, `LAZBUILD`, or `lazbuild`.
The Lazarus example sets `Toolchain.LazarusRoot`; adjust it for your machine.

Tests: `lazbuild projects/nxbuild/test/nxbuildTests.lpi`, then run
`output/nxbuildTests/x86_64-win64/nxbuildTests.exe` from the repository root.
