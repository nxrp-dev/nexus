# NexusForge execution contracts

`nxforge` compiles and validates a Forge document and executes its single task
root. `Group`, `Package`, and `Project` run their children in declaration order.
Command tasks render a Mustache `Template` and launch a tool. Render
and filesystem tasks execute within Forge.

## Package and Project contracts

`Package` and `Project` use the same ordered execution as `Group`, including
nesting, composition, target selection, preparation, and failure propagation.
A compiler invocation is always an explicit `FPC` child. A Package containing
no build operations is valid and performs no compilation.

| Contract | Group | Package | Project |
| --- | --- | --- | --- |
| Ordered build children | Yes | Yes | Yes |
| Required nonblank `Id` | No | Yes | Yes |
| `Version`, `Author`, `Description`, `License` | No | Optional | Optional |
| `Requires` catalog references | No | Optional | Optional |
| `Outputs` text array | No | Optional | Optional |
| `UnitPaths`, `IncludePaths`, `LibraryPaths` text arrays | No | Optional | Rejected |

The shared definitions and semantic validator are owned by `nxpackage`. Forge
extends the definitions with executable children. The package editor and Forge
use the same read-only contract checks. Neither follows descriptor locations,
fetches dependencies, selects versions, or builds `Requires` entries implicitly.
Each nonempty Requires list names records in the single index imported by its
supplying document, including requirements inherited through composition.

`CompileForgeDocument` compiles and validates metadata without preparing tools
or reading generated outputs. `TNXPackageDocument` can inspect the same Forge
descriptor without executing it. A declared output is a contract, not a freshness
cache or an implicit existence test. Add explicit validation children when build
success depends on verifying outputs. Failure of a final validation fails the
whole build and prevents every following child from starting; completed work
is retained. Contracts do not imply rollback.

```nexusscript
module Library "library/Package.nxscript";
Project Application {
    Id: "NXRP.Application";
    Outputs: [Binary: "bin/application.exe"];
    Package BuildLibrary (Library) {}
    FPC Compile {
        Template: "FPC.mustache";
        Source: ["src/application.pas"];
        EntryPoint: "src/application.pas";
        UnitPaths: @Library.UnitPaths;
        IncludePaths: @Library.IncludePaths;
        Output: @Application.Outputs.Binary;
    }
    Run Check {
        Template: "Run.mustache";
        Executable: @Application.Outputs.Binary;
    }
}
```

Importing a package makes its contract available; the explicit composed child
schedules its build. Contract references use ordinary NexusScript `@` syntax.
No new interpolation or placeholder syntax is involved. A language-level FPC
runtime package remains an artifact compiled by FPC, distinct from this build
contract and its operations.

Paths supplied by direct references retain the file where their value originated.
This applies to filesystem-operation paths and command `Output`, `UnitOutput`,
`CompilerUtilitiesPath`, `UnitPaths`, `IncludePaths`, `LibraryPaths`, `ObjectPaths`,
and `Objects`. A reference to an entire path array and references to individual
entries both preserve origin. Command Source arrays and EntryPoint always retain
the origin of their supplying values, including composition. Templates and tool
paths retain their existing origin semantics. A referenced Executable or Compiler
is a file path even when its text is only a filename; a literal bare tool name
continues to use PATH.

Literal output/search paths remain relative to the operation working directory.
By default that is the operation's declaring file, including children imported
from a package. The CLI working-directory override supplies a common base for
all operations. An operation's explicit WorkingDirectory then overrides that
base. Text expressions construct a new value at the expression's source location;
use direct references when an exported path must retain its original base.
None of this rewrites the compiled metadata or the NexusScript JSON emitter.

`Run` is an ordinary command operation with required `Template` and `Executable`,
optional text-array `Arguments`, and optional `WorkingDirectory`. The supplied
`Run.mustache` quotes the executable and each argument. It supports generated
tools and test programs without adding special process behavior to Forge.

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
Git, NXBuild, MSBuild, PowerShell, LazBuild, Npm, InnoSetup, CSV, Msg2Inc, Render,
FileOperations, BuildIdentity, Group, and Environment definitions form one
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
must satisfy the FPC contract, including Template, Source, and EntryPoint. Imported
partial bases need not independently supply every required operation property.
They remain module definitions, not additional commands. Existing module root
selectors can limit which definitions a consumer imports.

