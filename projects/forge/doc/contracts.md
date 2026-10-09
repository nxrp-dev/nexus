# NexusForge execution contracts

`nxforge` compiles and validates a Forge document and executes its single task
root. A `Group` runs its child tasks in declaration order and may contain other
Groups. Command tasks render a Mustache `Template` and launch a tool. Render
and filesystem tasks execute within Forge.

## CLI

From the repository root, with working `fpc` and `git` executables on PATH:

```powershell
lazbuild projects\forge\NexusForge.lpi
& .\output\NexusForge\x86_64-win64\nxforge.exe `
  /input=projects\forge\examples\Build.nxscript
```

The example compiles `hello world & test.lpr` and runs local `git status --short`.
Required: `/input=...`. Optional: `/targets=Name:Value,OtherName:OtherValue` and
`/working-directory=...`. There is no `/package` or `/manifest` argument.

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

`projects/forge/language/Forge.nxscript` includes
`projects/forge/language/definitions/*.ForgeDef.nxscript`. Core, FPC,
Git, MSBuild, PowerShell, LazBuild, Npm, InnoSetup, CSV, Render,
FileOperations, Group, and Environment definitions form one
effective Forge language through the included-definition view. The master does
not name individual tools.
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
Group Build {
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
tasks can inherit different templates. All tasks in a Group are prepared before
the first starts, including tasks within nested Groups. Declaration order is
preserved; module-only roots are not scheduled. A runnable document requires
one executable root: a singular task or a Group.

## Source selections and entry points

FPC `Source` is a nonempty list of explicit files or filename masks, for example
`Source: ["src/*.pas", "src/app.lpr"]`. `EntryPoint: "src/app.lpr"` names the
single input passed to FPC. Partial composed configurations can contribute Source
entries without an EntryPoint; a concrete FPC operation requires both.

Forge expands command-operation Source arrays relative to the declaring operation
file. `src/*.pas` selects
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
Each explicit FPC task invokes the compiler; FPC decides whether units need rebuilding.

## Template paths and rendering

`Source` identifies tool input; `Template` identifies the Mustache command file.
A relative Template path resolves from the source file supplying its value.
Inherited values retain that origin; scalar aliases/references are followed to
the supplying value. A locally overridden Template uses its own source origin.
For a constructed string, the expression's source file supplies the origin.
Moving a configuration into a module does not make its template path relative to
the importing task.

The template receives the operation's completed properties and `_nx` metadata
directly, without an operation-name wrapper. Arrays, inherited values, references,
and projection limits retain normal NexusScript JSON semantics. FPC tasks use
their own Template, Output, and UnitOutput properties.

`{{_nx.CompiledAt}}` exposes the entry document's compilation timestamp in
ISO 8601 UTC form, including milliseconds and a trailing `Z`. Operations from
the same compiled document share that timestamp. A Render operation's artifact
template receives the compiled source document's timestamp instead.

```mustache
fpc "{{{EntryPoint}}}" "-o{{{Output}}}"{{#Defines}} -d{{{.}}}{{/Defines}}{{#_nx.SourcePaths}} "-Fu{{{.}}}"{{/_nx.SourcePaths}}
```

Mustache is the template language. Templates own native quoting and command
construction. Raw interpolation avoids HTML escaping. The executor uses FPC's
`TProcess.CommandLine` parsing and adds no shell. Spaces and `&` in quoted paths
are verified; shell expansion and compound commands are not implicit.

## MSBuild compilation

MSBuild is an ordinary native operation. Its required `Template`, `EntryPoint`,
`Configuration`, and `Platform` render a solution or project build. `EntryPoint`
resolves from the declaring document to an absolute path. `Executable` defaults to `MSBuild` in
the example template. Optional `BuildTarget` and text-array `Properties` render
as `/t:` and `/p:` arguments. The template lives at
`projects/forge/examples/MSBuild.mustache`. For Nexus2D, the operation values
are `platform/windows/Corona.Simulator.sln`, `Release`, and `x64` when declared
from the Nexus2D root. Dependency preparation and output staging are separate
work; this operation alone is not a complete simulator build recipe.

PowerShell is also a native operation. Its required `EntryPoint` names a script
file and is resolved to an absolute path. The example template invokes
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File`; optional `Executable`
and text-array `Arguments` supply an alternate host or script arguments.
`Nexus2D.Win64.Forge.nxscript` in the sibling Nexus2D checkout uses it to
prepare x64 dependencies before its MSBuild operation. That script names the
currently installed tools and assumes the sibling `nexus` and `tools` folders.
It does not isolate Nexus2D's shared Win32/x64 `Bin/Corona` output directory.

LazBuild, Npm, and InnoSetup are command operations with ForgeDef contracts and
Mustache examples in `projects/forge/examples/`. `LazBuild.EntryPoint` names the
project file; `Npm.Command` is a command such as `ci`, `install`, or `run`, with
additional tokens in `Arguments`; `InnoSetup.EntryPoint` names the `.iss` file.
InnoSetup `Defines` and `Arguments` are text arrays, not semicolon-separated
strings. LazBuild and InnoSetup require an explicit `Quiet` Boolean, so there
is no hidden default when moving a Task recipe to Forge. Their optional
`Executable` values override the example templates' `lazbuild`, `npm.cmd`, and
`ISCC.exe` defaults. Set `Executable` for another host or install location.

Each of these operations may specify `WorkingDirectory`, resolved from the
Forge document directory. When
omitted, the usual Forge operation directory applies. In particular, a
LazBuild recipe that needs the project directory as its process directory
must state it. Boolean options validated by the Forge dialect are converted
to JSON booleans in the command-render context, so Mustache sections distinguish
`False` from `True` without changing the NexusScript JSON emitter.

## CSV compilation

CSV is an ordinary native operation. Import
`projects/csv/config/CSV.nxscript`, compose CompileCSV, and provide Source,
SourceTemplate, and Output. Its Template builds the command; SourceTemplate is
passed to nxcsv for artifact rendering. Optional Compiler, Name, and Delimiter
values remain explicit tool arguments. Forge contains no CSV loader or SQL logic.
See [NexusCSV](../../csv/README.md) for the tool contract and tests.

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
directory. Standalone Render does not invent output directories; callers create
them when needed.
This Output meaning belongs to Render, not to arbitrary operation properties.

All operations prepare before any executes. Source compilation/validation or
missing-template failures therefore launch no commands and write no artifacts.
Execution writes the rendered bytes without trimming, including an empty file.
Write failure stops subsequent operations. An invocation records SourcePath,
OutputPath, Started, and Completed; it does not fabricate a process exit status.
Native and Render operations can occur in the same ordered list.

See [the BotHost database example](../../../projects/bothost/doc/database-generation.md) for a
target-selected Environment. It renders Firebird SQL with no database
semantics in Forge and no separate NexusScript executable.

## Filesystem operations

`WriteTextFile`, `CopyFile`, `DeletePath`, and `Archive` execute in Forge without
Mustache or an external shell. Relative paths resolve from the operation working
directory. They use the same prepare-before-execute ordering and stop-on-failure
behavior as Render; later operations may consume files created by earlier ones.

`WriteTextFile` requires `Path` and `Text`. It creates parent directories and
writes text with LF line endings, matching Task's text-file action.

`CopyFile` requires `Source` and `Destination`. `Overwrite`, `Recursive`, and
`CleanDestination` default to false. A directory source requires `Recursive`;
`CleanDestination` removes an existing destination directory before copying.
`ExcludeNames` is an optional semicolon-separated, case-insensitive list of
exact file or directory names skipped during recursive copying.

`DeletePath` requires `Path`. `Recursive` defaults to false and `MissingOk`
defaults to true. A wildcard in the final path component matches files, not
directories; `Recursive` also searches subdirectories. A literal directory
requires `Recursive` unless empty.

`Archive` requires `Operation` (`Zip` or `Unzip`), `Source`, and `Destination`.
`Overwrite` defaults to false and `Recursive` defaults to true. Zip accepts a
file or directory source and uses the same `ExcludeNames` convention as CopyFile.
Unzip refuses entries outside its destination directory.

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
lazbuild projects\forge\NexusForge.lpi
lazbuild projects\csv\NexusCSV.lpi
lazbuild projects\forge\test\NexusForgeTests.lpi
& .\output\NexusForgeTests\x86_64-win64\NexusForgeTests.exe
lazbuild packages\nexus-packages\nxscript\test\NexusScriptTests.lpi
& .\output\NexusScript\console-tests\x86_64-win64\NexusScriptTests.exe
lazbuild projects\ls\nxscript\tests\NexusScriptLSTests.lpi
& .\output\NexusScriptLS\console-tests\x86_64-win64\NexusScriptLSTests.exe
```

The Forge tests compile and execute real Pascal source and exercise NexusScript
validation, target selection, Group ordering, built-in file tasks,
and command failure reporting. Compiler bootstrap
and cross-compilation are separate work.
