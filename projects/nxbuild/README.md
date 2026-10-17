# nxbuild

nxbuild reads a NexusScript Project or Package description, plans its ordered
build invocations, and executes them on request. FPC invokes the compiler once
per source file; LLVM passes its source list to one invocation. Entries may repeat
and may be mixed in the same description.

## Description

A description has exactly one Project or Package root. Both currently have the
same build-container fields: Name, RootDirectory, SourceRoot, and OutputRoot.
The root label supplies Name. RootDirectory defaults to the descriptor's
directory; a relative RootDirectory is resolved from that directory.

Builds are direct children, in declaration order:

```nexusscript
dialect "path/to/nxbuild.Language.nxscript";

Package Example {
    OutputRoot: "output";

    LLVM Native {
        Language: C;
        BuildKind: Object;
        SourceFiles: ["native.c"];
        OutputPath: @Example.OutputRoot + "/native";
    }
    FPC Application {
        SourceFiles: ["main.lpr"];
        OutputPath: @Example.OutputRoot + "/application";
        Files Paths {
            ObjectPaths: [@Example.Native.OutputPath];
        }
    }
}
```

Build names must be unique within the root. Build paths resolve against
RootDirectory. SourceRoot and OutputRoot are available to ordinary NexusScript
references and expressions; entries explicitly specify their compiler paths
and settings. OutputRoot is a reference value, not an implicit destination.

Every build entry has a SourceFiles array. Paths resolve against RootDirectory
and retain their listed order, including repeated entries. Planning requires a
nonempty list but does not check whether the files exist. InputFile is no longer
supported.

Every build entry has an OutputPath directory. It resolves against RootDirectory
and defaults to RootDirectory when omitted. Execution creates it and runs the
tool there. Inputs and search paths still resolve against RootDirectory.

The tool chooses the filenames, number of files, and contents in that directory.
nxbuild has no OutputFile or OutputName setting and does not rename or enumerate
build outputs. Choose separate OutputPath values when builds need separate
destinations.

Project/package contract resolution is a separate concern from this build
collection. Package here identifies the containing description; an FPC runtime
package is compiled by an FPC entry whose SourceFiles selects an `.nxpk` declaration.

FPC package options are named fields: `PackageSDKIdentity` emits `-Fj`,
`PackageBuildIdentity` emits `-Fk`, and `RequiredPackages` emits one `-FP` per
package. `Files.PackagePaths` resolves directories against RootDirectory and
emits `-Fp`. An `.nxpk` normally lists dependencies in its `requires` clause;
an executable lists them in RequiredPackages. The compiler creates a build
identity when PackageBuildIdentity is omitted. All participants use the same
SDK identity and matching shared RTL/startup units.

## Builders

FPC entries directly contain the existing typed FPC settings: SourceFiles,
OutputPath, CompilerPath, Config, Files, Language, Syntax, Target, Linking,
and the remaining compiler option sections in the dialect. For example:

```nexusscript
FPC Application {
    SourceFiles: ["main.lpr"];
    CompilerPath: "tools/ppcx64.exe";
    OutputPath: "output/application";
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
SharedLibrary, or Object. Other named settings are OutputPath, ConfigFiles, Target, Standard,
IncludePaths, SystemIncludePaths, LibraryPaths, Libraries, Defines, DebugInfo, and
PositionIndependentCode. SystemIncludePaths uses -isystem for SDK/compiler headers;
IncludePaths uses -I for project headers. Clang runs in OutputPath without an -o override.
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

## Planning and execution

```powershell
nxbuild /action=plan /project=../nexus-lab/examples/build/native/Hello.nxproject
nxbuild /action=build /project=../nexus-lab/examples/build/native/Hello.nxproject
nxbuild /action=plan /project=../nexus-lab/examples/build/native/Mixed.nxpackage
nxbuild /action=build /project=../nexus-lab/examples/build/native/Mixed.nxpackage
```

Optional `/targetos=<os>` and `/targetcpu=<cpu>` select the requested target.
Each omitted value defaults independently to nxbuild's native OS or CPU, using
FPC platform names (for example, `win64` and `x86_64` on this machine).
These defaults describe the nxbuild executable's platform; an emulated executable
uses its own platform, not the underlying machine's hardware. Values are
normalized to lowercase. Explicit flags require nonempty values.

```powershell
nxbuild /action=plan /project=../nexus-lab/examples/build/native/Abbrevia.nxpackage /targetos=linux /targetcpu=x86_64
```

nxbuild supplies these values to the existing NexusScript target selection as
`TargetOS` and `TargetCPU`. Selectors apply to the description and its imported
modules before the build plan is created. The selected values and references
configure each tool; nxbuild does not override compiler options or select a
compiler automatically. The supplied Abbrevia environment has native x86-64
Windows and Linux settings. A different target requires corresponding settings.

The existing /project flag accepts either root kind. Planning validates the
description and resolves each tool to an existing file, using PATH for bare
names. The plan contains one step per build entry, showing its tool, source
selections (including unexpanded masks), compiler options, and OutputPath.
It does not expand masks, run tools, create directories, check source existence,
or predict compilation success.

Execution follows the plan in declaration order. For each entry it expands
SourceFiles, prepares OutputPath, and invokes the compiler: once for all LLVM
sources, or once per FPC source. It waits for each invocation and stops at the
first failure.
A nonzero tool exit code is reported with the build's name and returned by
nxbuild. Launch and directory errors also identify the responsible build.

## Shared tool and SDK settings

[nxbuild.environment.nxscript](nxbuild.environment.nxscript) contains this
installation's tool and SDK settings under the root named `Tools`. Abbrevia
imports it explicitly, using the existing NexusScript module mechanism:

```nexusscript
module "../nxbuild.environment.nxscript";