Environment is a data definition with caller-defined properties. Its property
names, suffixes, and target values carry no built-in platform meaning. Environment
roots are never scheduled as commands, even if a property is named Template.

There is no separate process catalog or matching by operation kind. Two FPC
tasks can inherit different templates. All tasks in a Group, Package, or Project are prepared before
the first starts, including tasks within nested Groups. Declaration order is
preserved; module-only roots are not scheduled. A runnable document requires
one executable root: a singular task, Group, Package, or Project.

## Source selections and entry points

FPC `Source` is a nonempty list of explicit files or filename masks, for example
`Source: ["src/*.pas", "src/app.lpr"]`. `EntryPoint: "src/app.lpr"` names the
single input passed to FPC. Partial composed configurations can contribute Source
entries without an EntryPoint; a concrete FPC operation requires both.

Forge expands command-operation Source arrays relative to the declaring operation
file. `src/*.pas` selects
that directory only; `src/**/*.pas` explicitly includes subdirectories. There is
no extension inference. Source arrays are expanded immediately before their
command runs, after preceding tasks have completed. This allows files copied or
generated by earlier tasks to be selected in the same run. Missing directories
or selections matching no files stop that task before launch and prevent later
tasks from running; earlier completed tasks are retained. Entries retain selection
order, matches are sorted, and duplicate files and directories are removed.

The command render context receives absolute file names in `Source`, unique
containing directories in `_nx.SourcePaths`, and an absolute `EntryPoint`.
Templates translate those directories to switches such as `-Fu`. Schema validation
and loading/parsing all command templates still happen before any task runs.
For source-array commands, the normalized context and template text are retained
until source expansion and final command rendering at execution time. This does
not change the compiled NexusScript document. Scalar Source values for CSV and Render
retain their existing contracts. A Source list does not create multiple commands.

FPC searches these directories for dependencies and decides whether compiled units
are usable. The selected files establish search directories, not a restriction on
which other dependencies FPC may load from those directories. Forge does not hash
sources, generate bootstrap programs, or compile every selected unit independently.
Each explicit FPC task invokes the compiler; FPC decides whether units need rebuilding.

The FPC definition and `examples/FPC.mustache` support these optional settings:

| Property | Value | Compiler switch |
| --- | --- | --- |
| `Mode` | Text | Emits `-M<mode>` |
| `Rebuild` | Boolean | `True` emits `-B` |
| `ObjectPaths` | Text array | Emits `-Fo<path>` for each path |
| `LibraryPaths` | Text array | Emits `-Fl<path>` for each path |
| `LinkerOptions` | Text array | Emits `-k<option>` for each option |
| `DisableDefaultConfigFiles` | Boolean | `True` emits `-n` |
| `CompileSystemUnit` | Boolean | `True` emits `-Us` |
| `LabelAndGoto` | Boolean | `True` emits `-Sg` |
| `OptimizationLevel` | Integer, 1 through 4 | Emits `-O1` through `-O4` |
| `GenerateReleaseUnitFiles` | Boolean | `True` emits `-Ur` |
| `StripSymbols` | Boolean | `True` emits `-Xs` |
| `ResponseFiles` | Text array | Emits `@<file>` for each compiler options file |
| `TargetOS` | Text | Emits `-T<value>`, e.g. `-Tlinux` |
| `Assembler` | Text | Emits `-A<value>`, e.g. `-Aas-clang` |
| `UseLLD` | Boolean | `True` emits `-XLL` |
| `PositionIndependentCode` | Boolean | `True` emits `-Cg` |
| `CompilerUtilitiesPath` | Text | Emits quoted `-FD<path>` |
| `WorkingDirectory` | Text | Sets the compiler process directory using ordinary Forge path rules |
| `ExecutableOutput` | Text | Emits quoted `-FE<path>` |
| `PackageSDKIdentity` / `PackageBuildIdentity` | Text | Emit `-Fj` / `-Fk` identities before response files |
| `EmbedPackageMetadata` | Enabled / Disabled | Emit `-FJEnabled` / `-FJDisabled`; omission keeps the compiler default (embedded) |
| `PackagePaths` | Text array | Emits `-Fp` for each package directory |
| `RequiredPackages` | Text array | Emits `-FP` after package search paths |
| `SmartLinkUnits` / `SmartLink` | Boolean | Emit `-CX` / `-XX` |
| `ConsoleApplication` / `GUIApplication` | Boolean | Emit `-WC` / `-WG`; choose one subsystem |

