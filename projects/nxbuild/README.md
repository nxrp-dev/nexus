# nxbuild

nxbuild loads a universal NexusScript `Project`, resolves its complete dependency
graph, inherits published directories, and executes producers before consumers.
Projects can publish existing sources, generate resources, compile libraries or
applications, or simply group other projects. A source-only project needs no
build operations.

`NXPC` steps build with the Nexus Pascal compiler and default to `nxpc` (or the
`NXPC` environment override). `FPC` steps retain genuine upstream Free Pascal
support, including the initial 3.2.2 bootstrap, and default to `fpc` (or `PP`).
An explicit `CompilerPath` overrides either default. Nexus product descriptors
use `NXPC` and the shared `Tools.Native.NXPCCompiler` setting.

## Project descriptions and discovery

A `.nxproject` contains one `Project` root with a nonempty, opaque `Id`.
`Version`, `Author`, `Description` and `License` are optional metadata. The root
label supplies `Name`. `RootDirectory` defaults to the descriptor's directory;
a relative root resolves from that descriptor. Build inputs, local lookup paths
and publications resolve against the publishing project's root.

A project requires records from explicitly imported `ProjectIndex` catalogs:

```nexusscript
// Projects.nxscript, beside the consumer.
dialect "path/to/nxbuild.Language.nxscript";
ProjectIndex Projects {
    ProjectReference Archives {
        Id: "Local.Archives";
        Descriptor: "libraries/Archives.nxproject";
    }
}
```

```nexusscript
// libraries/Archives.nxproject
dialect "path/to/nxbuild.Language.nxscript";
Project Archives {
    Id: "Local.Archives";
    Publishes Directories {
        Sources: ["src"];
        Headers: ["include"];
        Objects: ["path/to/external/output/objects"];
        Libraries: ["path/to/external/output/libraries"];
    }
}
```

```nexusscript
// Consumer.nxproject
dialect "path/to/nxbuild.Language.nxscript";
module Projects "Projects.nxscript";
Project Consumer {
    Id: "Local.Consumer";
    Requires: [@Projects.Archives];
    FPC Application {
        SourceFiles: ["main.lpr"];
        OutputPath: "path/to/external/output/application";
    }
}
```

A named module selects the root with that name; it does not rename the root.
Descriptor locators resolve from the catalog declaring them. nxbuild checks that
the loaded project's `Id` matches its record, diagnoses missing projects and
cycles, and rejects two descriptors claiming the same identity in one graph.
Discovery uses local descriptors, without downloading dependencies.

Every requirement contributes all four directory categories recursively. A
shared diamond dependency builds once per invocation. There are no category
imports, filters or re-export declarations. Paths from a dependency retain their
publisher's context, including target-selected variants and generated directories
that do not exist yet.

| Publication | FPC operation | LLVM operation |
| --- | --- | --- |
| Sources | `-Fu` unit lookup | Available in the resolved environment |
| Headers | `-Fi` and `-I` includes | `-I` includes |
| Objects | `-Fo` object lookup | Available for explicitly named inputs |
| Libraries | `-Fl` library lookup | `-L` during linking |

A directory publication does not compile its contents or select linker inputs.
Keep object filenames, library names and Pascal link directives explicit.
`SourceFiles` is an operation's explicit compilation/link input list. It retains
its order and repeated entries. Source masks expand at execution after required
producers have run, so generated inputs are supported.

Operations are direct children in declaration order: `FPC`, `LLVM`, or `Process`.
`OutputPath` supplies their working/output directory unless a Process specifies
`Directory`. Configure every real build's output outside the source tree. The
shared environment's `Tools.OutputRoot` defaults under the external worktree;
set it to a unique worktree directory for isolated validation. Migrated repository
descriptions establish the Nexus workspace root explicitly, keeping that setting
consistent across differently located publishers.

`SourceRoot` and `OutputRoot` are ordinary reference values. Operations explicitly
select their inputs and output directory. The native tool chooses output names;
Clang-specific naming flags can be supplied through `RawOptions` or `ConfigFiles`.

NexusFPC compiler-native packages remain independent. An FPC operation can compile
an `.nxpk` or consume `.nxpl` metadata using explicit SDK/package options.
`Requires` never infers `RequiredPackages`, SDK identities or `-FP` flags.
`PackageSDKIdentity` emits `-Fj`, `PackageBuildIdentity` emits `-Fk`,
`RequiredPackages` emits `-FP`, and `Files.PackagePaths` emits `-Fp`.
Use a matching compiler, RTL, startup units and SDK for runtime-package builds.

