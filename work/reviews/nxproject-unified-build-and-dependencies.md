# Unified nxproject implementation review

Status: Implementation and Linux engine/plugin acceptance complete; native Windows and runtime-package SDK validation remain unverified. LS work is deferred.
Date: 2026-10-19.
Plan: [nxproject-unified-build-and-dependencies.md](../plans/nxproject-unified-build-and-dependencies.md).
No implementation commit or push has been made.

## Implemented behavior

nxbuild now accepts one universal Project entity with a required opaque Id,
optional metadata, all four directory publications, requirements and ordered
FPC/LLVM/Process operations. Source-only and aggregate projects are valid.
ProjectIndex records explicitly locate dependencies; the loader preserves the
record's original file context and source location. Resolution checks identities,
rejects conflicting descriptors, reports missing/cyclic requirements and builds
a deterministic dependency-first closure. A shared dependency builds once per
invocation. There is no incremental cache or concurrency change.

Plans own their project/environment/step snapshots. Required descriptions are
owned by the graph, while its root is borrowed from the caller. Loading and
planning release those temporary objects on success and failure. Selected
TargetOS/TargetCPU values pass unchanged into dependencies. Explicit typed FPC
OS and recognized LLVM triple settings are checked for conflicts with them.
Paths normalize in their publisher's root; all publication categories propagate
transitively. FPC receives unit/include/object/library lookup paths; LLVM receives
ordinary includes and link-time library lookup paths. Explicit object filenames,
library names and compiler-native package flags remain explicit.

`/action=validate` checks the model and graph without requiring installed tools.
`/action=plan` also resolves installed or earlier-produced tools. Both are
read-only; execution alone expands source masks and creates output directories.
Process operations invoke their executable directly with an argument array.
The Unix argument-allocation correction is covered by the Process regression
documented below.

The nxpackage document model uses the same loader and planner for unsaved
nxproject validation. It can inspect ProjectIndex catalogs and change its target
selection without executing producers. Its GUI was not launched on Linux.

## Descriptor migration

- 123 existing recipes migrated in the bulk manifest, plus the independently
  migrated nxbuild self/test and lab Mixed/Abbrevia descriptions.
- All 21 in-scope nxbuild `.nxpackage` filenames become `.nxproject`. Source
  providers and optional compiled-unit checks have distinct ordinary project
  identities; requiring sources does not force an entire compiled-unit check.
- 39 source/library providers and one explicit central project catalog establish
  publication ownership. Every literal published source/header directory was
  checked for existence. Generated output publications may be absent at plan time.
- Old root BuildTool/FPCBuildOptions recipes become ordinary FPC operations.
  Existing platform restrictions are retained. Active instructions reference
  the relocated filenames; historical review evidence retains its original names.
- Abbrevia native configuration files move with the canonical provider. Its
  source/static consumer has no runtime-package SDK prerequisite. The separate
  runtime-package producer preserves explicit `.nxpk/.nxpl`, SDK identities and
  RequiredPackages; project dependencies do not infer those settings.

The later standalone decoder and plugin regression descriptors were planned
and built separately from the 175-descriptor migration audit. The original three
decoder failures are corrected; all 22 expanded decoder/codec checks pass. The
real Linux engine/plugin NXTest also passes, with 23 interaction assertions.

The authoritative change inventory with original hashes, retained local paths,
removed dependency paths and old/new filenames is
`descriptor-migration-manifest.json` in the external evidence directory below.
Model validation of every migrated recipe does not assert that every recipe
compiles, that Windows is installed or that a package SDK is configured.

## Verified results