Omitted properties and `False` Boolean values emit no switch. `-Ur` prevents
automatic recompilation of the generated release units. These switches are
rendered by Mustache; the executor has no FPC-specific option handling.
FPC does not accept an unrestricted `Arguments` property. `Output` is optional:
the template emits `-o` only for a supplied, nonempty value. Without it, FPC
uses its normal output naming. Unit compilation can specify `UnitOutput`
(`-FU`) without naming an executable output. Output directories must already
exist when the compiler starts. `UnitPaths` and `IncludePaths` emit quoted
`-Fu` and `-Fi` switches respectively; relative paths use the operation's
working directory. Explicit unit paths follow the directories selected by `Source`.
`CompilerUtilitiesPath` follows the same working-directory rule. Target-filtered
configurations can supply these named settings while sharing one FPC template.

`ResponseFiles` entries are passed to the compiler verbatim; relative paths use
the operation's working directory. An earlier child may generate an options
file. The compiler reads it when the FPC child runs. This is FPC's existing
response-file interface, not NexusScript syntax.

An explicit relative `Compiler` path containing a slash or backslash resolves
from the document supplying that property, including inherited or referenced
values, just like `Executable`. Absolute paths and bare tool names retain their
existing meaning. The compiler need not exist during preparation; an earlier
task can build or copy it before invocation. This path normalization supplies the
Mustache context and does not construct compiler commands.

## FPC message generation

`Msg2Inc` runs FPC's existing message generator through `examples/Msg2Inc.mustache`.
It requires `Template`, `Source` (one message-file path), `OutputPrefix`, and
`ConstantName`. Optional `Executable` defaults to `msg2inc` on PATH. An explicit
relative executable path resolves from its declaring document, like other
command tools. Relative source and output paths use the operation working
directory.

