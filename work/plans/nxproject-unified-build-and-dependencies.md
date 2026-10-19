# Work Plan: Unified nxproject Architecture and Dependency-Aware nxbuild

Status: Owner-authorized implementation in progress.
Date: 2026-10-19.
Planning verification was source inspection. Implementation builds and tests are recorded separately.

## Inputs

- Owner's request and `/home/kcollins/Downloads/nxproject-unified-build-and-dependencies.md`.
- Owner clarifications: migrate in-scope nxbuild descriptions/scripts, defer LS work to the planned LS overhaul, and compile and test actual Solar2D integration on Linux.
- `AGENTS.md`, `projects/nxbuild/AGENTS.md`, `projects/nxpackage/AGENTS.md`, `.ai/protocols/architecture-change.md`, and `.ai/protocols/codex-workplan-format.md`.
- Source inspection underlying the original plan: Nexus `7e082536e7d3`; nexus-packages `331bfca0a5c6`; nexus-packages-ext `bbe61fcb0a11`; nexus-packages-apple `55e95914bee0`; nexus-lab `cf6922a396a8`; nexus-mobile `fed1539cc1fb`; nexus-fpc `030c3ad17f45`. Linux engine CMake targets were rechecked during planning. These are local-source findings, not claims about uninspected remote revisions.

The owner's clarifications govern this revision where they narrow or correct the supplied request. The compiler naming goal remains paused.

## Summary

Make `nxproject` the single universal entity understood by nxbuild. Every project may require other projects, publish directories and perform build operations, regardless of whether it produces an application, library, tool or source materials. nxbuild resolves the full dependency graph, inherits all published directory categories and builds required producers before consumers.

Migrate the existing nxbuild descriptions and scripts within this project's scope. Record LS integration issues for its planned overhaul instead of repairing that subsystem here. Validate the resulting system with real Abbrevia consumers, mixed FPC/LLVM builds and an actual Linux Solar2D engine/integration build.

The required results below are binding. Suggested syntax, internal structures and implementation mechanisms are proposals that may be replaced by simpler equivalent solutions. They are not additional acceptance requirements.

## Verified Findings

### Current nxbuild path

| Source | Confirmed behavior |
| --- | --- |
| `projects/nxbuild/language/nxbuild.Language.nxscript` | Project and Package repeat the same roots and FPC/LLVM children. Neither has requirements or publications. |
| `projects/nxbuild/src/obNXBuildCommands.pas`, `TNXBuildCommands.Execute` | Selects TargetOS/TargetCPU, calls LoadDescription, then CreatePlan, then WritePlan or Execute. |
| `obNXBuildDescriptionLoader.pas`, `LoadDescription` / `NXBuildAssignDefinition` | Uses NexusScript analysis, validation and native Live output; accepts one Project or Package root; assigns properties/build entries; resolves paths. Its generic string-array assignment does not load a dependency graph. |
| `obNXBuildDescription.pas` | Holds kind, filename, roots and builds, without identities, requirements or publications. |
| `obNXBuildPlanner.pas`, `CreatePlan` | Rejects zero-operation descriptions and makes steps for a single description in declaration order. There is no dependency graph or aggregation. |
| `obNXBuildExecutor.pas` | Expands masks at execution, prepares output directories, invokes tools synchronously and stops on the first failure. |
| `obNXBuildEntry.pas` | Resolves paths against the description's root. Source masks expand separately at execution. A missing OutputPath currently defaults to that root. |
| `obNXFPCBuildOptions.pas` | UnitPaths -> `-Fu`; IncludePaths -> `-Fi` and `-I`; ObjectPaths -> `-Fo`; LibraryPaths -> `-Fl`. Compiler-native package options are separately authored. |
| `obNXLLVMBuildOptions.pas` | IncludePaths -> `-I`; SystemIncludePaths -> `-isystem`; LibraryPaths -> `-L`; Libraries -> `-l`. Sources precede libraries. No explicit object-input collection exists in this model. |
| `packages/nexus-packages/nxscript/src/obNexusScriptLive.pas` | Provides native definitions, reference targets and original source ranges. These mechanisms can represent concise project references without a new reference parser. |

Unqualified nxbuild unit names in the table are under `projects/nxbuild/src/`.

### Publication metadata and real consumers