| Check | Result | Evidence under the external worktree |
| --- | --- | --- |
| Original nxbuild suite | 25 passed, no heap leaks | `baseline/` |
| Expanded nxbuild NXTests | 37 passed, no failures/errors/skips, no heap leaks | `tests.log`, `tests-compile.command` |
| nxbuild regressions after Process correction | 37 passed, no failures/errors/skips; zero heap leaks | `process-empty-argument-fix/nxbuild-tests/` |
| Historical Linux engine retry after Process correction | 153 Lua embeddings complete; build stops at decoder callback mismatch | `process-fix-engine-1792403820698615472-*` |
| Historical initial engine source regressions | Test recipe builds; 3 actual-source NXTests fail on the six decoder errors; zero runner heap leaks | `engine-decoder-abi/` |
| Historical Linux engine build after decoder correction | All 153 Lua embeddings, 594 objects and link pass in 322.74 seconds | `decoder-engine-final-1792414839218053965-*` |
| Decoder/runtime NXTests before lifetime fixes | 24 passed, 1 failed, 0 errors/skips; zero runner leaks. All 22 decoder/codec cases pass; original-application shutdown fails | `decoder-interface-fix/final-width-tests.log` |
| Approved Unix Process correction | Unchanged regression passes with zero leaks; full suite 12 passed, 3 Windows-only skips; rebuilt CLI argv probe passes | `process-empty-argument-fix/`, `process-fix-suite-1792403795442012886-*` |
| Final migrated nxbuild self/test recipes | Build passed; 37 NXTests passed, no heap leaks | `nxbuild-final-1792401122393059269-*` |
| Real migrated workbench test recipe and nxbuild producer | Build passed; 4 NXTests passed, no heap leaks | `workbench-model-recipe-corrected-1792400944140428431-*` |
| Migration descriptor audit | 175 descriptions, 184 valid target contexts, 0 failures | `descriptor-audit-final/results.json` |
| Original Mixed C/C++/Pascal example | Native objects and both applications build/run; Mixed result 42 | `mixed-1792396259592270965-*` |
| Generated native diamond | Producer once; Pascal 2 NXTests pass; C executable exit 0 | `generated-native-catalog-1792400183635238391-*`, `generated-native-runtime.json` |
| Actual generated artifacts | ELF x86-64 object, shared library and consumers; C DT_NEEDED names actual produced library | `generated-native-linkage.log` |
| Abbrevia source suite | 210 passed, 0 failures/errors, 22 platform skips | `abbrevia-source-tests-corrected.log` |
| Abbrevia library identity controls | Produced-library path accepted; different system-library expectation rejected | `abbrevia-identity-controls.json` and control logs |
| Abbrevia publisher relocation | Provider source publication changed to a real path containing a space; unchanged consumer rebuilt and 210 tests passed, 22 skips | `publisher-relocation/` |

All build logs retain failures as well as successful corrections. The expected
producer-failure tests deliberately report nonzero child statuses; those do not
represent failures of the nxbuild suite. Platform skips remain skips.

The Abbrevia suite initially had one failure because its old identity check
assumed the codec library was beside the executable. The provider now owns a
separate library directory. The actual test now accepts an explicit expected
artifact path, compares the loaded path exactly, and independently loads the
codec before checking it. A negative control rejects a different library;
this does not weaken validation or change codec implementation. Original
fixture payloads were copied byte-for-byte only to isolate test scratch files.
No copied implementation was altered.

The full audit initially found seven errors in this migration: three duplicate
environment imports in Unicode recipes and four root-property conversions that
missed one-space indentation. These were corrected in the actual checked-in
recipes and all seven then validated. The first workbench recipe build also
found a missing RTL source lookup for heaptrc; the recipe now includes the same
RTL source paths used by its direct compile. Original failed logs are retained.

## Resolved defects and unverified acceptance

1. **Unix empty arguments: corrected with owner approval.** The nil entry
   from StrNew prematurely terminated argv and cleanup. The two-line Process
   correction now allocates and copies empty strings too, reserving nil for the
   final terminator. The unchanged failing NXTest now passes with zero unfreed
   heap blocks. The full Process suite passes 12 tests with 3 Windows-only skips,
   and rebuilt nxbuild preserves the original `['-c', '', 'tail']` argv probe.
   See `process-empty-argument-fix/` and
   `process-fix-suite-1792403795442012886-*`. No RTL or bootstrap change was made.