The template passes the three named operands in that order, with each quoted.
The utility's default string-table mode writes `OutputPrefix + "idx.inc"` and
`OutputPrefix + "txt.inc"`; `ConstantName` supplies the base name for its text
constants. For compiler messages, use an output prefix ending in `msg` and
`ConstantName: msg`. Create the output directory before running the operation.
The executable may be produced by an earlier FPC task in the same Group.
No unrestricted `Arguments` property or tool-specific executor code is used.

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
fpc "{{{EntryPoint}}}"{{#Output}} "-o{{{Output}}}"{{/Output}}{{#Defines}} -d{{{.}}}{{/Defines}}{{#_nx.SourcePaths}} "-Fu{{{.}}}"{{/_nx.SourcePaths}}
```

Mustache is the template language. Templates own native quoting and command
construction. Raw interpolation avoids HTML escaping. The executor uses FPC's
`TProcess.CommandLine` parsing and adds no shell. Spaces and `&` in quoted paths
are verified; shell expansion and compound commands are not implicit.

An explicit relative `Executable` containing `/` or `\` resolves from the source
file supplying that property, including inherited values and scalar references.
Absolute executable paths are unchanged. Bare names such as `nxbuild` or
`nxbuild.exe` remain unchanged for PATH lookup. The child working directory does
not change this resolution. This applies to all command operations.

## Nexus project compilation

`NXBuild` is an ordinary command operation that invokes
`nxbuild /action=build /project=...`. Its required `Template` and `EntryPoint`
identify the command template and `.nxproject` file. `EntryPoint` resolves from
the declaring document to an absolute path, and the example template quotes the
entire `/project` argument. Optional `Executable` defaults to `nxbuild` on PATH;
optional `WorkingDirectory` follows the normal command-operation contract.

The template is `projects/forge/examples/NXBuild.mustache`. The project owns its
compiler selection, search paths, compiler options, and output locations. Forge
does not parse `.nxproject` files or copy their settings into Forge operations.
nxbuild remains independent of Forge.

`projects/forge/test/fixtures/NXBuild.Forge.nxscript` builds
`NexusForgeTests.nxproject` with the sibling NexusFPC toolchain, without LazBuild.
`projects/forge/NexusForge.nxproject` builds the updated CLI into
`output/NexusForge-next/x86_64-win64/nxforge.exe`, leaving the existing runner intact.

## LLVM C and C++ compilation

`Clang` and `LLVMAr` are ordinary command operations with definition contracts
and Mustache templates; the Forge executor contains no LLVM-specific behavior.

`Clang` requires `Template`, a nonempty `Source` array, and an explicit
`CompileOnly` Boolean. The example template defaults to `clang` on PATH. Set
`Executable` to `clang++` for a C++ driver. `CompileOnly: True` emits `-c`.
Omit `Output` to compile a source collection in one invocation: Clang writes
one object per source into `WorkingDirectory`, using each source's base name.
Create that directory before the compilation and select sources with distinct
base names. Source selections retain their declaring file's directory.
Supply `Output` to name a single object or linked binary; the template emits
`-o` only when it is present. `CompileOnly: False` compiles and links.
`Target`, `Standard`, `IncludePaths`, and `Defines` render native Clang switches.
`SystemIncludePaths` renders ordered `-isystem` paths; referenced paths retain
their declaration origin. `OptimizationLevel` accepts 0 through 3 and emits
`-O<level>`. `DisableStackProtector: True` emits `-fno-stack-protector`.
Optional `SourceLanguage` emits `-x <language>`; use `assembler` for assembly
inputs whose extension does not identify their language. `AssemblerSymbols`
is an optional text array of `name=value` entries, each rendered as
`-Wa,-defsym,name=value` for the assembler. These properties allow assembly
tasks to share the Clang template with C and C++ tasks.
`Arguments` supplies additional literal arguments, including linker selection
and libraries. No shell is involved. Source selections use the normal expansion
contract; output and other argument paths are interpreted in `WorkingDirectory`.

`LLVMAr` requires `Template`, `Operation`, `Output`, and a nonempty `Objects`
text array. The example template defaults to `llvm-ar`; `Operation: "rcs"`
creates or updates an indexed static archive. Optional `Arguments` supplies
native archiver options. Objects are explicit input arguments, not Source masks:
they may be generated by earlier tasks in the same Group. Neither this operation
nor Clang implicitly creates output directories or cleans existing artifacts.

`examples/AbbreviaLLVM.Forge.nxscript` builds the seven C sources from Abbrevia's
bundled bzip2 into Win64 objects and a COFF static library, then compiles a C++17
compression/decompression fixture with Clang++ and LLD. It writes only new
`output/AbbreviaLLVM-*` artifacts and does not modify the upstream source or
its prebuilt binaries. The example assumes the repository output directory,
the installed LLVM tools under `C:/Program Files/LLVM/bin`, and the existing
Windows SDK/CRT headers and libraries. The recipe explicitly names SDK
`10.0.19041.0` and CRT `14.29.30133` include and Win64 library paths; it does
not require a Visual Studio command shell. Adjust these paths for other
installations. It does not invoke MSBuild or `cl.exe`.
The final Run child verifies the C/C++ round trip. The canonical Abbrevia
`Package.nxscript` separately builds all 37 codec sources with one Clang child,
followed by an explicit FPC runtime build and its startup check. Its ordered
children prepare files directly; no PowerShell builder is involved.

```powershell
output/NexusForge-next/x86_64-win64/nxforge.exe /input=projects/forge/examples/AbbreviaLLVM.Forge.nxscript
```

Native tool contracts: [Clang](https://clang.llvm.org/docs/UsersManual.html),
[llvm-ar](https://llvm.org/docs/CommandGuide/llvm-ar.html).

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

## Build identity

`BuildIdentity` is a native file operation with required `Repository` and
`OutputDirectory` paths. It can run at the root or inside Group, Package, or
Project. Literal paths use the operation working directory; referenced paths
retain their declaring source origin. No Template is required.

```nxscript
BuildIdentity CaptureBuildIdentity {
    Repository: ".";
    OutputDirectory: "build/forge-bootstrap/seed";
}
```

The operation runs after preceding children. It requires
`OutputDirectory/source/version.pas`, reads Git HEAD and tracked/untracked
non-ignored dirty state, and chooses the UTC timestamp from `SOURCE_DATE_EPOCH`
or the captured commit. Git must be on PATH. Epoch values must be decimal
non-negative seconds no later than 9999-12-31 23:59:59 UTC. Invalid source,
Git, or timestamp inputs fail before output files are changed.

It writes `source/revision.inc`, `build-options.cfg` (`-DD` and `-DT`), and
`build-identity.json` beneath OutputDirectory. The JSON fields are Revision,
Dirty, Identity, Date, Time, and SourceDateEpoch. Text is UTF-8 without a BOM,
with LF endings; Date and Time use fixed `yyyy/MM/dd` and `HH:mm:ss` UTC formats.
Identity is the full revision with an optional `-dirty` suffix; it does not hash
uncommitted changes. Later bootstrap and cross tasks reuse the captured files.

This bounded operation intentionally owns the current FPC output formats in
`utNXForgeBuildIdentity.pas`. It uses the existing process runner for Git and
the ordinary native-operation dispatch for file generation. It adds no shell,
runtime reference evaluation, or Render lifecycle change. File-write failures
stop subsequent children and can leave earlier files written, as with the other
ordered file operations.

## Filesystem operations

`CreateDirectory`, `WriteTextFile`, `CopyFile`, `CompareFiles`, `DeletePath`, and `Archive` execute
in Forge without Mustache or an external shell. Relative paths resolve from the
operation working directory. They use the same prepare-before-execute ordering
and stop-on-failure behavior as Render; later operations may consume files
created by earlier ones.

`CreateDirectory` requires `Path`. It creates the directory and any missing
parents. An existing directory succeeds without changing its contents. A file
at the destination or in a required parent path, or any other creation failure,
reports an error and stops later operations.

```text
CreateDirectory SeedBin {
    Path: "build/forge-bootstrap/seed/bin";
}
```

`WriteTextFile` requires `Path` and `Text`. It creates parent directories and
writes text with LF line endings, matching Task's text-file action.

`CopyFile` requires `Source` and `Destination`. `Overwrite`, `Recursive`, and
`CleanDestination` default to false. A directory source requires `Recursive`;
`CleanDestination` removes an existing destination directory before copying.
`ExcludeNames` is an optional semicolon-separated, case-insensitive list of
exact file or directory names skipped during recursive copying.

`IncludeMasks` optionally limits copied files to a nonempty array of filename
masks, for example `["*.pas", "*.inc"]`. Each file's basename must match
at least one mask; overlapping masks copy the file only once. `*` matches zero
or more characters and `?` matches one. Matching is case-insensitive on Windows
and case-sensitive elsewhere. Masks cannot be empty or contain path separators
or drive prefixes. Directories are traversed regardless of these masks, and
`ExcludeNames` still skips matching files or whole subdirectories. The filter
also applies to a single-file source. No matches succeeds without copying files;
recursive copying can still create empty directories. Omitting `IncludeMasks`
copies all files as before. `CleanDestination` still clears the entire destination
directory before the filtered copy.

`CompareFiles` requires nonempty `Left` and `Right` file paths. It compares all
bytes using fixed-size buffers and succeeds only when lengths and contents match.
Two empty files compare equal. Files are opened when the operation executes, so
earlier tasks can produce them. Comparison does not change either file or create
output. Missing files, directories, open/read errors, and differences stop later
tasks. Diagnostics identify both resolved paths; differences report the first
unequal byte offset, counted from zero. If one file is an identical prefix of the
other, the offset is the shorter file's length. There are no ignored byte ranges
or file-format-specific rules.

```text
CompareFiles VerifyBootstrap {
    Left: "build/forge-bootstrap/cycle2/ppcx64.exe";
    Right: "build/forge-bootstrap/cycle3/ppcx64.exe";
}
```

`DeletePath` requires `Path`. `Recursive` defaults to false and `MissingOk`
defaults to true. A wildcard in the final path component matches files, not
directories; `Recursive` also searches subdirectories. A literal directory
requires `Recursive` unless empty.

`Archive` requires `Operation` (`Zip` or `Unzip`), `Source`, and `Destination`.
`Overwrite` defaults to false and `Recursive` defaults to true. Zip accepts a
file or directory source and uses the same `ExcludeNames` convention as CopyFile.
Unzip refuses entries outside its destination directory.

### Package SDK metadata

`PackageSDKOptions` and `PackageSDKManifest` are native file operations allowed
at the root or inside Group, Package and Project. They currently own the standard
NexusFPC Win64 SDK layout and formats; they do not compile or stage files.

```text
PackageSDKOptions Identity {
    BootstrapDirectory: "build/forge-bootstrap";
    OutputDirectory: "build/forge-bootstrap/package-sdk";
}
// Compile and copy the foundation and startup artifacts here.
PackageSDKManifest Manifest {
    Directory: "build/forge-bootstrap/package-sdk";
}
```

The required paths must be nonempty and use the ordinary Forge path rules.
Inputs are opened at execution time so previous children can produce them.
`PackageSDKOptions` hashes `bin/ppcx64.exe`, the fixed standard release settings,
the recursively sorted files in `work/rtl-units` and the bootstrap's `seed/rtl`,
and `seed/build-options.cfg`. SHA-256 uses the existing FPC `fpsha256` unit.
Paths within the fingerprint use `/` and sorting is case-sensitive, independent
of the checkout's absolute location. A new GUID identifies each foundation build.
It writes UTF-8/no-BOM, LF-terminated `work/identity.json`, `work/foundation.cfg`
and `work/startup.cfg`. The startup response file places package search before
`-FPnxrtl`. All input hashing completes before writing; filesystem write failures
can leave partial output, as with the other file operations.

`PackageSDKManifest` checks `work/identity.json` against the compressed compiler
metadata and Win64 ABI-4 descriptor in `packages/nxrtl.nxpl`. A package compiled
with embedding disabled instead uses its fingerprint-bound `.nxp` sidecar. The image is read
as bytes, never loaded or executed. Invalid/truncated structures, unsupported
formats, identity mismatches and compiler-query failures stop subsequent tasks
without rewriting an existing manifest. After validation it queries the staged
compiler with `-iV`, hashes the compiler and direct files in `units` and `packages`,
and writes `sdk.json` Format 2 with relative artifact paths and SHA-256 hashes.

### Package consumer builds

`PackageBuildPrepare` and `PackageBundlePublish` are native file operations at
the root or inside Group, Package and Project. `examples/PackageBuild.nxscript`
composes explicit work-directory cleanup, preparation, ordinary FPC compilation
and publication in that order. The Win64 SDK ships this group and `FPC.mustache`
under `forge/`. Consumers need Forge and its language definitions installed.

```text
PackageBuildPrepare Prepare {
    SDKDirectory: "sdk";
    WorkDirectory: "build/package-work";
    PackageDirectories: ["providers"];
}
// Compile into the prepared work directory, using its package.cfg response file.
PackageBundlePublish Publish {
    WorkDirectory: "build/package-work";
    OutputDirectory: "distribution";
    Name: "mypackage";
    Kind: Package;
}
```

Preparation verifies Format 2 Win64 or x86-64 glibc Linux SDK artifact hashes, resolves each
provider's selected generation, and checks NXP004/ABI-4 PCP/image pairs and exact
dependency build identities. It requires an empty work directory and writes
`package.cfg` plus `package-build.json` containing a fresh build identity and
the hashes of the selected package inputs. `PackageDirectories` is optional;
the SDK foundation is always included. Compilation remains an FPC child.

Publication requires `Kind: Package`, `Console` or `GUI`. It rejects changed
inputs, mismatched output identities, missing pairs and incompatible dependency
builds. Packages publish PCP/image pairs; applications publish their executable and the
supplied shared-library closure. Each completed `generation-<id>` has a hash manifest;
`current.json` changes atomically only after copying and validation succeed.
An I/O failure can leave an unselected generation. Existing generations remain
until explicitly removed. Builds and publication are sequential.

Provider directories may be raw PCP/image directories or published distributions.
When present, their manifests are enforced, including rejection of unlisted
artifacts. These operations do not acquire packages or select versions.
Rebuilding a provider already consumed within a bundle requires rebuilding its
dependent distribution in a new output directory.

When composing the supplied group, explicitly derive replaced children from
`PackageBuild.Prepare`, `PackageBuild.Compile`, and `PackageBuild.Publish` to
retain their inherited settings. Supply absolute SDK/work paths: the group
combines them into compiler and response-file paths before changing the compiler
working directory. Relative literal FPC paths use that work directory.
See the NexusFPC SDK guide for a complete example.

Linux consumers compose `LinuxPackageBuild` for providers and
`LinuxPackageApplication` for executables. These derive from the same ordered
group; platform linker settings remain in the recipes. Application composition
adds nxrtl and PIE/no-COPY/no-text-relocation/RELRO/eager-binding options to the
shared PIC and `$ORIGIN` settings. Existing array composition appends entries.
Preparation records the SDK target and writes resolved rpath-link directories
to its response file. Publication preserves executable permissions on Unix.

The native ELF reader supports little-endian x86-64 ELF64 and ABI 4. It reads
section, symbol and RELA tables, resolving local descriptor pointers without
loading code. It verifies package identities, descriptor dependency build IDs
against PCP declarations, and application dependencies against the supplied
providers. Truncated structures, invalid table links/indexes and external
descriptor pointers are rejected. Linux SDK construction remains a separate,
deferred task. Existing Linux Format 2 SDK manifests use their original lowercase
keys; new publication manifests use the common Format/Files/Generation structure.

This is a temporary migration of existing SDK policy into native operations.
The platform layouts, identities, validation and generation publication remain
SDK-specific responsibilities in Forge pending the owner's architectural review.
The source-tree PowerShell compile entry point only creates the composed Forge
document and captures its log for existing example/test callers; it is not
distributed in the SDK.

## Execution and failure

The child inherits the developer's environment. Input is closed after launch.
Both output pipes are drained on the console thread; stdout and stderr remain
separate and are collected through exit. There are no worker threads. Captured
output is buffered in memory.

Each invocation records its operation name, resolved template path, command,
working directory, launch state, separate output, exit status, and diagnostic.
CLI output marks unstarted entries. Schema and template-preparation failures
prevent that operation list from launching. Source-selection or final rendering
failure at execution time, launch failure, or nonzero exit stops subsequent operations.
Completed output remains available. Success returns exit status 0; failure 1.

## Verification

```powershell
& .\output\nxbuild-next\x86_64-win64\nxbuild.exe /action=build /project=projects/forge/NexusForge.nxproject
& .\output\nxbuild-next\x86_64-win64\nxbuild.exe /action=build /project=projects/forge/test/NexusForgeTests.nxproject
& .\output\NexusForgeTests\x86_64-win64\NexusForgeTests.exe
```

These projects use the completed NexusFPC bootstrap at
`../tools/nexus-fpc/build/forge-bootstrap/cycle3` and compile their required
package units from source into their own output directories. Forge is written
to `output/NexusForge-next/x86_64-win64/nxforge.exe`. The tests also require a
working `fpc` on PATH and the built `output/NexusCSV/x86_64-win64/nxcsv.exe`.
Lazarus is not a build dependency. Shared NexusScript changes additionally
require the NexusScript and language-server suites under their own projects.

The Forge tests compile and execute real Pascal source and exercise NexusScript
validation, target selection, Group ordering, built-in file tasks,
and command failure reporting. Compiler bootstrap
and cross-compilation are separate work.