## Installed resource projects

The shared `Projects.nxscript` catalog includes directory-only projects for
installed SDK resources and RTL source support. A consumer requires the resources
it uses; these projects have no build operations.

| Project | Published directories |
| --- | --- |
| `NexusRTL` | Installed native RTL units |
| `RTLSystem` | RTL system and object-Pascal source directories |
| `RTLObjPas` | Object-Pascal support units and platform/CPU includes |
| `RTLGenerics` | Generic collections and their includes |
| `RTLExtra` | Additional platform RTL units and includes |
| `NativeLibraries` | Native SDK library search directories |
| `PackageSDK` | Runtime-package SDK units and its Windows library directory |
| `AppleRTL` | RTL units from the selected Apple target SDK |
| `RTLUnicodeRTL` | RTL units matching the Unicode build configuration |

The RTL source projects publish their complete relevant source/include paths;
consumers no longer reconstruct those directory layouts. Keep installed package
SDK units before standalone RTL units, and installed RTL units before fallback
sources in the requirement list. Ordinary project-local paths stay with the
consumer. The Solar2D API project also publishes its existing Windows native
plugin library directory.

Installation roots and compiler selection still come from the configuration
modules. System headers stay in `SystemIncludePaths` because those use `-isystem`,
while published `Headers` use `-I`. Package lookup stays in `Files.PackagePaths`
(`-Fp`). Compiler executables, target triples, SDK identities, library names and
linker options remain explicit settings; directory publication does not carry
them. This migration does not add publication fields or external-value handlers.

## Builders

FPC entries directly contain the existing typed FPC settings: SourceFiles,
OutputPath, CompilerPath, Config, Files, Language, Syntax, Target, Linking,
and the remaining compiler option sections in the dialect. For example:

```nexusscript
FPC Application {
    SourceFiles: ["main.lpr"];
    CompilerPath: "tools/ppcx64.exe";
    OutputPath: "path/to/external/output/application";
    Config Options { DisableDefaultConfigFiles: True; }
    Language Pascal { Mode: ObjFPC; }
    Target Platform { OperatingSystem: "win64"; }
    Syntax Operators { COperators: Disabled; }
}
```

An FPC entry compiles each listed source separately, in order, with the same
settings and OutputPath. FPC follows that source's unit dependencies as usual.
A failure stops the remaining sources in that entry and all subsequent entries.

C-style operators default to enabled. Enabled emits -Sc, Disabled emits -Sc-,
and Unset emits neither. CompilerPath is local to the entry; an omitted FPC
compiler uses PP, then fpc. OutputPath supplies both -FE and -FU, directing
executables and compiled units to the same destination. FPC chooses their names.
The former Files.ExecutableOutputPath and Files.UnitOutputPath settings are
replaced by this common property.

LLVM entries invoke Clang. Language is Auto, C, or CPP; CPP defaults to
clang++, while Auto and C default to clang. CompilerPath overrides that choice.
SourceFiles expands to the files passed to that single invocation. BuildKind is Program,
SharedLibrary, or Object. Other named settings are OutputPath, RawOptions, ConfigFiles, Target, Standard,
IncludePaths, SystemIncludePaths, LibraryPaths, Libraries, Defines, DebugInfo, and
PositionIndependentCode. SystemIncludePaths uses -isystem for SDK/compiler headers;
IncludePaths uses -I for project headers. Clang runs in OutputPath. RawOptions passes explicit native argument strings before the input list and libraries.
For example, an Object entry with two source files can produce two object files
in one invocation. Clang determines whether the supplied combination is buildable.