2. **Linux engine decoder blocker: corrected with owner approval.** The expanded
   interface correction covers portable codecs, native adapters, dispatcher, RWops
   and consumers. Original 1-pass/7-fail evidence is preserved. The expanded suite
   passes all 22 decoder/interface and actual-codec cases. Including simulator
   exit scenarios, the result at that stage was 24 passed, 1 failed, 0 errors/skips, with
   zero runner leaks. The actual simulator compiled 594 objects and linked through
   nxbuild in 322.74 seconds. Full evidence and platform limits are in
   `../nexus-mobile/platform/linux/NXBUILD_REVIEW.md`.
   **The original runtime failure is corrected.** Its recorded before-fix
   OriginalApplicationExit case reproduced heap corruption from the original
   application directory, while two other scenarios passed.
   Those two lifetime defects are now corrected with owner approval: the
   context owns its font provider, locale strings remain alive until copied, and
   594 link inputs are explicitly ordered. All 27 release-engine behavior checks
   pass, including the original shutdown case and a populated-font fixture.
   The full sanitizer run exposed an IndexArray malloc/delete mismatch;
   two specific NXTests proved it. Its separately approved one-line correction is
   applied and passes both regressions. The subsequently approved console/window
   and unused-audio cleanup fixes now remove all reported engine-owned leaks.
   Final instrumented NXTests: 30 passed / 2 failed, both solely the installed
   Mesa/EGL leak the owner accepted for now. That leak remains unchanged and
   visible; no vendor repair is pending. The final optimized build and all seven
   runtime scenarios pass.
3. **Pascal plugin shared-library link: corrected and validated.** The original
   failure against non-PIC RTL objects remains in
   `solar2d-pascal-plugin-1792400988928779490-*`. The owner subsequently approved
   making PIC the Linux x86-64 compiler default. The one-line target-flag change
   builds an ordinary PIC RTL through the unchanged bootstrap script. All 13
   shared-library NXTests pass, including a library compiled without `-Cg`
   against that ordinary RTL. The validated compiler/RTL is now installed under
   the standard toolchain's `current` link and selected by nxbuild's environment.
4. **Linux engine/plugin interaction: passed.** The real sample plugin was
   rebuilt through its migrated recipe with the promoted toolchain. The actual
   optimized engine loads it and passes the new
   `Nexus2D.PascalPlugin.ActualEngineInteraction` NXTest: 23 assertions covering
   properties, Pascal calls, local and engine Runtime events, listener removal,
   reset and retained-method lifetime across Lua garbage collection. The rebuilt
   nxbuild itself passes all 37 core NXTests with no runner heap leaks.
5. **Remaining native evidence:** native Win64 build/link/load validation is
   unavailable on this Linux machine. Linux runtime-package SDK paths remain
   unconfigured, so the retained Abbrevia runtime-package recipe has graph
   evidence only. Source Abbrevia validation is independent and passed.

The agreed Linux engine/runtime scenario is complete. Native Windows and
runtime-package SDK execution remain unverified; Linux success does not establish
those results. The accepted Mesa/EGL leak remains visible in the sanitizer tests.

## Deferred LS handoff

NexusLS generation still emits retired nxbuild root properties and an
FPCBuildOptions child, and its option-model callers refer to obsolete members.
The VS Code adapter still supplies an empty project/options context. The three
LS-dependent project-generation cases remain separate, unclaimed tests.
Checked-in descriptions were migrated; no LS implementation repair was made.

## Reproduction and review evidence

External evidence root:
`/media/kcollins/dev/worktree/nxproject-unified-wpoyr_f5`.
The initial-state file records clean heads of all seven repositories. Every
scenario evidence JSON records its complete command, selected environment,
external OutputRoot and original/restored environment hashes. No implementation
source was patched in an external copy. Compilation logs and generated products
are outside the source repositories. An ignored-artifact scan found no object,
unit, library, executable or log written in source during this pass.