- `projects/nxpackage/language/nxpackage.Language.nxscript` separately defines Package metadata, requirements and path publication; its Project root excludes development path publication. The associated validator checks catalog/reference contracts but does not resolve or build dependencies.
- `projects/nxbuild/nxbuild.nxproject` manually lists NexusScript, serialization, Core, SQLite, Mustache and other dependency paths. Meanwhile NexusScript's `Package.nxscript` declares several of those requirements without publishing source directories. FCLProcess metadata already declares FCLBase. These provide real migration and transitive-dependency cases.
- Abbrevia lives under `packages/nexus-packages-ext/compression/abbrevia`. The lab `examples/build/native/Abbrevia.nxpackage` uses nxbuild and orders codec-object, bzip2-library and `.nxpk` builds. This is the existing nxbuild recipe to consolidate with its nxproject publication contract.
- The Solar2D descriptor under `packages/nexus-packages/solar2d` describes the Pascal plugin bridge and refers to Lua. It does not describe or build the engine. Lua metadata also does not supply a Lua host/runtime.
- The actual engine source is in sibling `../nexus-mobile`. Its root CMakeLists selects `platform/linux/CMakeList.txt` on Linux. That file defines actual `Solar2D`, `Solar2DSimulator` and `Solar2DBuilder` executable targets and native dependency checks. Existence of these targets is not proof they currently compile.
- The Win64 engine has a separate MSBuild solution. Its native prerequisites and generated output locations must be understood before validating that target.
- The lab's `examples/mobile/pascal-plugin/plugin_sample.nxproject` repeats Lua, bridge and other dependency paths; its Win64 linking options name `CoronaLabs.Corona.Native.lib`. Library filenames remain normal link intent; dependency directories should be inherited.
- The existing environment module supplies target-specific FPC/LLVM/SDK settings. Its machine-specific installation paths and relative common OutputRoot need careful interpretation when publishers live at different directory depths.

### LS findings retained for the later pass

NexusLS project generation still emits retired fields and an FPCBuildOptions child. Three nxbuild project-generation cases depend on that LS path. NexusLS tests also reference obsolete options-model members. The VS Code adapter currently supplies an empty projectFile/options context for code intelligence.

These are verified affected integrations, but fixing LS generators, LS option-model callers, VS Code language-server context or adding an editor plan-query interface is deferred at the owner's direction. Report their status separately; do not count them as passing or silently repair them during nxbuild implementation. Checked-in build recipes consumed by nxbuild still receive required descriptor migration.

### Inventory and migration classification

The earlier read-only inventory included nested repositories and source directories such as `examples/build`, and excluded Git metadata and generated output/cache directories. It includes test fixtures; it does not assert that every file is a live build or builds successfully.

| Area | `.nxproject` | `.nxpackage` | `Package.nxscript` | Index-root documents |
| --- | ---: | ---: | ---: | ---: |
| Nexus, excluding the three nested package repositories | 29 | 0 | 0 | 2 |
| nexus-packages | 40 | 16 | 32 | 1 |
| nexus-packages-ext | 1 | 0 | 3 | 1 |
| nexus-packages-apple | 0 | 3 | 3 | 1 |
| nexus-lab | 26 | 2 | 1 | 3 |
| nexus-fpc | 14 | 0 | 0 | 0 |
| **Total** | **110** | **21** | **39** | **8** |

There are 131 descriptions declaring nxbuild's dialect and 47 declaring nxpackage's dialect; these overlap the table. These totals are inspection inventory, not migration quotas or authorization to expand this project's scope.

The 21 legacy nxbuild `.nxpackage` files cover sixteen first-party library builds, three Apple library builds and the lab's Mixed/Abbrevia examples. Migrate these to the universal contract and establish one authoritative nxbuild description per project. Use existing metadata as evidence without broadening the migration beyond nxbuild's own descriptions and required providers.

## Architecture Problem

Nxbuild lacks a project-level publication/dependency contract and a single owner for resolving it. Explicit consumer paths compensate for that gap and make transitive dependencies and producer scheduling manual.

Correct the nxbuild model and its consuming inputs through one dependency-resolution path, rather than independent traversal logic for each compiler or consumer.

## Target Contract

### Required outcomes

