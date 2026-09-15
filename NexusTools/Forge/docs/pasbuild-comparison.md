# PasBuild project translation and gap review

Date: 2026-09-15. Status: comparison rerun after approved Forge corrections.

Forge builds the selected PasBuild project in default, debug, and release variants
using module-composed configurations. It prepares artifact directories, derives
filenames from shared environment data, and inherits each operation's command
Template. The harness still prepares resources; that remains a demonstrated gap.
The table below contains only outstanding behavior differences.

## Input and reproducibility

Selected [PasBuild's own project.xml](../../../lib/pasbuild/project.xml), version
1.10.0-SNAPSHOT. Unlike its single-file sample, it declares filtered resources,
two compiler profiles, tests, and an additional source-archive directory.

- [Corresponding Forge package](../examples/pasbuild-comparison/PasBuild.ForgePackage.nxscript)
- [Shared environments and operation configurations](../examples/pasbuild-comparison/Shared.nxscript)
- [Repeatable comparison script](../../../scripts/Compare-ForgePasBuild.ps1)
- [Recorded results](../../../output/ForgePasBuildComparison/20260915-095939/results.json)
- [Test failure comparison](../../../output/ForgePasBuildComparison/20260915-095939/test-comparison.json)

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Compare-ForgePasBuild.ps1
```

The script creates a new dated directory under output/ForgePasBuildComparison.
It copies the original project, sources, resources, documentation, and license
into independent bootstrap, baseline, and Forge roots. Each package definition
resides in its actual staged package root. No existing artifacts are copied.

The old vendored PasBuild executable reported 1.0.0. To avoid measuring a stale
implementation, the script bootstraps the current PasBuild source with FPC 3.2.2
and uses that executable for the baseline. Both current executables subsequently
report version 1.10.0-SNAPSHOT and the correctly substituted build date.

The translation deliberately stores variants in target/default, target/debug,
and target/release. PasBuild's XML uses one target directory for all profiles;
sharing that executable path would cause Forge's presence-only reuse to accept
one profile's executable for another. Separate paths use the agreed folder model.
CPU/OS are restricted to the Windows x64 host actually tested.

## What happened

| Attempt | Observed result |
| --- | --- |
| PasBuild compile: default, debug, release | All succeeded. |
| Forge package with inherited project template, clean tree | Created its selected artifact directory, then failed on missing version.inc. |
| Forge with prepared resources and project-specific compiler templates | All three variants compiled successfully. |
| Repeat the default Forge request | Reused the executable without starting FPC. |
| Add CompilerOptions to an FPC operation | Validation rejected it: NSV2102, Unknown property CompilerOptions. |
| PasBuild test | 251 tests, zero errors, 12 failures. |
| Forge test compilation, then explicit external test execution | 251 tests, zero errors, the same 12 failure messages. |
| PasBuild binary package and source-package | Both succeeded; binary ZIP has 3 entries, source ZIP has 135 entries. |
| Introduce invalid Pascal into each copied source with executables still present | PasBuild compile failed; Forge reused its existing executable. Sources were restored byte-for-byte afterward. |

Matching test failures are baseline failures in this environment, not evidence of
a Forge regression. Their underlying causes were not investigated in this task.
The standalone Forge test run required explicit fixture copying and an external invocation from target/default. It is not a complete Forge test lifecycle.

## Outstanding gaps and decisions

“Missing” below means absent from the current shipped Forge vocabulary/workflow.
It does not mean the generic executor cannot invoke a tool that performs the work.
Harness resource preparation, fixture copying, and external test execution remain
outside Forge.

| PasBuild behavior used by this project | Current Forge translation | Classification / decision |
| --- | --- | --- |
| Copy/filter main resources | Harness generates version.inc and build-date.inc. No resource operation exists in the shipped Forge pieces. | Needed by this real build. Decide the explicit generation/copy mechanism; do not assume all PasBuild interpolation variables must be copied wholesale. |
| Compiler flags and unit/include search paths | Custom templates still provide flags and input search paths. | Declarative compiler flags and input search paths remain incomplete. |
| Debug and release defines/profiles | Defines and templates are inherited from target-selected configurations; templates supply profile flags. Separate paths preserve variants. | Both individual profiles proven. PasBuild also supports ordered comma-separated profile composition; this one-of-three BuildMode translation does not reproduce it. Composition is source-verified, not separately exercised here. |
| Copy test fixtures, run tests with framework options from output directory, propagate exit code | Harness performs these steps outside Forge. | Missing test-running vocabulary/workflow. Package operations currently use the package root, whereas PasBuild runs this suite from target. Decide how to express execution context and an explicit test request. |
| Binary distribution ZIP | PasBuild produced pasbuild-1.10.0-SNAPSHOT-x86_64-win64.zip containing pasbuild.exe, LICENSE, README.adoc. No Forge archive produced. | Missing archive recipe and metadata/naming/content conventions. Forge Package means an obtainable build result, not automatically a distribution archive. |
| Source distribution ZIP plus configured docs inclusion | PasBuild produced PasBuild-1.10.0-SNAPSHOT-src.zip with sources, project.xml, docs, and standard accompanying files. | Missing source-archive recipe. Preserve the fact that docs was explicitly requested before deciding its replacement. |
| Goal dependencies: compile prepares resources; test compiles and prepares fixtures; package cleans then compiles | Only an explicitly authored sequence and package prerequisites are available. No clean/test/package goal vocabulary is supplied. | Workflow difference. Decide which actions need explicit recipes; importing PasBuild's entire lifecycle is not required by this finding. |
| Source inventories and status files; compiler.log for nonverbose builds | Forge captures command/stdout/stderr/exit in its run objects and CLI. Harness saves logs. No equivalent automatic status-file inventory. | Convenience/diagnostic difference. Source-verified; this comparison used verbose baseline builds. |

PasBuild's recursive unit/include scanning and conditional paths exist in the
compiler-command implementation. This project's flat source layout does not prove
equivalence for nested/conditional paths. The explicit flags in this translation
are sufficient for the selected tree, not a replacement for that scanning behavior.

## Source anchors

- [XML declarations](../../../lib/pasbuild/project.xml): resource filtering, test options, profiles, metadata, docs inclusion.
- [Compiler command and preparation](../../../lib/pasbuild/src/main/pascal/PasBuild.Command.Compile.pas): paths, defines/options, directory creation, profile ordering, status lists, resource prerequisite.
- [FPC defaults](../../../lib/pasbuild/src/main/pascal/PasBuild.Compiler.FPC.pas): -Mobjfpc -O1 and output/search flags.
- [Resource substitution](../../../lib/pasbuild/src/main/pascal/PasBuild.Command.ProcessResources.pas): project variables and build date/time variables.
- [Test lifecycle](../../../lib/pasbuild/src/main/pascal/PasBuild.Command.Test.pas): compile prerequisite, separate test units, framework options, output-directory execution.
- [Binary packaging](../../../lib/pasbuild/src/main/pascal/PasBuild.Command.Package.pas) and [source packaging](../../../lib/pasbuild/src/main/pascal/PasBuild.Command.SourcePackage.pas): goal prerequisites, names, archive contents.
- [Forge FPC contract](../../../NexusLib/script/dialects/NexusForge/pieces/FPC.ForgeDef.nxscript) and [package contract](../../../NexusLib/script/dialects/NexusForge/pieces/Package.ForgeDef.nxscript): currently accepted properties.

## Scope and next decisions

The remaining demonstrated needs for a clean build are resource generation and
declarative FPC settings currently supplied by custom templates. Tests and archives
are additional real requirements declared by or conventionally consumed from this
project.xml; they have not been silently discarded.

This project declares no library, module dependency, or installed-package dependency.
It therefore does not establish parity for library bootstrap generation, reactor
ordering, repository install/resolve, transitive paths, or nested aggregators.
It also does not test another compiler backend, cross-compilation, or plugin hooks.
Those need an appropriate second project before drawing conclusions.

## Current verification

The linked run uses the shared module and direct Template model. Default, debug,
and release builds succeed; a second default request reuses the executable.
Application filenames derive from Platform.ExecutableSuffix, and compiler Output
references the package artifact Path. Test compilation uses CompileTests from the
same shared module. Both suites run 251 tests with the same 12 baseline failures.

The Forge suite passes all 21 tests, including selected output-folder preparation,
explicit compiler-unit placement, intermediate outputs outside artifact directories,
environment-derived artifact lookup before reuse,
dependency-specific configuration selection, and inherited template path origins.
The earlier full regression run passed all 57 compiler and 12 language-server
tests with zero heap leaks.
No NexusScript core rule change was needed.

The explicit UnitOutput correction was verified separately in a fresh
[build run](../../../output/ForgeUnitOutput/20260915-103604/results.json).
Default, debug, and release each compiled successfully with 29 units in the
configured artifact directory; standalone test compilation also succeeded.
Resources were explicitly prepared by the verification harness. This focused run
did not repeat baseline tests or archive production.
