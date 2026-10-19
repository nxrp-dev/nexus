# Review: nxbuild target-aware publications

## Inputs

- Owner's target-aware-publications request and subsequent approval of the reduced implementation on October 19, 2026.
- Completed generic NexusScript `$` references and selected-target resolution.
- Evidence: `/media/kcollins/dev/worktree/nxbuild-config-x3bupnws`.

## Implementation

`/buildconfiguration` adds `BuildConfiguration` to the existing target selection.
The shared default is `Debug`; configuration values retain their case and custom
names are accepted. Empty explicit values fail. OS/CPU normalization retains its
existing behavior. The project workbench uses the same configuration default.

Dependency loading and publication inheritance already carry arbitrary target
selections. No changes to either mechanism were needed. `validate` now reports
the resolved project directories; all CLI actions report the selected context.

123 existing nxbuild descriptions now include `$BuildConfiguration` in generated
output paths: 95 in Nexus and nested package repositories, 27 in Nexus Lab, and
one in Nexus Mobile. Publications continue to reference their producer's output.
The Abbrevia package lookup and Apple compiled-unit lookups follow the selected
configuration. Source providers and installed SDK paths remain independent.
Compiler flags remain script-owned; naming a configuration does not enable flags.

## Verification

- Rebuilt nxbuild from the current checkout using its checked-in project recipe
  and the installed NexusFPC/Clang toolchain.
- nxbuild NXTests: 43 passed, zero failures/errors/skips, zero reported heap leaks.
- Project workbench NXTests: 5 passed, zero failures/errors/skips, zero reported heap leaks.
- New real integration: four NXTests pass in Debug and four in Release. A Pascal
  consumer requires an intermediate project and inherits common sources,
  configuration-selected Pascal/C headers, a C object and a C shared library.
  Debug returns 101; Release returns 202. The distinct object/library/executable
  hashes are in `integration-artifacts.json`. Release leaves Debug's hashes
  unchanged; Debug passes again afterward. ELF analysis confirms the shared
  dependency and `$ORIGIN/../libraries` runtime path.
- Existing generated native integration: both Pascal NXTests and the C consumer
  pass. The shared producer runs exactly once in the aggregate build.
- 246 successful descriptor checks: Debug and Release for all 123 migrated
  descriptions, using their applicable targets. Raw attempts are retained in
  `recipe-validation.json`; final applicable selections are recorded in
  `validated-migrated-recipes.json`. The sweep initially selected Linux for a
  recipe explicitly targeting Windows; Windows revalidation passes in both
  configurations without changing its target settings.
- Fresh real integration `validate` and `plan` pass for both configurations and
  leave the output directory absent. OS/CPU variation and Apple unit paths are
  additionally covered by NXTests. Cross-platform native execution was not run.
- The recipes and production sources were compiled from the real checkout.
  During native builds, only the installation environment's output-root setting
  was temporarily pointed at the task's worktree and then restored byte-for-byte.

## Discovered issue retained for separate repair

`nexus-lab/examples/build/orchestration/hello world & test.nxproject` has no `Id`.
The current project contract already requires that property, so loading this
example fails with `Missing required property Id.` The immutable `before.tar.gz`
snapshot contains the same omission. The example is restored byte-for-byte to
that snapshot and is not counted among the migrated descriptions.

The owner instructed that discovered bugs receive a documented NXTest and be
left for subsequent work. `nxbuildTests --known-project-issues` runs
`NXBuild.KnownProjectIssues.LegacyProjectIdentity`, which attempts to load the
actual example and currently fails with that missing-Id error: zero passed,
one failure/error, process exit 1. It is explicitly separate from the passing
43-test suite, not an expected-pass assertion or a waived success.

The new integration fixture's initial authoring errors were corrected in the
actual fixture: a duplicate section name, missing heap-tracing RTL search paths,
and misuse of `RuntimeLinkPath`. That last property emits FPC `-Xr`, a link-time
search path. The final fixture uses `LinkerOptions` to emit the actual runtime
`-rpath` option. No compiler correction was needed.

## Artifacts and limits