1. **One nxbuild entity:** nxproject has identity, optional metadata, requirements, categorized directory publications, operations and normal target/toolchain settings. Source-only projects with no operations are valid. Output kind introduces no separate dependency rules.
2. **Declarative dependencies:** consumers identify required projects rather than their resource directories. Discovery is explicit and deterministic; missing and cyclic dependencies have useful diagnostics.
3. **Full inheritance:** every dependency contributes all published categories recursively. No import selection or re-export declarations. A shared diamond dependency builds once for the same required build context.
4. **Publisher-owned paths:** relative publications resolve against their publisher, and descriptor locators against their declared discovery context. Selected target/configuration must remain consistent through the graph.
5. **Producer scheduling:** generated and existing directories share one publication contract. Required producers run before consumers. Failures identify the producer, preserve failure information and prevent dependent execution.
6. **Read-only planning:** plans expose the graph, resolved categorized directories and relevant operations/options without building producers or creating outputs. Directories produced by a dependency need not already exist.
7. **Toolchain consumption:** operations receive applicable inherited directories centrally. Explicit local and SDK settings retain their genuine purposes. Compiler-native `.nxpk`/`.nxpl`, SDK identities, RequiredPackages and associated flags remain independent.
8. **Complete in-scope nxbuild migration:** adapt the affected nxbuild descriptions/scripts and required provider descriptions. Consolidate duplicate nxbuild definitions and remove rejected nxbuild paths/models within this project's scope.
9. **Real validation:** actual Abbrevia and mixed compiler builds plus actual Linux Solar2D engine/integration compilation and execution evidence. Graph tests alone do not satisfy the native build requirement.

### Ownership and state flow

The project definition owns authored identity, requirements, publications and operations. One shared nxbuild resolution/planning path loads projects, resolves the closure, aggregates directories and schedules operations. FPC/LLVM option generation consumes that resolved environment. The executor consumes the plan and runs required operations in order; it does not rediscover dependencies.

Use the existing NexusScript compiler and native Live analysis/reference facilities. Preserve source provenance for diagnostics and path interpretation. Keep loaded data and plans valid for their actual lifetimes. These responsibilities do not prescribe particular class names, allocation structures or unit boundaries.

### Resource and path semantics

Begin with directories for source/unit lookup, headers/includes, objects and libraries. The existing FPC `-Fu`, `-Fi`/`-I`, `-Fo`, `-Fl` mappings and LLVM `-I`, `-L` mappings provide concrete integration points. System headers keep their existing system-header meaning. A source directory does not mean compile every file in it.

Do not perform spelling-based substitutions: UnitPaths on a publisher means exported lookup locations, while the same-named compiler field can express local or SDK configuration. SourceFiles are compilation inputs; OutputPath is a destination; root settings establish context. Classify existing Outputs entries by their real use rather than treating file paths as published directories.

A directory does not tell a linker which object or library to link. Preserve explicit filenames/library names and existing Pascal link directives as operation-level link intent. If an operation needs additional explicit object inputs, address that concrete need within the operation. Do not turn publication into a file manifest.

Use deterministic traversal and directory deduplication appropriate to the platform. Preserve explicit linker input order/repetitions. No new collision policy or author-facing precedence controls are needed.

### Candidate approaches, not additional requirements

- Retain a single `Project` root for nxbuild and add identity, Requires and publications. A renamed dialect file, wholesale class renaming or a renamed workbench executable is not necessary merely to express nxproject.
- Use existing NexusScript module/reference syntax and explicit project catalogs to locate requirements. The exact record names, catalog binding and CLI syntax remain implementation choices.
- Initially run each required project's operations once per invocation and let existing native builders handle their own incremental work. This is a simple freshness policy, not a prerequisite cache framework.
- Let one configured external output location feed target/project destinations. Exact context binding and directory layout should follow existing toolchain configuration where practical, without embedding a checkout path in every consumer.
- Adapt the existing process execution path to invoke a real native builder when necessary. Whether that needs a small new operation or another existing mechanism should follow the actual engine build, not a prescribed process framework.
- Keep the existing editing workbench useful where practical by letting it inspect/edit the nxbuild dialect and use nxbuild's validation for that contract. Avoid an application rename or GUI redesign unless actually needed.

Choose the smallest coherent solution meeting the required outcomes. If a proposed mechanism proves unnecessary, omit it and explain the simpler choice. Discuss a material contract change or encountered blocker rather than silently changing the objective.

