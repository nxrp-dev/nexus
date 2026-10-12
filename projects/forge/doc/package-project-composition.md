# Package and Project composition

Approved and implemented 2026-10-11.

## Ownership and execution

`nxpackage` owns the common Package and Project contracts and their read-only
semantic validator. Forge composes these contracts with ordered child operations.
Group, Package, and Project share one executor: there is no package-specific
scheduler, automatic Pascal invocation, or alternate process path.

Package exposes Id, descriptive metadata, Requires, Outputs, UnitPaths,
IncludePaths, and LibraryPaths. Project shares identity, metadata, requirements,
and Outputs. Compiler search paths are private child-operation settings in a
Project. Existing metadata-only packages remain valid.

Importing a package exposes its contract. An explicit composed Package child
executes its build at that position. `Requires` records relationships through
the existing catalog contract; it does not acquire or schedule dependencies.
The package editor can validate the same descriptor without preparing tools or
requiring its generated artifacts to exist.

Path references preserve the supplying value's source file. Composed child
operations default to their declaring directory. This allows a package to
generate files and export paths when built from another document. Literal tool
search/output paths retain working-directory semantics. See
[execution contracts](contracts.md) for precise path rules and examples.

## Applied builds

- Abbrevia's canonical `Package.nxscript` starts with a NativeCodecs group that
  stages Pascal source and compiles all 37 C files in one Clang invocation.
  Existing file operations own output preparation and CRT staging. Explicit
  FPC runtime-probe compilation and execution follow. The PowerShell builder
  has been retired; Win64 object references use Clang's generated filenames.
- The separate Abbrevia C/C++ bzip2 round-trip is a Project with a final Run child.
- NexusFPC Bootstrap and Cross are Projects with compiler/RTL Outputs.
  Bootstrap composes table generation before compiler construction and owns the
  final byte comparison. Compiler and RTL source staging excludes generated
  tables; five generators reconstruct instruction/register/intrinsic includes
  inside the build tree. Cross builds consume that same staged source.

`Run` is a declarative command definition and Mustache template using the existing
process executor. Additional FPC options needed by the preserved Abbrevia recipe
are likewise definition/template changes: Mode, Rebuild, ObjectPaths,
LibraryPaths, and LinkerOptions.

## Choices and remaining boundaries

- All operation templates and contracts are prepared before the first child runs.
  Source-array expansion is deferred until each command executes, so earlier
  children may generate source. Generating a later child's command template in
  the same invocation is not supported by this preparation model.
- Declaring Outputs does not verify them automatically. Explicit verification
  operations determine build success. A failed child stops the entire enclosing
  build; completed filesystem changes remain. There is no implicit rollback.
- A direct referenced compiler/executable value is a path, including a bare
  filename. Use a literal bare executable name for PATH lookup. Text expressions
  create a value at their expression's source location; direct path references
  preserve the exported value's base.
- Abbrevia's recipe currently names the preserved Win64 LLVM/SDK/CRT setup.
  It verifies the combined Pascal runtime link/startup and a separate native
  bzip2 round-trip. It does not claim complete archive/codec coverage or complete
  static-bzip2 Pascal integration.
- The compiler's checked-in generated includes and make infrastructure remain.
  The Forge compiler/RTL path now regenerates its required tables without make;
  remaining FPC package and utility recipes are separate migration work.
- The existing nxbuild-specific Project dialect remains the input to nxbuild.
  Its compiler-option model is not replaced by the common Forge Project contract.
  Forge and its tests' nxbuild descriptors include the shared validator source path.

## Verification evidence

The 2026-10-12 Abbrevia migration passed all 47 Forge checks with no reported
heap leaks. One Clang command selected all 37 codec C files and produced 37
COFF x86-64 objects. The existing Pascal runtime probe linked and ran using
the isolated Forge compiler/RTL build. The package launched no PowerShell
commands. The LLVM resource-header path is now explicit in the descriptor,
alongside the existing SDK/CRT installation paths.

The original composition verification below predates that migration.

Logs, baseline snapshots, table comparisons, and matrix results are kept under
the ignored `output/ForgeComposition` directory. The isolated compiler checkout
was populated from tracked source; generated includes are excluded when Forge
stages its build inputs. The native seed remains stock Win32 FPC 3.2.2.

- Forge: 47 passed; zero failures; heap tracing reported no leaks.
- Package/editor: 31 passed; zero failures; heap tracing reported no leaks.
  The earlier owner-paused Dependencies fixture remains excluded, as before.
- Native bootstrap: 230.85 seconds from an isolated source tree with empty build
  output. Generations two and three are byte-identical; SHA-256 for both is
  `B7E99095D61BE4FCCDF423BB2D22B57A2EB1A891A435330C227A22A215BA2810`.
- All 65 tracked generated compiler/RTL includes match the freshly generated
  content after normalizing CRLF/LF. Three additional generator outputs have no
  checked-in compiler counterpart; two are copied to the RTL and the third is
  the generator's extra x64 register-name index.
- All 13 compiler/RTL cross builds passed. Linux and Windows targets also linked
  the existing SysUtils/Classes smoke program; the i386-win32 and x86_64-win64
  programs ran and printed `forge-cross-ok`. Other target programs were not run.
  Apple/Android coverage remains compiler/RTL construction, not application linking.
- The NexusFPC-built `NexusForge-next` executable rebuilt all 37 Abbrevia codec
  objects and passed the explicit Pascal compile/startup probe. Its separate
  C/C++ Project restored all 4096 bytes after compression to 100 bytes.
- Both Lazarus and nxbuild build definitions include the common validator and
  build the Forge executable successfully. Git whitespace checks pass.

Cross timings below measure each complete target recipe in this verification
session; other validation processes were active, so these are not controlled
performance comparisons.

| Target | Seconds |
| --- | ---: |
| i386-linux | 64.40 |
| x86_64-linux | 30.83 |
| aarch64-linux | 33.18 |
| i386-win32 | 26.80 |
| x86_64-win64 | 75.10 |
| aarch64-win64 | 52.98 |
| x86_64-android | 41.32 |
| aarch64-android | 49.39 |
| x86_64-darwin | 30.09 |
| aarch64-darwin | 45.02 |
| x86_64-iphonesim | 39.19 |
| aarch64-iphonesim | 31.76 |
| aarch64-ios | 30.73 |
