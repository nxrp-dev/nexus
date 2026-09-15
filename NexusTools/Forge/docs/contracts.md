# NexusForge execution contracts

`nxforge` compiles and validates a Forge document, renders each concrete
operation's `Template` with Mustache, and executes the commands sequentially.
FPC and Git use the same execution code.

## CLI

From the repository root, with working `fpc` and `git` executables on PATH:

```powershell
lazbuild NexusTools\Forge\NexusForge.lpi
& .\output\NexusForge\x86_64-win64\nxforge.exe `
  /input=NexusTools\Forge\examples\Build.nxscript
```

The example compiles `hello world & test.lpr` and runs local `git status --short`.
Required: `/input=...`. Optional: `/targets=Name:Value,OtherName:OtherValue` and
`/working-directory=...`. Package requests additionally use `/package=...`; see
[package contracts](packages.md). There is no `/manifest` argument.

Flags use the existing Nexus command-line parser; quote the entire argument when
its value contains spaces. Targets are explicit; Forge does not infer host or
compilation targets. The input path resolves from the launch directory. The
child's default working directory is the operation document's directory. A
relative working-directory override resolves from that document directory.
Tool arguments remain relative to the child's working directory.

There is no dialect-selection or dialect-root CLI flag. Documents declare their
dialect through existing NexusScript resolution. Forge adds no search catalog,
environment repair, or activation logic.

## Language pieces

`NexusForge.Language.nxscript` includes `pieces/*.ForgeDef.nxscript`. Core, FPC,
Git, Package, and Environment definitions form one effective Forge language
through the included-definition view. The master does not name individual tools.
`ForgeDef` is a convention selected by this include pattern, not a filename rule.
The document declaration identifies its dialect.

## Shared configurations and environment data

A shared configuration file is an ordinary module. It may contain partial
operation configurations and target-selected environment data:

```nexusscript
Environment Platform TargetOS[Windows] { ExecutableSuffix: ".exe"; }
Environment Platform TargetOS[Linux] { ExecutableSuffix: ""; }
FPC CompileApplication { Template: "application.mustache"; }
FPC CompileTests { Template: "tests.mustache"; }
```

A consumer imports it and uses normal composition and references:

```nexusscript
module "Shared.nxscript";
FPC Compile (CompileApplication) {
    Source: "app.lpr";
    Output: "app" + @Platform.ExecutableSuffix;
}
FPC Test (CompileTests) {
    Source: "tests.lpr";
    Output: "tests" + @Platform.ExecutableSuffix;
}
```

Select TargetOS explicitly for this example. The completed concrete operations
must satisfy the FPC contract, including Template, Source, and Output. Imported
partial bases need not independently supply every required operation property.
They remain module definitions, not additional commands. Existing module root
selectors can limit which definitions a consumer imports.

Environment is a data definition with caller-defined properties. Its property
names, suffixes, and target values carry no built-in platform meaning. Environment
roots are never scheduled as commands, even if a property is named Template.

There is no separate process catalog or matching by operation kind. Two FPC
operations can inherit different templates. All selected operations are rendered
before any child in that operation list starts. Declaration order is preserved,
including included roots; module-only roots are not scheduled.

## Template paths and rendering

`Source` identifies tool input; `Template` identifies the Mustache command file.
A relative Template path resolves from the source file supplying its value.
Inherited values retain that origin; scalar aliases/references are followed to
the supplying value. A locally overridden Template uses its own source origin.
For a constructed string, the expression's source file supplies the origin.
Moving a configuration into a module does not make its template path relative to
the importing package.

The template receives the operation's completed properties and `_nx` metadata
directly, without an operation-name wrapper. Arrays, inherited values, references,
and projection limits retain normal NexusScript JSON semantics. Package rendering
supplies resolved dependency output paths. It assigns no special semantics to
operation properties named Output and injects no directory properties. FPC
configurations explicitly supply UnitOutput when their template needs -FU.

```mustache
fpc "{{{Source}}}" "-o{{{Output}}}"{{#Defines}} -d{{{.}}}{{/Defines}}
```

Mustache is the template language. Templates own native quoting and command
construction. Raw interpolation avoids HTML escaping. The executor uses FPC's
`TProcess.CommandLine` parsing and adds no shell. Spaces and `&` in quoted paths
are verified; shell expansion and compound commands are not implicit.

## Execution and failure

The child inherits the developer's environment. Input is closed after launch.
Both output pipes are drained on the console thread; stdout and stderr remain
separate and are collected through exit. There are no worker threads. Captured
output is buffered in memory.

Each invocation records its operation name, resolved template path, command,
working directory, launch state, separate output, exit status, and diagnostic.
CLI output marks unstarted entries. Rendering failure prevents that operation
list from launching; launch failure or nonzero exit stops subsequent operations.
Completed output remains available. Success returns exit status 0; failure 1.

## Verification

```powershell
lazbuild NexusTools\Forge\NexusForge.lpi
lazbuild NexusTools\Forge\tests\NexusForgeTests.lpi
& .\output\NexusForgeTests\x86_64-win64\NexusForgeTests.exe
lazbuild NexusTools\Script\tests\NexusScriptTests.lpi
& .\output\NexusScript\console-tests\x86_64-win64\NexusScriptTests.exe
lazbuild NexusTools\Script\ls\tests\NexusScriptLSTests.lpi
& .\output\NexusScriptLS\console-tests\x86_64-win64\NexusScriptLSTests.exe
```

Verified 2026-09-15: 21 Forge tests, 57 NexusScript compiler tests, and 12
language-server tests passed with zero failures/errors/skips and zero heap leaks.
Tests use the real compiler, validator, renderer, and process paths. Coverage
includes partial bases, required concrete properties, target selection, two FPC
configurations with different templates, nested inheritance, referenced template
paths, local overrides, module/data roots excluded from execution, preflight
failures, independent output streams, working directories, and runner reuse.
Package tests cover artifact presence, dependencies with their own targets,
artifact directory preparation, explicit FPC unit placement, intermediate outputs
outside final artifact directories, and environment-derived artifact filenames.

Native tests compile and run Pascal source and execute Git against a local
repository. The PasBuild comparison builds default/debug/release through the
shared configurations; its application/test templates remain project-specific.
No NexusScript core rules changed. Compiler bootstrap and cross-compilation
remain separate work. Linux suffix selection is tested; Linux native execution
has not been established by these Windows runs.