### Illustrative descriptors

The following is proposed syntax, not installed or required spelling. The toolchain module supplies configured paths and an external output root. Catalog references identify projects; they do not wire resource paths into consumers.

```nexusscript
// Provider's own nxbuild descriptor.
Project Abbrevia {
    Id: "NXRP.Compression.Abbrevia";
    Publishes Directories {
        Sources: ["external/abbrevia/source"];
        Headers: ["external/abbrevia/source"];
        Objects: [@Abbrevia.OutputRoot + "/native"];
        Libraries: [@Abbrevia.OutputRoot + "/libraries"];
    }
    // Actual native codec build operations and target/output settings.
}
```

```nexusscript
module Projects "Projects.nxscript";
Project ArchiveApplication {
    Id: "Local.ArchiveApplication";
    Requires: [@Projects.Abbrevia];
    FPC Application {
        SourceFiles: ["ArchiveApplication.lpr"];
        // Normal compiler/output settings; no Abbrevia directory list.
    }
}
```

```nexusscript
// Three separate descriptors; module/dialect/toolchain declarations omitted.
Project Nexus2DIntegration {
    Id: "NXRP.Nexus2D.Integration";
    Requires: [@Projects.Solar2DBridge, @Projects.Nexus2DEngine];
}
Project Solar2DBridge {
    Id: "NXRP.Solar2D";
    Requires: [@Projects.Lua];
    Publishes Directories { Sources: ["src"]; }
}
Project Nexus2DEngine {
    Id: "NXRP.Nexus2D.Engine";
    // Actual target-selected engine build and verified published directories.
}
```

Integration receives Lua's directories transitively through the bridge, along with the engine's publications and all further dependencies. The engine project points to the actual available nexus-mobile source, not a fictitious host path. Exact engine directories follow inspection of its real build outputs.

## Scope

| Area | Planned correction |
| --- | --- |
| nxbuild dialect/model/loading | One project contract; requirements/publications and valid zero-operation projects; source-aware loading using existing NexusScript facilities. |
| Graph/planner/CLI | Explicit discovery, complete closure, diagnostic chains, resolved categories, target consistency and dependency-first plans. Preserve read-only plan behavior. |
| FPC/LLVM option generation | Consume inherited paths centrally; preserve local/toolchain/compiler-package semantics and actual linker input requirements. |
| Execution/native build integration | Producer-before-consumer scheduling, useful failures, real native tool invocation and external output handling. No concurrency changes. |
| Existing nxbuild scripts/descriptors | Migrate affected in-scope consumers across Nexus, nested package repositories, lab and compiler test recipes. |
| Providers/catalogs | Establish authoritative nxbuild publications/requirements and discovery entries. Review existing metadata as evidence for the new contract. |
| Workbench/discovery surfaces | Make only changes needed to consume the new nxbuild contract; do not require a GUI rename. |
| Tests/docs | Update actual nxbuild coverage, fixtures, examples and documentation. Record LS work for its later pass. |

### Abbrevia

Consolidate the nxbuild recipe and its directory publication in the provider's source location, and migrate the lab/test consumers to requirements.

Preserve source/static consumption and existing compiler-native runtime-package capability. A source consumer should not gain an unnecessary package-SDK prerequisite. A separate ordinary runtime-package producer requiring the source/native provider is one possible arrangement, not a mandatory project split.

### Solar2D on Linux and Windows

Describe the actual engine as an ordinary dependency alongside Lua and the Pascal bridge. Add the required nxbuild descriptions and integration.

On Linux, express the actual engine build directly through nxbuild LLVM/Process operations and any necessary task types. Existing native recipes are reference material for source lists, generation and tool options. Compile the engine targets needed by the scenario, compile/link the Pascal integration against their actual outputs, and run a meaningful host/plugin scenario. Inspect required native libraries, generated inputs and output locations before selecting commands. Merely invoking a no-op command, using a stub engine, inspecting a graph or compiling only the bridge is insufficient.

Use existing native build machinery where it fits, with generated files under the external worktree. Do not prescribe a source snapshot, rewrite prerequisite scripts or introduce acquisition machinery before proving it is necessary. If missing prerequisites, engine defects or native output handling block the build, investigate and report the concrete problem for discussion; do not silently weaken verification or start an unrelated engine repair.