Representative commands from the Nexus repository are:

```sh
"$NXBUILD" /action=validate /project=projects/nxbuild/test/nxbuildTests.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD" /action=build /project=projects/nxbuild/test/nxbuildTests.nxproject /targetos=linux /targetcpu=x86_64
"$NX_OUT/nxbuildTests/x86_64-linux/nxbuildTests"
"$NXBUILD" /action=build /project=projects/nxpackage/test/nxprojectDocumentTests.nxproject /targetos=linux /targetcpu=x86_64
"$NX_OUT/nxproject-document-tests/x86_64-linux/nxprojectDocumentTests"
```

Configure NXBUILD/NX_OUT from the recorded environment, not from an arbitrary
compiler installation. The generated native fixture README and Abbrevia test
README provide their runtime library paths and artifact identity controls.
Review covered graph identity/path ownership, cycle/failure cleanup, deterministic
ordering, read-only plan boundaries, native option insertion/link order and
target-selected provider directories. The later approved compiler change makes
PIC the Linux x86-64 default, and the validated toolchain is now selected by
nxbuild. Bootstrap processing, thread scheduling and bridge implementation remain
unchanged.


## Historical decoder interface review — before correction, 2026-10-19

At the owner's direction, reviewed the complete decoder callback interface,
its implementations and consumers, and every substantive change in upstream
Solar2D PR 866. The mobile Linux NXBUILD_REVIEW.md records the findings and
recommended corrections, including platform-specific source-review limits.
The expanded existing NXTest project builds through its real recipe and reports
1 passed / 7 failed / 0 errors or skips. It now covers the existing three ABI
failures, the missing mpg123 header configuration, and real dispatcher cleanup,
zero-size resize and invalid read-count behavior. The passing case is explicit
sample cleanup. Native sanitizer failures remain failures; no engine production
source, bootstrap or thread behavior changed. Outputs and logs are under
`nxproject-unified-wpoyr_f5/decoder-interface-review/`. The earlier three-case
results above are retained as historical evidence.


## Approved decoder correction follow-up

See the engine's [Linux review](../../../nexus-mobile/platform/linux/NXBUILD_REVIEW.md).
Final results: 22 decoder/codec cases pass; the complete run has 24 passes and
one original-application shutdown failure. The actual engine build passes in
5m23s. Commands, final artifact identity and remaining limits are in that review.
The compiler/linker blocker is resolved. The first linked simulator run exposes a
shutdown failure after entering a Lua exit callback. Decoder API-double tests,
real Linux build/runtime evidence, and unvalidated Apple/Windows SDK paths are
reported separately. Bootstrap processing remains unchanged.


## Historical shutdown diagnosis before correction

The engine review now identifies the precise freed-memory write, the new recipe's
link-order trigger, a same-object relink control, source history, and the proposed
ownership correction. A separate startup locale-string lifetime defect prevents
the ASan engine from reaching shutdown. It is preserved in the new
`Nexus2D.EngineRuntime.LocalePreferenceLifetime` regression.

With that case added: unchanged release 24 passed / 2 failed;
ASan engine 22 passed / 4 failed. All failures are retained;
both Pascal runners report equal allocated/freed block counts. No production fix or suppression
was applied. Evidence: `runtime-heap-investigation-1792416362373527003/` under the existing worktree.


## Approved lifetime corrections and next sanitizer finding

Applied the approved small ownership and locale corrections and explicit 594-file
link list. Real release build: 334.28 seconds; all 27 behavior checks pass. Both
diagnostic link orders also pass with unchanged corrected objects.

The instrumented run before the allocator correction is 22 passed / 7 failed: two newly added allocation
NXTests and five runtime cases reproduce IndexArray's malloc/delete mismatch.
The initial new-probe compile failures (missing fixture include, then omitted
C++ runtime library) are preserved in the earlier logs. A further probe configuration mistake initially produced false passes because
the C driver did not link C++ sanitizer interceptors. The corrected C++ driver
command compiles both probes and the full NXTest run reproduces the actual
mismatch. All earlier attempts are retained in the evidence.