Package Abbrevia {
    LLVM Native {
        CompilerPath: @Tools.Native.LLVMCompiler;
        Target: @Tools.Native.Triple;
        SystemIncludePaths: @Tools.Native.SystemIncludePaths;
        LibraryPaths: @Tools.Native.LibraryPaths;
        // SourceFiles and OutputPath describe this package's build.
    }
}
```

Module paths resolve relative to the file declaring them. Packages can share
one module and obtain updated values without changing their build descriptions.
For another environment, configure that shared file's installation paths and
versions. A package can also explicitly reference another module file.

`Tools.Native` selects platform-specific compiler, RTL, system include and
library paths with `TargetOS[win64]` and `TargetOS[linux]`.
`Tools.WindowsSDK` and `Tools.MSVC` describe the Windows-only installations.
`Tools.NexusFPC` supplies the compiler source path. The enclosing `Tools`
definition selects `TargetCPU[x86_64]`.

The module is ordinary NexusScript. Its descriptive kinds (`Environment`,
`SDK`, `Platform`, `Toolchain`) do not become build entries. Packages reference
the selected values without duplicating their build sequence.

There is no automatic environment import or environment command-line switch.
The package's module declaration selects its configuration. Existing NexusScript
errors report missing modules and unresolved references. Build-option validation
inside FPC and LLVM entries remains unchanged.

## Abbrevia integration example

The supplied regression cases and the former codec probes now use nxtest under
[Abbrevia/test](../../packages/nexus-packages-ext/compression/abbrevia/test/README.md).
Current full-suite results and remaining failures are recorded there. The older
52-check verification below is historical codec-only evidence.

`../../../nexus-lab/examples/build/native/Abbrevia.nxpackage` uses the same three ordered entries on Windows
and Linux:

1. LLVM compiles 30 LZMA, PPMd and WavPack C sources to objects in one invocation.
2. LLVM compiles and links seven bzip2 C sources into the platform shared library.
3. FPC compiles `Abbrevia.nxpk`, containing all 51 Pascal runtime units and
   requiring `nxrtl`, into `Abbrevia.nxpl` with embedded development metadata.
   Tests are built separately from Abbrevia/test/AbbreviaTests.nxproject and
   consume the compiled package through RequiredPackages.

Source masks expand during execution without sorting. The three entries produce
three compiler invocations. No build helper script is used.
The LZMA sources retain their existing threading configuration.

Run from the Nexus repository root on Windows:

```powershell
output/nxbuild-next/x86_64-win64/nxbuild.exe /action=plan /project=../nexus-lab/examples/build/native/Abbrevia.nxpackage
output/nxbuild-next/x86_64-win64/nxbuild.exe /action=build /project=../nexus-lab/examples/build/native/Abbrevia.nxpackage
output/nxbuild-next/x86_64-win64/nxbuild.exe /action=build /project=packages/nexus-packages-ext/compression/abbrevia/test/AbbreviaTests.nxproject
output/nxbuild-abbrevia/x86_64-win64/pascal/AbbreviaTests.exe packages/nexus-packages-ext/compression/abbrevia/test/testfiles
```

The equivalent commands on Linux use `output/nxbuild-next/x86_64-linux/nxbuild`
and the executables without `.exe` in
`output/nxbuild-abbrevia/x86_64-linux/pascal`. Target flags are optional on
either native host. Adjust `nxbuild.environment.nxscript` for the installed
NexusFPC, RTL, package SDK and Clang paths; Linux uses the system C headers and libraries.
PackageSDKPath selects the matching SDK directory, PackageSDKIdentity comes from
its sdk.json, and PackageLibraryPaths includes its packages directory alongside
the platform libraries. Replacing the SDK requires updating these installation
settings together. The Linux package SDK must be installed/configured on that host.

At runtime, the matching `nxrtl.nxpl` must be beside the executable or on the
platform library search path. `Abbrevia.nxpl` and the generated bzip2 library
are built beside the test executable. The source declaration `.nxpk` is build
input; `.nxpl` is the compiled runtime package.

Clang's `libbz2-win64.cfg` names `libbz2.dll` and references `libbz2.def`,
which exports all 24 public bzip2 functions. Clang's `<CFGDIR>` locates that
definition file. `libbz2-linux.cfg` names `libbz2.so.1` and sets its SONAME.
These are compiler configurations; nxbuild supplies only OutputPath.
Both libraries are built beside the Pascal executables. Linux executables use
the linker's `$ORIGIN` rpath to load that sibling library.

SDK headers use LLVM SystemIncludePaths. LibraryPaths provides libraries to
both builders. Windows object directives retain their `Win64/` prefix;
Linux directives use the object filenames. FPC ObjectPaths includes the
Native entry's output directory and its parent.

The binding updates enable the existing bzip2, LZMA, PPMd and WavPack codec
paths on Linux and link the newly compiled ELF objects against libc, libm and pthread.
PPMd's allocation callbacks use the Pascal allocator on both platforms.
The shared size_t declaration in Abbrevia.CRuntime is available on Windows and
Linux and uses ctypes.csize_t, preserving C's unsigned, pointer-sized contract.
The LZMA and PPMd bindings use that declaration. The nxtest codec suite checks its size
and unsigned range before exercising the codecs.
Linux verification programs that use LZMA place cthreads first in their uses
clause under an explicit LINUX guard, initializing the Pascal thread support
required by the existing codec.
The codec's threading defaults and IsMultiThread initialization are unchanged.
WavPack's implementation-only C import now declares its callback record as
a var parameter, matching the pointer required by WavpackOpenFileInputEx.
The previous const declaration passed a record value under the Linux ABI;
the public DecompressWavPack interface is unchanged.
The pre-existing bzip2 correction scopes `{$PACKRECORDS C}` to TBZStreamRec;
the nxtest codec suite checks its 80-byte layout on both tested 64-bit platforms.

The codec checks exercise:

- Eight bzip2 buffer/stream round trips at 0, 1, 4,096 and 1,048,576 bytes,
  plus verification that the generated sibling library was loaded.
- All 11 entries in each Canterbury Deflate, LZMA and PPMd ZIP, comparing
  extracted bytes with Store.zip (33 comparisons).
- Eight LZMA buffer/stream round trips at the same four sizes.
- Three WavPack decodes (8-, 16- and 24-bit PCM), comparing complete WAV bytes.

The small WAV fixtures contain 256 mono samples at 8 kHz: unsigned sample
`i` at 8 bits, or signed `(i - 128) * 2^(bits - 8)` at 16/24 bits.
Their WavPack files were generated with the reference WavPack 5.9.0 encoder
using default lossless settings. They are generated test data, not recordings.
The reference encoder is not a package build or runtime dependency.

Verified on 2026-10-13: the shared package compiled all 50 Pascal
units and 30 native codec objects, then linked the bzip2 shared library and all three probes
on x86-64 Windows and native Ubuntu Linux under WSL. Startup and all 52 codec
checks passed on each platform, including confirmation of the generated bzip2
library's location. All 19 nxbuild grouped tests passed on Windows with zero
unfreed heap blocks.
After correcting the shared size_t declaration and explicit Linux guards, both
package builds and all 52 codec checks passed again, including the new checks
that size_t is unsigned and pointer-sized.

Recorded build invocations took 63.61 seconds on Windows and 194.80 seconds
on Linux, excluding the subsequent codec checks. These are local verification
timings, including WSL invocation overhead, not a platform performance comparison.
Local verification used Clang 23 on Windows and Clang 18 on Linux. A matching
native NexusFPC compiler was generated from the existing staged compiler sources
for Linux; its binary is in output/nxbuild-next/x86_64-linux/ppcx64.
Clang 18 and the reference WavPack encoder were installed in the WSL environment
for this verification. No compiler or Forge source changes were needed.
This pass targets native x86-64 Windows and glibc Linux. It does not change
Windows-specific CAB facilities or the separately threaded LZMAStream wrapper.
Portable LZMA buffer/stream functions and ZIP extraction use the enabled codec.
Forge and common NexusScript source are unchanged.

## Building and testing nxbuild

The executable and its own test suite have descriptions:
nxbuild.nxproject and test/nxbuildTests.nxproject. Set CompilerPath and the FPC
unit/include paths inside each FPC entry for your NexusFPC installation.

```powershell
nxbuild /action=build /project=projects/nxbuild/nxbuild.nxproject
nxbuild /action=build /project=projects/nxbuild/test/nxbuildTests.nxproject
output/nxbuildTests/x86_64-win64/nxbuildTests.exe
```

Run the tests from the Nexus repository root. They cover ordered mixed builds
under both root kinds, typed options, relative paths, common output destinations, tool availability,
planning without existing source files or directory creation, execution-time
mask expansion (including generated sources), shared environment modules, OS/CPU selection in imported modules, and
sequential execution that
preserves the failing tool's exit code and skips later entries.

The mixed example compiles C and C++ objects in one LLVM invocation. Its FPC
entry then builds Mixed.lpr and Hello.lpr in separate invocations using the same
settings and output directory. Configure both toolchains for the same target.

The three existing NexusLS project-generation cases are preserved in the
separate test/nxbuildProjectGenerationTests.lpr and .nxproject runner. They remain
blocked until NexusLS adopts the current description model and dialect.
NexusLS was not modified in this nxbuild-only pass.

The earlier Pascal-only root fields and FPCBuildOptions child have been
replaced by FPC entries. Lazarus settings remain unsupported.

## Verification

Verified on Win64 with NexusFPC and LLVM:

- Fresh source compilation and nxbuild rebuilding itself through its FPC entry.
- All 19 grouped tests passed, with zero unfreed heap blocks in the test runner
  and its helper processes.
- The mixed package built its C and C++ objects in one LLVM invocation, with
  Clang choosing both object filenames, and one FPC entry built both Pascal
  executables through separate compiler invocations;
  both executables ran successfully, including the linked native functions.
- OutputPath worked with spaces and separate destinations; all generated files
  stayed in those directories, with no build artifacts in the example sources.
- FPC source lists preserved order, repeated entries, shared settings and the
  shared output directory in the plan.
- A missing middle FPC source preserved the compiler exit code and stopped both
  the remaining source and the following LLVM entry.
- A missing tool in a later entry prevented every build from starting.
- Masks expand per build entry at execution, with filesystem enumeration order,
  no recursion, and declaration order/repeats preserved. Tests cover generated
  sources from a preceding entry and unmatched-mask failures.
- An explicitly imported environment module supplied both LLVM and FPC paths.
  Changing its values updated plans for both Project and Package descriptions
  without changing those descriptions; missing or invalid modules were rejected.
- Missing source was accepted during planning; execution reported Clang's
  failure, preserved its exit code, and skipped subsequent entries.

The verified executables are in output/nxbuild-next/x86_64-win64/nxbuild.exe
and output/nxbuild-next/x86_64-linux/nxbuild.
The test runner is in output/nxbuildTests/x86_64-win64/nxbuildTests.exe.

For NexusFPC runtime packages, `BuildControl Options { EmbedPackageMetadata:
Disabled; }` emits `-FJ-`. `Enabled` emits `-FJ`; `Unset` or omission keeps the
compiler default. The default produces one `.nxpl` with compressed compiler
metadata. Disabling embedding produces `.nxpl` plus `.nxp`; both modes use the
same runtime loading behavior and can be mixed among dependencies.