Retain the original Win64 engine/integration requirement using the actual available solution and tools. Linux success does not prove Win64 success, or vice versa. Report platform-limited evidence explicitly; native Windows validation availability does not remove the required Linux build.

## Out Of Scope

- LS/NexusCode integration repairs: generated-project logic, obsolete model callers, code-intelligence dependency propagation, new query interfaces and their associated acceptance tests. Record them for the planned LS overhaul.
- Compiler/RTL changes, compiler package formats or flags, codec changes, new threads, speculative caches/categories, dependency downloads/version solving/trust redesign, resource filters/re-exports and collision registries.
- Broad workbench redesign, mandatory application/type renaming, or native engine build-system replacement without a demonstrated requirement.
- Resuming the paused compiler naming goal.

## Staged Implementation Plan

1. **Confirm scope and baseline.** Record the in-scope nxbuild descriptions and required providers that must migrate. After implementation authorization, run the relevant existing nxbuild tests and real build baselines; report failures. Inspect the actual Linux engine prerequisites/build before choosing its integration mechanism.
2. **Correct the nxbuild contract.** Add universal project identity, requirements and directory publications; allow no-operation providers. Use the existing parser/Live model and retain useful operation settings. Build the new nxbuild using the existing toolchain/self-build path; do not introduce compiler bootstrap changes.
3. **Resolve and plan complete graphs.** Implement deterministic discovery, missing/cyclic dependency diagnostics, target-aware publisher-relative paths, all-category inheritance and dependency-first scheduling. Expose resolved environments in plans without executing producers or creating outputs.
4. **Connect options and execution.** Apply applicable inherited paths to FPC/LLVM, handle actual linker inputs and native builder invocation, and propagate producer failures. Verify generated inputs, diamond deduplication and operation order without adding concurrency or a cache framework.
5. **Migrate affected in-scope nxbuild inputs.** Consolidate nxbuild providers and adapt consumers, catalogs, examples and checked-in build descriptions. Remove manual dependency-directory repetition and obsolete nxbuild execution models within this project's scope. Document LS deferral.
6. **Validate real scenarios.** Build/run Abbrevia and mixed FPC/LLVM consumers, nxbuild itself and its focused tests, then the actual Linux engine plus Pascal integration. Gather Win64 evidence using its real builder where available. Any blocker remains a reported blocker; it does not become a substitute acceptance test.
7. **Review and finish.** Check every required migration, remove unused nxbuild-only machinery, update documentation and review source/output cleanliness. Report exact commands/results, unresolved failures and deferred LS work. Implementation completion requires the agreed build/runtime evidence, including Linux Solar2D.

These stages lead to one final nxbuild architecture, not an indefinite dual system. Particular class names, CLI switches or staging methods are not stage gates.

## Sub-Agent Delegation

Implementation remains local. No sub-agent use is authorized by this request or this plan; later implementation approval alone does not authorize delegation.

## Verification Plan

All builds/tests below are future work after implementation approval. Use NXTest for new regressions, real checked-in inputs and external worktree outputs. Do not alter copied source or test expectations to turn a failure into a pass.

### Focused NXTests

- Universal projects publish every supported directory category regardless of output kind, including no-operation providers. Retired nxbuild Package execution behavior is removed.
- Direct, transitive and diamond requirements inherit all categories. A shared producer builds once for the same context. Missing identities/descriptors, cycles and inconsistent target contexts have useful diagnostics before dependent execution.
- Publisher-relative paths work with different roots, nested catalogs/modules, spaces and target-selected directories. Directory deduplication does not remove required explicit linker argument repetitions.
- A real producer creates initially absent headers/source/objects/libraries. Consumers run afterward with those directories. Producer failure preserves its code and prevents a consumer marker. Planning creates no marker, output directory or producer process.
- FPC/LLVM receive the applicable inherited categories with the current verified switches. Sources are not indiscriminately compiled; ordinary headers are not silently made system headers. Explicit compiler-native package options retain their meaning and are not inferred from project requirements.
- Retain useful existing option, source-mask, ordering, tool-failure and output tests. Adapt nxbuild fixture strings to the new contract. Document the LS-dependent generation cases as deferred rather than treating them as passing or repairing LS to obtain a green total.

### Real migration/build evidence