The owner approved the one-line StringHash correction after the explanation of
why ASan reached it only after the locale fix. Rtt_FREE now matches Rtt_MALLOC;
both native regression commands pass. Final release build and all five direct
runtime scenarios pass. The full instrumented NXTest result is 24 passed / 5 failed;
the runtime cases now reach exit-time detection of console/audio cleanup leaks. See the engine review and `runtime-heap-investigation-1792417632613682760/` for before-fix evidence.
No sanitizer diagnostic was suppressed. PIC-RTL/plugin and native SDK limits
remained at this stage; the PIC/plugin work is completed in the final follow-up below.


## Final engine correction validation

Release build: 319.76 seconds, with all five runtime scenarios
passing. Full instrumented build passes. Its actual NXTest suite is 24 passed /
5 failed: the 22 decoder/codec cases and both allocation regressions pass; five
runtime cases report shutdown leaks. The direct engine runs report 252 bytes in
four allocations, traced to console ImGui backend cleanup and the unused-audio
notifier cleanup path. The immediate-exit locale test additionally reports 2,928
bytes allocated through SDL/graphics initialization; ownership remains unresolved.
Those source files remain unchanged; the failures remain
open in the existing runtime NXTests. The engine review records proposed bounded
corrections and source-history evidence. These results do not establish a clean
sanitizer run or complete the whole migration.

Final evidence: `runtime-heap-investigation-1792419607458224576/final-validation-summary.json` under the external
worktree. Recipe/environment restoration and executable hashes are recorded there
and in the associated build evidence.


## Runtime leak investigation follow-up

The five failing runtime tests share two engine cleanup defects: console/backend
teardown occurs incompletely and after SDL_Quit, and the unused-audio path leaks
its notifier. A matched audio control removes exactly 36 leaked bytes when audio
is initialized; 216 console/backend bytes remain.

The extra 2,928-byte graphics leak reproduces in an EGL-only program with no
engine or SDL code, and grows to 14,640 bytes across five load/unload cycles.
Added Nexus2D.EngineRuntime.EGLDisplayCleanup to preserve it as an actual NXTest.
The expanded suite is 24 passed / 6 failed: the original five plus that independent
reproduction. No production repair or system-library change was applied in this
investigation. The engine review records the concrete three-file engine cleanup
recommendation, constraints on dialog/runtime teardown order, evidence and the
remaining uncertainty within the Mesa/GLVND implementation.


## Approved console/window and unused-audio cleanup completed

Both engine fixes are implemented in their actual production source and validated
through nxbuild. Window backends and GL contexts are released before SDL_Quit;
dialogs are released while their runtime is alive. The audio notifier is released
when audio was never initialized, preserving initialized-audio shutdown order.

Added InitializedAudioCleanup and DialogCleanup NXTests; both fixtures reproduced
leaks in the saved unmodified engine before passing with the corrected engine.
Final sanitizer result: **30 passed / 2 failed**. The only remaining failures are
EGLDisplayCleanup and LocalePreferenceLifetime, each reporting the same installed
Mesa/EGL leak of 2,928 bytes in three allocations. The owner explicitly accepted
that leak for now. No graphics workaround, suppression, test skip or vendor change
was made; further investigation/repair is not pending in this task.

The final optimized build and all **seven runtime scenarios pass**. Debugger
traces match every created GL context to its deletion before SDL_Quit, with the
appropriate ImGui contexts selected. Recipe/environment restoration hashes match.
Evidence: `engine-cleanup-fix-1792422634245985635/` and
`runtime-heap-investigation-1792422642827040081/` under the external worktree;
full details are in `../nexus-mobile/platform/linux/NXBUILD_REVIEW.md`.


## Final PIC toolchain and engine/plugin acceptance — 2026-10-19