`ConfigFiles` passes native Clang configuration files in declaration order using
`--config`. Paths resolve against RootDirectory; Clang reads and validates their
contents during execution. This lets the compiler's own configuration describe
its artifacts while nxbuild supplies OutputPath. See
[Clang configuration files](https://clang.llvm.org/docs/UsersManual.html#configuration-files).

`SourceFiles` accepts literal filenames and `*`/`?` filename masks for both
builders, for example:

```nexusscript
SourceFiles: ["native/*.c", "support/helper.c"];
```

Masks expand when their build entry executes, so they can select files created
by an earlier entry. Each mask searches only its stated directory, without
recursion or wildcards in directory names. Matches use filesystem enumeration
order; nxbuild does not sort them. Array declaration order and repeated files
are preserved. List files explicitly when their compile order matters.
An unmatched mask fails that entry and stops the build. Literal filenames are
passed to the compiler, which reports missing or invalid input as usual.

## Process operations

`Process` runs an executable directly, with an argument array and no shell.
`Directory` is its working directory and defaults to `OutputPath`. Relative
Directory/OutputPath values resolve against the project root; argument strings
retain ordinary process semantics relative to Directory.

```nexusscript
Process Generate {
    Executable: "python3";
    Directory: ".";
    OutputPath: @Example.OutputRoot + "/generated";
    Arguments: ["generate.py", @Example.OutputRoot + "/generated"];
}
```

An explicitly named tool may be produced by an earlier operation. Planning
accepts that future executable beneath the earlier producer's output directory.
Execution still stops if the producer fails or the tool cannot be launched.

## Validation, planning and execution

```sh
nxbuild /action=validate /project=Project.nxproject /targetos=linux /targetcpu=x86_64
nxbuild /action=plan /project=Project.nxproject /targetos=linux /targetcpu=x86_64
nxbuild /action=build /project=Project.nxproject /targetos=linux /targetcpu=x86_64 /buildconfiguration=Release
```

`validate` checks the project model and complete graph without requiring installed
tools. Both `validate` and `plan` display the selected OS, CPU and configuration,
project identities, dependency edges and inherited directories. `plan` also
resolves installed tools and shows operations. Validation provides model/graph
evidence; only `build` compiles the project. Neither action runs producers,
expands source masks or creates output directories.

The complete `TargetOS` / `TargetCPU` / `BuildConfiguration` selection is passed
unchanged to every dependency and its NexusScript imports. Explicit FPC OS and LLVM triple values must agree
with that context. nxbuild does not choose or install a compiler automatically.
OS and CPU default to the native nxbuild platform. `BuildConfiguration` defaults
to `Debug`, including in the nxpackage project workbench. Configuration names
are case-sensitive, matching NexusScript target criteria; custom names such as
`Profile` are accepted. An explicitly empty configuration is an error.
Cross compilation needs appropriately configured compilers, RTLs and SDKs.

Additional selections can be supplied with `/targets=Name:Value,Other:Value`.
They are available through the same Live `$Name` mechanism and are forwarded
to dependencies. Names must be unique, including the three standard selection
names; values may contain spaces and colons. Commas separate selections.
For example, `"/targets=BootstrapRoot:/path/to/worktree,Stage:cycle1"` passes
bootstrap locations without adding a bootstrap-specific nxbuild API.

Selected values are available as `$TargetOS`, `$TargetCPU` and
`$BuildConfiguration`. Common and selected directories can share one publication:

```nexusscript
Project Library {
    Id: "Local.Library";
    OutputRoot: @Tools.OutputRoot + "/Library/" + $TargetOS + "/" + $TargetCPU + "/" + $BuildConfiguration;
    Publishes Directories {
        Sources: ["src", "src/" + $TargetOS];
        Headers: ["include"];
        Objects: [@Library.OutputRoot + "/objects"];
        Libraries: [@Library.OutputRoot + "/libraries"];
    }
    // Producer operations use those same OutputRoot-based directories.
}
```

The migrated nxbuild descriptions include `$BuildConfiguration` in generated output paths.
Source-only publications and prebuilt SDK paths remain independent where
appropriate. Output paths are script expressions; nxbuild adds no directories
automatically. Reuse the producer's output value in its publications so the
published path matches its actual output. Consumers continue to require projects.

Configuration names select script criteria such as `BuildConfiguration[Debug]`.
They do not automatically enable optimization, debug information or compiler
defines. The project owns those settings. Existing projects keep their compiler
settings while gaining separate output directories for each configuration.

`build` executes the dependency-first plan sequentially. FPC invokes its compiler
once per source; LLVM uses one invocation for its list. Execution expands masks,
creates each operation's output directory and waits for completion. A failure
identifies the project/operation, preserves the tool's exit code and stops later
operations. Directory/launch failures identify their responsible operation.

## Repository builds and examples

The central catalog is [Projects.nxscript](Projects.nxscript). Source providers
live with their libraries. Optional compiled-unit checks remain ordinary
projects with separate identities; requiring a source provider does not force
those checks to compile every unit.

From the Nexus repository, with configured installed tools and an external output
root:

```sh
"$NXBUILD" /action=build /project=projects/nxbuild/nxbuild.nxproject
"$NXBUILD" /action=build /project=projects/nxbuild/test/nxbuildTests.nxproject
"$NX_OUT/nxbuildTests/x86_64-linux/Debug/nxbuildTests"
"$NXBUILD" /action=build /project=projects/nxpackage/test/nxprojectDocumentTests.nxproject
"$NX_OUT/nxproject-document-tests/x86_64-linux/Debug/nxprojectDocumentTests"
```

The nxpackage workbench edits `.nxproject` and ProjectIndex documents. Unsaved
project validation uses the same native analysis, model loader and graph/planner
as nxbuild, with tool availability checks disabled. It does not run builds.

Real integration descriptions include:

- [Configuration publications](test/fixtures/configuration-publications/README.md):
  Debug/Release objects and shared libraries reach a Pascal NXTest consumer
  through an intermediate project; common sources and configuration-selected
  headers are inherited with them.

- [Mixed.nxproject](../../../nexus-lab/examples/build/native/Mixed.nxproject):
  Pascal consumers require a C/C++ producer and inherit its object directory.
- [Generated native integration](test/fixtures/native-dependencies/All.nxproject):
  a diamond-shared producer creates Pascal source, C/Pascal includes, an object
  and a shared library. Pascal NXTests and a C consumer use their inherited paths.
- [Abbrevia source tests](../../packages/nexus-packages-ext/compression/abbrevia/test/AbbreviaSourceTests.nxproject):
  codec producers precede source consumption, without a package SDK prerequisite.
  [Test instructions](../../packages/nexus-packages-ext/compression/abbrevia/test/README.md)
  describe strict runtime-library identity verification.
- [AbbreviaRuntime.nxproject](../../packages/nexus-packages-ext/compression/abbrevia/AbbreviaRuntime.nxproject):
  a separate compiler-native runtime-package product requiring the same provider.
- [Nexus2DEngine.nxproject](../../../nexus-mobile/Nexus2DEngine.nxproject):
  native Linux simulator compilation and Lua generation run as direct LLVM and
  Process operations. [Native prerequisites](../../../nexus-mobile/platform/linux/README.md)
  belong to machine provisioning, not build execution.

The separate [engine source regressions](test/nxbuildEngineTests.nxproject)
reuse the actual engine recipe's compiler settings to check its decoder sources:

```sh
"$NXBUILD" /action=build /project=projects/nxbuild/test/nxbuildEngineTests.nxproject /targetos=linux /targetcpu=x86_64
"$NX_OUT/nexus2d-decoder-tests/x86_64-linux/Debug/nxbuildEngineTests" ../nexus-mobile/Nexus2DEngine.nxproject
```

The expanded eight-case suite currently has one passing cleanup control and
seven failing ABI, header-configuration and dispatcher-contract cases;
they are separate from the passing core nxbuild tests. The actual engine code
is unchanged. [Native finding and evidence](../../../nexus-mobile/platform/linux/NXBUILD_REVIEW.md)
record the blocker and required follow-up discussion.

NexusLS-generated projects and editor integration remain deferred to the owner's
planned LS overhaul. The checked-in build descriptions were migrated; the three
LS-dependent project-generation cases remain separate and are not counted as
passing nxbuild regressions.

For NexusFPC runtime packages, `BuildControl Options { EmbedPackageMetadata:
Disabled; }` emits `-FJ-`; Enabled emits `-FJ`; Unset keeps the compiler default.
Embedding produces `.nxpl` with compressed metadata. Disabling it produces `.nxpl`
plus `.nxp`. These compiler options are independent of nxproject dependencies.

## Recorded project issue

The legacy `nexus-lab/examples/build/orchestration/hello world & test.nxproject`
example has no required project `Id`, so the existing loader rejects it. Its
source was left unchanged during the configuration migration.
`nxbuildTests --known-project-issues` runs the `LegacyProjectIdentity` NXTest
and currently exits with a failing test for that missing identity. This is
separate from the passing configuration suite and is pending repair.
