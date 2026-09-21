# Using Forge packages

Packages declare named outputs, requirements, accepted Targets, and ordinary
Forge operations. Packages with an EntryPoint operation always execute; other
packages reuse existing artifacts. When execution is required, Forge obtains the
prerequisites and runs the package's operations sequentially.
Every declared output must exist afterward.

From the repository root:

```powershell
& .\output\NexusForge\x86_64-win64\nxforge.exe `
  /input=NexusLib\script\examples\forge\hello.ForgePackage.nxscript `
  /package=Hello `
  /targets=TargetCPU:x64,TargetOS:Windows
```

Every request invokes FPC once for the application EntryPoint, including when
`hello package.exe` already exists. FPC decides which units need recompilation.
Packages without an EntryPoint operation retain artifact-presence reuse.
The CLI reports package completion, native commands, exits, and output paths.

Each actual package build writes `build.log` beside the first declared output,
after target selection. A directory output places the log beside that directory,
not inside it. Each attempt replaces the previous log; artifact reuse leaves it
untouched. Packages sharing an output directory therefore share this log location.

The log contains the package and targets, operation templates, working directories,
commands, separate stdout/stderr sections, exit statuses, and build diagnostics.
Render operations record their source and output paths. Preparation and missing-output
failures are recorded too, provided the log directory can be created and written.
It is a completed-attempt record, not a live stream. Operations that did not start
are marked accordingly. Log-write failures are reported to the caller.

The log is not a readiness artifact and cannot be declared as an output at that
reserved path. Creating it never creates a directory artifact. Source inventories
and source-change tracking are not part of logging.

## Definition and target contract

Package supports optional text properties `Version`, `Author`, and `License`.
Its definition name supplies the name. These values remain ordinary compiled
properties for references and resource/archive consumers; they do not affect
package identity, target selection, or artifact reuse. There is no version-format
parsing or license validation.

The package root is the directory containing its defining source file. Operations
run there, and relative output paths resolve there. Multiple packages can share
a file or directory; `/package` selects a definition. The filename convention
`*.ForgePackage.nxscript` is optional and does not trigger directory scanning.
The invocation's input path resolves from the caller's directory. Relative Template
paths resolve from the source file supplying the value, including inherited and
referenced values. Shared configurations are loaded using ordinary modules.

```nexusscript
module "Shared.nxscript";

Package Hello {
    Targets: [
        Dimension TargetCPU { Required: True; Allowed: [x64]; },
        Dimension TargetOS { Required: True; Allowed: [Windows]; }
    ];
    Outputs: [Output Application { Path: "hello package.exe"; }];
    FPC Compile (CompileFPC) {
        Source: ["hello world & test.lpr"];
        EntryPoint: "hello world & test.lpr";
        Output: @Hello.Outputs.Application.Path;
    }
}
```

Required, undeclared, and disallowed selections are checked before artifact reuse.
An omitted optional dimension stays unspecified. Declaration order determines
display order; request equality uses named selections independently of their order.
Existing NexusScript compilation still precedes Forge's checks.

An output can declare `Directory: True`; otherwise it must be a file. Absolute
paths are allowed, for example to describe an existing compiler executable.
After deciding a build is needed and obtaining prerequisites, Forge creates the
parent directories of the selected artifacts before launching operations. Failure
to create a directory stops the build. A ready package skips this preparation.
Paths remain those explicitly selected by Targets; no new naming scheme is inferred.
Directory artifacts themselves are not precreated to satisfy readiness.

Operation properties are ordinary data. Forge does not infer directory preparation
or location restrictions from a property named Output. Intermediate files may live
outside the final artifact directories; their preparation belongs to the recipe.

FPC declares an optional text UnitOutput property. The template uses it for -FU
when supplied. Our configurations explicitly place units beside the executable:
the simple example inherits UnitOutput: ".", and the PasBuild package references
BuildPaths.Directory. Paths supplied to the compiler resolve from its working
directory, which is the package root for managed builds.

## Shared configuration and artifact names

The examples' Shared.nxscript supplies `FPC CompileFPC` with Template and UnitOutput properties.
The concrete operation inherits it and supplies its Source, EntryPoint, and Output. Validation
applies to that completed operation; a module base can be partial. The executor
renders its resolved Template directly, without selecting a separate process entry.

Environment data can supply filename conventions. For example, a shared module
can declare target-selected `Environment Platform` definitions with an
ExecutableSuffix property. A package then defines the name once:

```nexusscript
Outputs: [Output Application { Path: "app" + @Platform.ExecutableSuffix; }];
FPC Compile (CompileFPC) {
    Source: ["app.lpr"];
    EntryPoint: "app.lpr";
    UnitOutput: ".";
    Output: @App.Outputs.Application.Path;
}
```

Here App is the containing package. The same resolved filename drives artifact
presence checks and compiler output. These are ordinary NexusScript values and
references; Forge has no hard-coded executable suffix or operating-system table.
See the [PasBuild shared configuration](../../../NexusLib/script/examples/forge/pasbuild-comparison/Shared.nxscript)
and [package](../../../NexusLib/script/examples/forge/pasbuild-comparison/PasBuild.ForgePackage.nxscript)
for a complete example with target-selected directories and compiler settings.

## Dependency outputs

Load a package definition using ordinary `module` syntax, then reference it:

```nexusscript
module Compiler "compiler.ForgePackage.nxscript";
module "Shared.nxscript";

