# NexusForge execution contracts

`nxforge` compiles and validates a Forge document, renders each concrete
operation's `Template` with Mustache, and executes operations sequentially.
FPC and Git use the native command path; Render writes a generated artifact.

## CLI

From the repository root, with working `fpc` and `git` executables on PATH:

```powershell
lazbuild NexusTools\Forge\NexusForge.lpi
& .\output\NexusForge\x86_64-win64\nxforge.exe `
  /input=NexusLib\script\examples\forge\Build.nxscript
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
Git, CSV, Render, Package, and Environment definitions form one effective Forge language
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
    Source: ["app.lpr"];
    EntryPoint: "app.lpr";
    Output: "app" + @Platform.ExecutableSuffix;
}
FPC Test (CompileTests) {
    Source: ["tests.lpr"];
    EntryPoint: "tests.lpr";
    Output: "tests" + @Platform.ExecutableSuffix;
}
```

Select TargetOS explicitly for this example. The completed concrete operations
must satisfy the FPC contract, including Template, Source, EntryPoint, and Output. Imported
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

## Source selections and entry points

FPC `Source` is a nonempty list of explicit files or filename masks, for example
`Source: ["src/*.pas", "src/app.lpr"]`. `EntryPoint: "src/app.lpr"` names the
single input passed to FPC. Partial composed configurations can contribute Source
entries without an EntryPoint; a concrete FPC operation requires both.

Forge expands command-operation Source arrays relative to the declaring package
root (or the declaring operation file outside a package). `src/*.pas` selects
that directory only; `src/**/*.pas` explicitly includes subdirectories. There is
no extension inference. Missing directories or selections matching no files fail
preparation before commands launch. Entries retain selection order, matches are
sorted, and duplicate files and directories are removed.

The command render context receives absolute file names in `Source`, unique
containing directories in `_nx.SourcePaths`, and an absolute `EntryPoint`.
Templates translate those directories to switches such as `-Fu`. This does not
change the compiled NexusScript document. Scalar Source values for CSV and Render
retain their existing contracts. A Source list does not create multiple commands.

FPC searches these directories for dependencies and decides whether compiled units
are usable. The selected files establish search directories, not a restriction on
which other dependencies FPC may load from those directories. Forge does not hash
sources, generate bootstrap programs, or compile every selected unit independently.
An operation with EntryPoint causes its package to execute on each new request;
within a request graph, an already obtained variant is still shared.

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

`{{_nx.CompiledAt}}` exposes the entry document's compilation timestamp in
ISO 8601 UTC form, including milliseconds and a trailing `Z`. Operations from
the same compiled package share that timestamp. A Render operation's artifact
template receives the compiled source document's timestamp instead. This
metadata does not participate in package artifact-presence or reuse checks.

```mustache
fpc "{{{EntryPoint}}}" "-o{{{Output}}}"{{#Defines}} -d{{{.}}}{{/Defines}}{{#_nx.SourcePaths}} "-Fu{{{.}}}"{{/_nx.SourcePaths}}
```

Mustache is the template language. Templates own native quoting and command
construction. Raw interpolation avoids HTML escaping. The executor uses FPC's
`TProcess.CommandLine` parsing and adds no shell. Spaces and `&` in quoted paths
are verified; shell expansion and compound commands are not implicit.

## CSV compilation

CSV is an ordinary native operation. Import
`NexusLib/script/tools/CSV/CSV.nxscript`, compose CompileCSV, and provide Source,
SourceTemplate, and Output. Its Template builds the command; SourceTemplate is
passed to nxcsv for artifact rendering. Optional Compiler, Name, and Delimiter
values remain explicit tool arguments. Forge contains no CSV loader or SQL logic.
See [NexusCSV](../../CSV/README.md) for the tool contract and tests.

## Render artifacts

Render declares required Source, Output, and Template text values and an optional
explicit Environment definition reference. Its Template generates artifact content.
The source declares its own dialect; Forge compiles and validates it in-process
with the current target selection. The template receives the source's generic
JSON, including the combined included-definition collections. An explicit
Environment is added at `Environment`; a source root with that name is rejected
when the operation supplies this context. This operation renders model definitions;
it does not import external seed-data rows.

Relative Source and Template retain the origin of the supplying value, including
module references and composition. Output resolves from the operation working
directory (the package root for package operations). Package coordination prepares
declared artifact parents. Standalone Render does not invent output directories.
This Output meaning belongs to Render, not to arbitrary operation properties.

All operations prepare before any executes. Source compilation/validation or
missing-template failures therefore launch no commands and write no artifacts.
Execution writes the rendered bytes without trimming, including an empty file.
Write failure stops subsequent operations. An invocation records SourcePath,
OutputPath, Started, and Completed; it does not fabricate a process exit status.
Native and Render operations can occur in the same ordered list.

See [the BotHost database example](../../../NexusLib/script/bothost/database/README.md) for a complete
package and target-selected Environment. It renders Firebird SQL with no database
semantics in Forge and no separate NexusScript executable.

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
lazbuild NexusTools\CSV\NexusCSV.lpi
lazbuild NexusTools\Forge\tests\NexusForgeTests.lpi
& .\output\NexusForgeTests\x86_64-win64\NexusForgeTests.exe
lazbuild NexusLib\packages\nxscript\test\NexusScriptTests.lpi
& .\output\NexusScript\console-tests\x86_64-win64\NexusScriptTests.exe
lazbuild NexusTools\Script\ls\tests\NexusScriptLSTests.lpi
& .\output\NexusScriptLS\console-tests\x86_64-win64\NexusScriptLSTests.exe
```

Source/EntryPoint verification: 30 Forge tests and 61 NexusScript compiler tests
passed with zero failures/errors/skips and zero heap leaks. The shared FCL example
also builds and runs. Language-server code and the shared compiler are unchanged;
the earlier 12-test language-server result is not a new run for this correction.
Tests use the real compiler, validator, renderer, and process paths. Coverage
includes partial bases, required concrete properties, target selection, two FPC
configurations with different templates, nested inheritance, referenced template
paths, local overrides, module/data roots excluded from execution, preflight
failures, independent output streams, working directories, and runner reuse.
Package tests cover artifact presence, dependencies with their own targets,
artifact directory preparation, source-selection composition and expansion,
unchanged-unit reuse and changed-unit rebuilding, explicit FPC unit placement, intermediate outputs
outside final artifact directories, and environment-derived artifact filenames.

Native tests compile and run Pascal source and execute Git against a local
repository. The PasBuild comparison builds default/debug/release through the
shared configurations; its application/test templates remain project-specific.
The selective-import dependency fix preserves private external bindings while
retaining internal composition rebinding; the compiler regressions cover ownership
after producer destruction and same-name consumer capture. Compiler bootstrap and cross-compilation
remain separate work. Linux suffix selection is tested; Linux native execution
has not been established by these Windows runs.