1. **Abbrevia direct consumer:** require Abbrevia without repeating any provider directory. Build and run compression/decompression using the required real codecs. Save the consumer descriptor hash and resolved compiler paths.
2. **Publisher change:** change only the provider's published source directory to a real equivalent input location. Re-plan/build and prove the consumer's resolved paths change while its descriptor hash is unchanged. Do not patch implementation code to hide failure.
3. **Transitive consumer:** rebuild nxbuild and its NXTests from migrated descriptions. Show that transitive Core/serialization/Mustache or other real requirements supply their paths through providers rather than copied consumer lists.
4. **Mixed native/Pascal:** build a real Clang producer and FPC consumer; exercise a native link needing explicit object inputs and generated headers/source. Prove producer ordering, target agreement and failure handling.
5. **Linux Solar2D:** compile the actual engine targets required for the host scenario, compile/link the Pascal integration using resolved dependencies, and execute a host/plugin interaction with observable assertions. Save builder/compiler logs, binary architecture/linkage evidence and runtime results. Graph-only tests or bridge-only builds cannot satisfy this requirement. Report any display/runtime-environment blocker honestly; do not substitute an unrelated smoke test.
6. **Win64 Solar2D:** use the actual native solution/toolchain and verify engine -> integration build/link/load behavior. Keep this evidence distinct from Linux validation and state any unavailable native coverage explicitly.

### Commands and review expectations

Use the existing installed nxbuild and configured NexusFPC/LLVM tools, then the newly built nxbuild for migrated inputs. The previously inspected Linux nxbuild executable is under `../../worktree/nexus/nxbuild-next/x86_64-linux/`; its presence is not validation. Representative commands from the Nexus repository are:

```sh
"$NXBUILD" /action=plan /project=projects/nxbuild/nxbuild.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD" /action=build /project=projects/nxbuild/nxbuild.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD" /action=build /project=projects/nxbuild/test/nxbuildTests.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD_TESTS"
```

For Linux native engine integration, invoke `../nexus-mobile/Nexus2DEngine.nxproject`
through nxbuild. Its LLVM and Process operations compile the native tools, generate
embedded Lua sources and compile/link the actual simulator under the configured
external output root. Native development-library provisioning is documented in
`nexus-mobile/platform/linux/README.md`; system installation is separate from
build execution.

Review actual nxbuild dialect references across nested package repositories, lab and compiler descriptions. Confirm all affected in-scope nxbuild scripts are migrated and consumer resource paths disappear where requirements replace them. Update relevant docs, check generated-output locations and record exact native/test commands in the implementation report.

No LS test-module build, TypeScript compilation, LS project-generation repair or new editor query endpoint is an acceptance gate for this pass. Preserve a clear handoff listing those known integrations for the later LS work.

## Risks And Questions

The universal entity, complete inheritance, producer scheduling, in-scope nxbuild-input migration, LS deferral and actual Linux engine validation are settled. Remaining choices are narrow:

- **Discovery representation:** prefer existing NexusScript references/catalog capabilities. Choose the simplest explicit local resolution mechanism that meets the graph requirements; exact catalog records and CLI syntax are not preapproved obligations.
- **Path/output context:** preserve publisher-relative meaning and select an external target-specific output location. Resolve the current environment module's relative output settings consistently, without forcing new machine paths into consumer descriptions.
- **Native link intent:** directories alone do not select objects/libraries. Retain explicit normal link intent and add only the operation capability proven necessary by the real mixed/engine builds.
- **Engine build health/prerequisites:** actual source/build targets exist, but current compilation and runtime health have not been demonstrated by planning inspection. Investigate and discuss concrete failures before deciding whether additional repair or provisioning is authorized.
- **Inventory versus scope:** neither the inventory nor a general migration statement authorizes expanding this project's scope. Migrate nxbuild descriptions and the providers needed by the agreed scenarios.

## Approval Gate

The owner authorized implementation in the conversation. Later clarification requires direct nxbuild task execution for the native engine. LS work remains deferred. Problems and unrelated repairs must be investigated and discussed; they must not be bypassed to obtain passing results.

If implementation reveals a material conflict with this scope or a blocking bug, investigate and discuss the facts instead of silently broadening the work, bypassing the problem or weakening acceptance. The paused compiler naming goal remains paused.