Package App {
    Targets: [
        Dimension TargetCPU { Required: True; Allowed: [x64]; },
        Dimension TargetOS { Required: True; Allowed: [Windows]; }
    ];
    Requires: [Requirement Tools {
        Package: @Compiler;
        Targets: [
            Selection TargetCPU { Value: x64; },
            Selection TargetOS { Value: Windows; }
        ];
    }];
    Outputs: [Output Application { Path: "app.exe"; }];
    PackageOutput CompilerPath { Requirement: Tools; Output: Compiler; }
    FPC Compile (CompileFPC) {
        Compiler: @App.CompilerPath;
        Source: ["app.lpr"];
        EntryPoint: "app.lpr";
        Output: @App.Outputs.Application.Path;
    }
}
```

The referenced Compiler package must declare the named Compiler output and its
own target contract. Each requirement supplies its dependency's selections
explicitly. Forge obtains that request, then resolves CompilerPath to the
output's absolute path in the rendering context. No reference syntax or generic
JSON behavior is changed. The descriptor can also supply FPC EntryPoint or Git
Repository values.

Each package imports its own shared configurations. A dependency request compiles
those definitions with that dependency's Targets, independently of its consumer.
A ready package skips prerequisite artifact checks/builds and does not read unused
command template files; normal language compilation still needs referenced
definition files.

## Failure and ownership

Prerequisite failures prevent consumer execution. Operation failures stop the
recipe; exit zero with missing outputs also fails. Partial artifacts remain.
For packages without EntryPoint, existing artifacts satisfy a later request even
after an earlier failure. EntryPoint packages invoke their compiler again. Forge
maintains no success receipts, timestamps, or hashes.

The coordinator owns its request records, compilation sessions, and runners.
Exposed request/result references are borrowed until the next Execute or destruction.
The active request chain guards build cycles; existing module/reference cycle
errors can occur during compilation first.

## Verification scope

The package suite covers build/reuse, target validation, dependency-specific
configuration selection, repeated requests, optional selections, multiple packages and
shared roots, custom filenames, directory outputs, missing/unknown outputs,
prerequisite failure, and partial artifacts. It also compiles real Pascal source
using an installed FPC executable exposed as a package output.

This verifies compiler consumption, not an FPC bootstrap or cross-compiler recipe.
No version solver, downloads, Forge freshness tracking, or NexusScript core changes
are included. Standalone Forge operation execution remains available.

## Generated artifacts

A package may use Render to compile/validate a source document and write a declared
artifact through its Template. See the [Render contract](contracts.md#render-artifacts)
and [BotHost schema package](../../../NexusLib/script/bothost/database/README.md). Artifact presence
remains the readiness test; no hashing or database connection is implied.