The approved `tf_pic_default` addition applies to Linux x86-64. The stock FPC
3.2.2 seed completed the unchanged three-generation bootstrap in 99.85 seconds.
Generation 2 and generation 3 compilers match byte-for-byte, as do all 89 RTL
objects. Windows and i386 defaults were not changed. The new shared-library
regressions proved the missing default against the previous compiler before the
corrected compiler passed all 13 cases, including explicit `-Cg-` opt-out.

The owner approved promotion to the standard toolchain. All 199 installed files
were hash-verified, and `toolchain/nexus-fpc/x86_64-linux/current` now selects
`030c3ad17f-work-abcb55437e`. The previous installation is retained. nxbuild's
Linux environment uses this `current` compiler and RTL. Post-installation checks
again passed all 13 library cases and rebuilt the actual sample plugin.

Final integration used the unchanged, previously validated optimized engine and
rebuilt nxbuild, its core tests, the sample plugin and the new plugin test runner
from their actual source recipes with the promoted compiler. Results:

| Check | Result |
| --- | --- |
| nxbuild self recipe | Builds successfully |
| nxbuild core NXTests | 37 passed; no failures/errors/skips or runner heap leaks |
| Actual `plugin_sample.nxproject` | Builds and links successfully |
| Plugin artifact | ELF64 x86-64 shared object; `luaopen_plugin_sample` exported; no TEXTREL |
| Real engine/plugin NXTest | 1 passed; no failures/errors/skips; all 23 Lua assertions pass |
| Engine identity | Matches the previously validated optimized executable exactly |
| Compiler environment restoration | Original and restored SHA-256 values match |

The plugin test uses the real dynamic library and engine APIs. It checks string
and floating-point properties, signed integer and string-returning calls,
function/table/self-removing listeners, Lua-to-Pascal dispatch, Pascal-to-engine
Runtime dispatch, reset and a detached method retaining its object across garbage
collection. A real engine timer emits the success marker after these checks.
This is behavioral integration coverage, not a new sanitizer/leak-clean claim.
The runtime log retains diagnostics about optional application settings/resources
absent from this minimal fixture; the process exits successfully with the marker.

Evidence roots, all outside source:

- `/media/kcollins/dev/worktree/linux-x64-pic-default-zmhh4fjf`: bootstrap,
  before/after default regressions and toolchain evidence.
- Its `promotion-xu768d4o/` directory: installed-file hashes, promotion record,
  post-installation shared-library checks and initial plugin artifact inspection.
- `/media/kcollins/dev/worktree/nxproject-final-plugin-zb9y870c`: final commands,
  durations and statuses in `results.json`; build/test logs;
  `runtime/pascal-plugin-runtime.log`; ELF inspection in `plugin-artifact.log`;
  binary hashes in `artifact-evidence.json`; and environment restoration in
  `environment-evidence.json`.

Reproduce from the Nexus repository with the configured standard toolchain,
`NXBUILD` naming the rebuilt nxbuild, `NX_OUT` matching `Tools.OutputRoot` under
the external worktree, and `SIMULATOR` naming the actual built Linux engine:

```sh
"$NXBUILD" /action=build /project=../nexus-lab/examples/mobile/pascal-plugin/plugin_sample.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD" /action=build /project=projects/nxbuild/test/nxbuildPluginTests.nxproject /targetos=linux /targetcpu=x86_64
"$NX_OUT/nexus2d-plugin-tests/x86_64-linux/nxbuildPluginTests" \
  "$SIMULATOR" "$NX_OUT/plugin_sample/x86_64-linux/libplugin_sample.so" \
  "$NX_OUT/plugin-runtime" \
  "$PWD/projects/nxbuild/test/fixtures/engine-runtime-pascal-plugin/main.lua"
```

The runner selects SDL's offscreen driver and OpenAL's null driver and applies a
20-second timeout. It saves the complete engine output and requires both success
exit status and the assertion-completion marker. The deferred LS handoff and the
native validation limits above remain unchanged. No implementation commit or
push has been made.