All generated products and logs are under the evidence directory. The new CLI is
`products/nxbuild-next/x86_64-linux/Debug/nxbuild` there. The configured shared
source environment is restored. No toolchain installation, bootstrap change,
commit or push was performed.

The source hash manifest and a source checkpoint are saved with the evidence.

## Directory publication follow-up — October 19, 2026

The owner approved moving directory settings into dependency projects using the
existing four publication categories. Non-directory publications and extensions
to the build engine remain outside this pass.

Ten directory-only providers now describe the installed native RTL, RTL system
sources, object-Pascal support, generics, extra RTL, native library directories,
runtime-package SDK directories, Apple RTL, Unicode-configured RTL, and the
Windows Solar2D native plugin library directory. The central catalog registers
them. 120 existing consumers now require the relevant providers. All 130 new or
changed project descriptions were validated.

Shared directory layouts now belong to those providers. Three configuration
modules lost their unused derived directory fields. Installation roots, compiler
selection, target triples, SDK identities, output-root policy and linker inputs
retain their original values. System headers remain explicit `-isystem` paths;
package lookup remains explicit `-Fp`. No publication field, external-value
handler, Pascal implementation, compiler flag or test expectation changed.

The source providers publish their relevant source/include directories together.
Inherited paths follow the existing graph order; installed package units precede
the standalone RTL, followed by fallback RTL sources. Local consumer paths remain
local. The before/after audit confirmed that every removed directory expression
is covered and that all consumers' non-directory settings are unchanged.

Evidence: `/media/kcollins/dev/worktree/nxbuild-sdk-directories-5dds8uyx`.

### Verification

- Rebuilt nxbuild and its test executable from the actual checkout through their
  checked-in nxproject recipes. The first migrated batch and final recipe state
  each passed all 43 nxbuild NXTests, with no failures or reported heap leaks.
- 160 successful descriptor/target checks cover all 130 new or changed project
  descriptions. Apple checks cover the five configured OS/CPU combinations.
- 20 additional Linux/Windows Debug/Release checks verify inherited native and
  package SDK library directories, package-before-RTL unit ordering, and selection
  of the Windows plugin library directory.
- Native builds and runs: Setup 24 passed; project workbench 5 passed; Abbrevia
  210 passed with the existing 22 Windows Cabinet skips; Unicode RTL 19 passed.
- The Abbrevia recipe compiled its C codecs and shared bzip2 library. The library
  identity NXTest confirmed loading that producer's artifact. ELF inspection
  confirms x86-64 and SONAME `libbz2.so.1`.
- All ten PasZLib example programs compiled through their migrated recipe,
  exercising the extra-RTL provider.
- Debug and Release publication integration each passed four NXTests for Pascal
  sources/includes, a C object, and a C shared library. Their artifact hashes
  differ, Release leaves Debug unchanged, and Debug passes again afterward.
  ELF inspection confirms `libnxconfiguration.so` and `$ORIGIN/../libraries`.
- Diff checks passed in all five affected repositories. The temporary validation
  OutputRoot setting was restored byte-for-byte after each build sequence.

Windows and Apple received descriptor/target and path analysis, not native builds
or execution. Compiler-native runtime-package SDK builds were not performed;
the installed Linux package SDK fields remain unconfigured, as before. Abbrevia
was tested through its source/native recipe.

### Validation corrections and retained limits

The new PackageSDK description initially selected two publication blocks on
Windows. It was corrected in the actual descriptor to use disjoint target
blocks, then passed both targets. A sweep initially selected Windows for the
existing Linux-only integration fixture; the sweep now honors its root target.

Initial native test invocations omitted documented runner inputs: Abbrevia's
data-directory argument and expected-library environment value, the Unicode ZIP
fixture beside its executable, and the integration runner's configuration
argument. Those invocations reported errors/failure and were not counted as
successes. Final runs use the existing documented interfaces. Test code and
expectations were unchanged; copied test data was verified byte-identical.
The invocation history and available failed-run logs remain with the evidence.

The previously documented legacy example without an Id remains byte-for-byte
unchanged and excluded from this migration. Its existing failing NXTest remains
available through `nxbuildTests --known-project-issues`.

No toolchain installation, bootstrap change, commit or push was performed.
