# Work Plan: Unified nxproject Architecture and Dependency-Aware nxbuild

Status: Proposed; implementation requires direct owner approval.
Date: 2026-10-18.
Planning verification: source inspection only; no builds, tests, applications, or migration executed.

## Inputs

- Owner's conversation request to read the supplied document and provide a work plan/commentary.
- `/home/kcollins/Downloads/nxproject-unified-build-and-dependencies.md`, including its twelve binding architectural decisions and eventual acceptance criteria. This is planning input, not implementation authorization.
- `AGENTS.md`, `projects/nxbuild/AGENTS.md`, `projects/nxpackage/AGENTS.md`, `.ai/protocols/architecture-change.md`, and `.ai/protocols/codex-workplan-format.md`.
- Live source in Nexus and its locally available package, lab, mobile, and compiler repositories. The separate compiler naming goal remains paused.

Inspection revisions: Nexus `7e082536e7d3`; nexus-packages `331bfca0a5c6`; nexus-packages-ext `bbe61fcb0a11`; nexus-packages-apple `55e95914bee0`; nexus-lab `cf6922a396a8`; nexus-mobile `fed1539cc1fb`; nexus-fpc `030c3ad17f45`. Findings concern these local working trees; no claim is made about uninspected remote revisions.

## Summary

Replace the two incomplete description contracts with one `Project` contract in a canonical `nxproject` dialect. Every project has the same identity, requirements, directory publication, target selection, and ordered build-operation capabilities, including projects with no operations. `nxbuild` resolves one complete project graph, creates dependency-first plans, and executes those plans sequentially.

Keep catalog records as descriptor locators and keep the editing workbench as an editor. Neither is another kind of build entity. Remove the obsolete Package execution root and duplicate package publication contract. Preserve compiler-native NexusFPC package options and formats.

This is a complete migration, including real providers, consumers, editor generators, and tests. It is not an optional resolver layered on the current split. Forge execution and dialect reconciliation are deferred explicitly; they do not dictate the corrected nxbuild model.

## Verified Findings

### Current call paths and responsibilities

| Verified source | Present behavior and required correction |
| --- | --- |
| `projects/nxbuild/language/nxbuild.Language.nxscript`, definitions `Project`, `Package`, `FPC`, `LLVM` | Project and Package repeat the same root properties and FPC/LLVM children. Neither root exposes identity, requirements, or publications. Replace with one Project root, retaining operation-specific settings. |
| `projects/nxbuild/src/obNXBuildCommands.pas`, `TNXBuildCommands.Execute` | Creates TargetOS/TargetCPU selections, calls `LoadDescription`, then `CreatePlan`, then either `WritePlan` or `Execute`. This is the CLI entry for a single shared resolution/planning path. |
| `obNXBuildDescriptionLoader.pas`, `LoadDescription` / `NXBuildAssignDefinition` | Runs NexusScript analysis/validation, emits native Live output, demands exactly one Project or Package root, assigns RTTI properties and FPC/LLVM children, resolves paths, and frees the analysis/Live document. New requirements need typed reference handling before these objects are freed; the present generic string-array assignment is insufficient. |
| `obNXBuildDescription.pas`, `TNXBuildDescription` | Stores Kind, filename, root/source/output roots and builds. Has no project identity, dependency model, or publication collections. |
| `obNXBuildEntry.pas`, `ResolvePath` / `ResolvePaths` | Resolves relative paths against the description's RootDirectory. Defaults a missing operation OutputPath to that root. Source masks are expanded separately at execution. Preserve publisher ownership and stop relying on a default that can put generated files in source. |
| `obNXBuildPlanner.pas`, `CreatePlan` | Rejects zero-build descriptions, checks source lists and installed tools, and creates one step per operation in declaration order. No graph, closure, context, or producer scheduling exists. Source masks remain unexpanded during planning. |
| `obNXBuildExecutor.pas`, `Execute` / `ExecuteStep` / `ExecuteInvocation` | Expands masks per step, creates OutputPath, launches TProcess synchronously and stops on failure. Retain these useful execution boundaries; add project attribution and graph ordering rather than another executor. |
| `obNXFPCBuildOptions.pas`, `TNXFPCFileOptions.AppendArguments` | UnitPaths -> `-Fu`; IncludePaths -> both `-Fi` and `-I`; LibraryPaths -> `-Fl`; ObjectPaths -> `-Fo`. These are actual existing mappings, not interchangeable properties. |
| Same file, `TNXFPCBuildOptions.AppendArguments` / `ResolvePaths` | Adds SDK/build identities `-Fj`/`-Fk`, RequiredPackages `-FP`, output paths `-FE`/`-FU`, raw options, and other sections. These compiler-package settings are independent of project dependencies. |
| `obNXLLVMBuildOptions.pas`, `AppendArguments` | IncludePaths -> `-I`, SystemIncludePaths -> `-isystem`, LibraryPaths -> `-L`, Libraries -> `-l`; sources are inserted before libraries. Object build uses `-c`. There is no LLVM object-search-directory switch or explicit object-input collection in this model. |
| `projects/nxpackage/language/nxpackage.Language.nxscript` | Package defines metadata, Requires and publication arrays. Project reuses metadata/Requires/Outputs but excludes UnitPaths, IncludePaths and LibraryPaths. Neither permits build operations. |
| `projects/nxpackage/src/obNXPackageContractValidator.pas` | Requires references LocalPackage/ExternalPackage records from one imported index. Checks index membership, relative descriptor syntax, and repository associations. Does not open required descriptors, verify identity agreement, resolve a dependency graph, aggregate paths, or build producers. |
| `obNXPackageDocument.pas` / `uiNXPackageMain.pas` | Document validates analysis plus the separate contract validator. GUI already delegates edits, dirty state, undo and save to TNXScriptEditor. Keep that ownership; replace contract checks with the canonical project/catalog service. |
| `packages/nexus-packages/nxscript/src/obNexusScriptLive.pas` | Native Live values expose definitions/references and source ranges. The owned snapshot has non-owning navigation/reference links. Use these mechanisms, not JSON conversion, text substitution, or a second reference parser. |

All nxbuild source filenames above are under `projects/nxbuild/src/` unless otherwise stated.

### Real providers and consumers

- Abbrevia's authoritative catalog location is **`packages/nexus-packages-ext/compression/abbrevia`**, not the first-party package repository. Its `Package.nxscript` is currently a Forge recipe with metadata, published output/unit/include/library paths, Windows installation literals and source-tree output paths. It cannot simply be loaded by current nxbuild.
- `../nexus-lab/examples/build/native/Abbrevia.nxpackage` is a different nxbuild recipe for the same library: native codec objects, bzip2 shared library, then the NexusFPC `.nxpk` runtime-package build. It repeats the provider's build facts elsewhere and explicitly wires native object directories into FPC. Consolidate ownership rather than retaining both as authoritative descriptions.
- `packages/nexus-packages/nxscript/Package.nxscript` declares Core, SQLite, DelimitedText, JSON, FCLJSON and Mustache requirements but publishes no source paths. The actual `projects/nxbuild/nxbuild.nxproject` hardcodes those source locations and others in its compiler paths. This is a direct real migration case: require NexusScript and the other actual direct dependencies, then inherit their complete closures.
- `packages/nexus-packages/fcl-process/Package.nxscript` already declares FCLBase, providing a real transitive edge to retain. Many other metadata-only providers still lack directory publications; migration must populate them from real source and consumer usage, not just rename files.
- `packages/nexus-packages/solar2d/Package.nxscript` is the **Pascal plugin bridge** and requires Lua. It explicitly says consumers supply a matching host. `lua/Package.nxscript` similarly bundles no Lua runtime; its comments identify platform-dependent LibFFI needs not yet represented as complete project dependencies.
- The **actual engine is present** in sibling `../nexus-mobile`, including `librtt/`, `platform/windows/Corona.Simulator.sln`, and `Nexus2D.Win64.Forge.nxscript`. No `.nxproject` describes it. Its existing Win64 recipe runs `Build-X64Dependencies.ps1` then MSBuild Release/x64; it is not an LLVM-only direct compiler invocation.
- The engine's dependency script defaults its cache to `.build/win64-deps`, fetches pinned Git sources when absent, and copies built dependencies into `external/vulkan/Lib64` and `external/live-libs64`. Existing MSBuild props also write/copy into `platform/windows/Bin/Corona` and other checkout-relative directories. Passing only OutDir/IntDir would not relocate every generated output.
- The engine's root CMakeLists selects the Linux implementation and explicitly rejects other host OSs. It is not an existing substitute for the Win64 MSBuild solution.
- `../nexus-lab/examples/mobile/pascal-plugin/plugin_sample.nxproject` hardcodes Lua, Solar2D, LibFFI and other paths. Its Win64 LinkerOptions explicitly name `CoronaLabs.Corona.Native.lib`. The import library filename remains legitimate link intent; its directory must come from the engine's publication.
- `projects/nxbuild/nxbuild.environment.nxscript` already supplies target-selected FPC/LLVM/SDK settings via ordinary modules. It contains installation-specific paths and a relative common OutputRoot whose interpretation currently depends on callers' roots. Keep toolchain configuration distinct from dependency discovery, and normalize the common output root once before using it in differently located publishers.

### Editor and other callers

- `projects/ls/pascal/src/service/obNXLSProjectService.pas`, `NXLSProjectScriptHeader` / `NXLSNexusProjectScript`, locates nxbuild's dialect but emits retired fields such as BuildTool, ProjectKind, BuildFile and an FPCBuildOptions child. This is a verified source mismatch; no new test execution is claimed.
- `projects/nxbuild/test/tsNXBuildProjectGenerationTests.pas` has three NXTest cases intended to load generated descriptors. The README explicitly records their separation/blockage pending model adoption. Migrate and run them; do not leave them out of the architecture correction.
- `projects/ls/pascal/NexusLSTestModule/tsNXLSCoreTests.pas` still accesses TNXFPCBuildOptions.InputFile, OutputFile and BuildArguments, which are absent from the current options class. Update these tests to the real API, preserving the behavior they cover. Its module currently imports Windows, so Linux cannot stand in for executing that entire module.
- `projects/nexuscode/src/build/nexusBuildCommandBuilder.ts` already invokes nxbuild with `/action=build /project=...`. `projectTypes/nexusProjectAdapter.ts` finds `.nxproject` files but returns an empty projectFile/fpcOptions language-server context. The editor does not currently inherit project dependencies for code intelligence.
- `projects/forge/src/obNXForge.pas` imports TNXPackageContractValidator and conditionally recognizes the nxpackage dialect. `projects/forge/language/definitions/Contracts.ForgeDef.nxscript` imports that language and composes its properties/index definitions. These are concrete deferred dependencies, not evidence of a need for two nxbuild entities.

### Descriptor and catalog inventory

A read-only filesystem inventory included nested repositories, preserving `examples/build` as source. It excluded `.git`, node_modules, generated output/dist and Python cache directories. Counts are file inventory, including fixtures; they do not assert that every descriptor currently builds.

| Repository/area | `.nxproject` | `.nxpackage` | `Package.nxscript` | Documents declaring index roots |
| --- | ---: | ---: | ---: | ---: |
| Nexus, excluding the three nested package repositories | 29 | 0 | 0 | 2 |
| nexus-packages | 40 | 16 | 32 | 1 |
| nexus-packages-ext | 1 | 0 | 3 | 1 |
| nexus-packages-apple | 0 | 3 | 3 | 1 |
| nexus-lab | 26 | 2 | 1 | 3 |
| nexus-fpc | 14 | 0 | 0 | 0 |
| nexus-mobile | 0 | 0 | 0 | 0 |
| nexus-private | 0 | 0 | 0 | 0 |
| **Total** | **110** | **21** | **39** | **8** |

There are 131 descriptions declaring the nxbuild dialect and 47 documents declaring the nxpackage dialect. These are overlapping views of the same inventory, not additional counts to add to the table. Forge descriptions, inline test fixture strings, documentation snippets, and the extra catalog-example `ExternalPackage.nxscript` also require reference searches.

The 21 `.nxpackage` files are the first-party FCLXML, FCLJSON, FCLBase, Pthreads, Iconv, Users, RTLUnicode, FCLDB, SQLite, OpenSSL, PasJPEG, X11, FCLImage, FCLRegistry, LibFFI and FCLRes builds; Apple's CocoaInterfaces, AppleLocale and UniversalInterfaces builds; and lab Mixed/Abbrevia native examples. Consolidate with colocated metadata where they describe the same project; do not blindly turn each old file into a competing new descriptor.

The eight catalogs are Nexus's `packages/Packages.PackageIndex.nxscript`, the three package repositories' `Packages.RepositoryIndex.nxscript`, the workbench's IndexWithHash fixture, and the lab's PackageIndex, RepositoryIndex and ExternalRepositoryIndex examples. The workspace package index has explicit local locations across repositories; repository indexes include external identity records. Keep those discovery roles distinct from project execution.

## Architecture Problem

A consumer cannot express one requirement and obtain a usable build environment because metadata/publication and execution have different owners and neither owns the graph. Manual compiler-path wiring fills the gap and defeats transitive inheritance. The editor and build generators have consequently drifted onto yet another obsolete description shape.

The correction is one project definition and one resolver/planner. Catalogs locate definitions; they do not supply competing requirements or publications. Compiler option classes translate resolved environments; they do not independently discover dependencies. Execution consumes the completed plan; it does not discover a second graph.

## Target Contract

The following is proposed design, separate from the verified behavior above. The binding decisions in the request remain fixed.

### Universal project and ownership

- One canonical `nxproject.Language.nxscript` under `projects/nxbuild/language/`, with one execution/publication root, `Project`. `.nxproject` is the universal description extension. Remove the old `nxbuild.Language.nxscript` and `nxpackage.Language.nxscript` contracts after the coordinated cutover; no Package-root alias.
- One shared project definition/loader and one graph implementation under `projects/nxbuild/src/`, named for their actual ownership (`obNXProject...`, shared record/enumeration definitions in `tpNXProject...`). FPC/LLVM operation classes remain operation-specific. No Project/Package subclass hierarchy or duplicate metadata model.
- Project owns Id, optional descriptive metadata, Requires, categorized published directories, root configuration and ordered operations. The source descriptor is authoritative. A metadata/source-only project has zero operations and is valid.
- Loader owns analysis/Live snapshots while loading; materializes owned project values and requirement locators with original source identity/ranges before releasing them. Graph owns each loaded node once. Plans own resolved operation arguments and project/dependency attribution. Neither plan nor editor retains dangling analysis references.
- Publication state is declared once on the project. The resolved environment adds the project's own directories and the complete dependency closure. Every category is retained, even if a particular operation cannot use it.
- Planning/editor inspection creates no directories, expands no source masks, launches no producer, and requires no published directory to exist. Execution creates outputs and expands masks only after prerequisites have run.
- Executor remains sequential on the current thread and uses the existing synchronous process path. No threads, scheduling pool, or concurrency changes.

### Discovery and identities

Retain NexusScript `module` declarations and `@` references. Rename catalog build-entity records to LocalProject/ExternalProject and PackageIndex to ProjectIndex; retain RepositoryIndex and existing repository/hash metadata where still useful. These are locators, not executable roots.

A requirement references a catalog record. A LocalProject supplies Id and Descriptor; resolve Descriptor against the **catalog document declaring that record**, including imported records, not against the consumer or the module alias. Load that file and require its Project.Id to match the record's opaque, case-preserved identity. Project labels and catalog labels are reference names, not alternate IDs.

For an ExternalProject, resolve its identity through an explicitly supplied local workspace ProjectIndex. Recommend `/catalog=<file>` for this selection; allow the explicitly imported workspace index itself to provide the local locator when it already does so. Never search arbitrary directories, fetch a repository, or guess a sibling checkout. Diagnose a referenced identity with no local locator. If multiple supplied local locators disagree, report the ambiguity; this is necessary dependency resolution, not resource-collision management or a version solver.

An explicit reference identifies its catalog directly. Remove the validator's blanket assumption that every requirement must belong to one implicitly selected imported index. Validate each referenced record and retain provenance. Repeated references to the same loaded project/context reuse its node. Catalog Version/Description are browsing summaries; descriptor values stay authoritative. Existing remote/trust/hash records remain descriptive and trigger no acquisition or verification subsystem.

### Graph, aggregation and build context

1. Carry one immutable invocation target/toolchain selection through every descriptor load, including imported modules and target-selected requirements/publications. Preserve TargetOS/TargetCPU selection and any genuinely selected configuration. Diagnose inconsistent FPC target OS/CPU versus LLVM triple rather than silently mixing target artifacts.
2. Resolve the complete closure using visiting/visited states. Missing-descriptor diagnostics include the requiring project, requirement source range and attempted locator. Cycle diagnostics show the project chain and offending edge before any producer runs.
3. Deduplicate nodes by canonical descriptor identity plus effective invocation context. Repeated same-context diamond nodes build once per invocation. Detect inconsistent identity/descriptor bindings instead of selecting a version. Do not introduce persistent caching.
4. Use stable dependency traversal in authored Requires order. Schedule each dependency before its dependents; preserve operation order within each project. Aggregate categories in stable first-encounter dependency order and declaration order, deduplicating normalized directory identities while retaining provenance from every contributing project. This internal order is documented and tested; expose no precedence knobs or category filters.
5. Resolve every relative publication against the publisher's effective root (default: its descriptor directory; RootDirectory relative to that descriptor). References yielding strings do not transfer path ownership to the consumer. Keep author-facing directory lists coarse-grained.
6. Normalize the configured external output root once in the shared context, then derive target/project output directories. Publish generated paths using the same lists as existing paths. No GeneratedResources category, existence switch, special generated-path contract, or mandatory artifact manifest.
7. Initial freshness rule: visit/build every required project once per invocation; invoke its operations and let existing native builders use their own incremental behavior. Do not skip a producer because its output directory happens to exist. A source-only project contributes no steps. This establishes correctness without cache design.
8. Plan output shows project identities/descriptors, target/context, edges, dependency-first steps, each categorized resolved directory with publisher provenance, applicable compiler arguments and output destinations. Failure reports name the producer/project/operation, preserve exit status and do not execute dependents. Retain the existing stop-on-first-failure behavior.

### Publications and operation paths

Proposed publication child: `Publishes Directories`, containing `Sources`, `Headers`, `Objects`, and `Libraries`. Four categories reflect actual existing distinct toolchain facilities, rather than a speculative taxonomy.

| Existing field/concept | Proposed meaning |
| --- | --- |
| Package UnitPaths | Move to project Publishes.Sources after reviewing whether each entry is a source or precompiled-unit directory. Both are unit lookup directories for FPC. |
| Package IncludePaths | Move to Publishes.Headers. |
| Package LibraryPaths | Move to Publishes.Libraries. |
| Object directories currently smuggled through Outputs or consumer ObjectPaths | Move to Publishes.Objects after checking the actual contents/use. |
| FPC Files.UnitPaths/IncludePaths/ObjectPaths/LibraryPaths | Keep for the operation's local and explicit toolchain/SDK settings. Add applicable resolved project directories through one options input; remove manually repeated dependency paths. |
| LLVM IncludePaths/LibraryPaths | Same distinction: local settings remain; inherited headers/libraries are appended centrally. |
| LLVM SystemIncludePaths | Retain its genuine system-header semantics. Publishing ordinary headers must not silently mark third-party code as system headers. |
| SourceFiles | Keep explicit compilation inputs/masks; published source directories are search paths, not permission to compile every file. |
| OutputPath, OutputRoot, SourceRoot, RootDirectory | Output destination and authoring/root configuration, not publication categories. Review each use; no global spelling-based replacement. Require generated destinations outside source. SourceRoot is currently a referenceable value, not an automatic source search path. |
| Outputs | Remove as a publication catch-all. Classify published directories into the four lists; keep actual build destination settings on operations. Inspected named executable Outputs references are in Forge recipes/tests, with other uses in contract test fixtures. They do not justify a new output-file publication mechanism for nxbuild. Defer those Forge consumers. |
| FPC PackagePaths, RequiredPackages, PackageSDKIdentity, PackageBuildIdentity and `.nxpk`/`.nxpl` | Preserve their compiler-native meanings and explicit operation settings. A project requirement is never converted into `-FP` or a package identity. |

FPC consumes Sources with `-Fu`, Headers with the existing `-Fi`/`-I` mapping, Objects with `-Fo`, and Libraries with `-Fl`. LLVM consumes Headers with `-I` and Libraries with `-L`. Sources remains visible in the environment but does not cause a C/C++ compiler to search for or compile arbitrary implementation files.

A search directory alone does not tell a native linker which object/library to link. Preserve library names in LLVM Libraries and existing Pascal link directives/options. Add a narrow LLVM operation-level `ObjectFiles` input if required by the mixed example: resolve named object inputs against inherited Objects directories at execution after producers finish. This is link intent on the consuming operation, not a file manifest on the publisher. Keep sources/objects before libraries and preserve deliberate repetitions/order of explicit linker inputs; directory deduplication must not deduplicate link arguments.

### Illustrative descriptor form

These examples propose syntax for review; they are not installed descriptors. `Tools` is the ordinary configured environment module, with an already normalized absolute external OutputRoot, platform settings and installed tool paths. Catalogs below locate projects; none of the consumers repeat dependency resource directories.

```nexusscript
// Provider's own descriptor, beside its source tree.
dialect "nxproject.Language.nxscript";
module "BuildEnvironment.nxscript";
Project Abbrevia {
    Id: "NXRP.Compression.Abbrevia";
    OutputRoot: @Tools.OutputRoot + "/abbrevia/" + @Tools.Native.Name;
    Publishes Directories {
        Sources: ["external/abbrevia/source"];
        Headers: ["external/abbrevia/source"];
        Objects: [@Abbrevia.OutputRoot + "/native"];
        Libraries: [@Abbrevia.OutputRoot + "/libraries"];
    }
    // Real native-codec and bzip2 LLVM operations live here.
    // Existing filename subdirectories/link directives determine the final layout.
}
```

```nexusscript
// The imported catalog contains LocalProject Abbrevia with its Id/Descriptor.
dialect "nxproject.Language.nxscript";
module Projects "Projects.ProjectIndex.nxscript";
module "BuildEnvironment.nxscript";
Project ArchiveApplication {
    Id: "Local.ArchiveApplication";
    Requires: [@Projects.Abbrevia];
    FPC Application {
        CompilerPath: @Tools.Native.FPCCompiler;
        SourceFiles: ["ArchiveApplication.lpr"];
        OutputPath: @Tools.OutputRoot + "/archive-app/" + @Tools.Native.Name;
    }
}
```

```nexusscript
// Distinct ordinary projects, each in its own real descriptor.
// Their catalog locators are supplied explicitly by the workspace.
Project Nexus2DIntegration {
    Id: "NXRP.Nexus2D.Integration";
    Requires: [@Projects.Solar2DBridge, @Projects.Nexus2DEngine];
    // May publish its own materials or compile a plugin using normal FPC entries.
}
Project Solar2DBridge {
    Id: "NXRP.Solar2D";
    Requires: [@Projects.Lua];
    Publishes Directories { Sources: ["src"]; }
}
Project Lua {
    Id: "NXRP.Lua";
    Publishes Directories { Sources: ["src", "src/bindings"]; }
    // Add the actually required target-selected LibFFI edge after inspecting uses.
}
Project Nexus2DEngine TargetOS[win64] {
    Id: "NXRP.Nexus2D.Engine";
    // Publish header/library/object directories verified from the actual engine build.
    // Ordered external-tool operations invoke its native Win64 build.
}
```

The last block shows graph shape, not four roots in one accepted build file. Integration inherits the bridge, Lua, engine and every further dependency automatically. Actual engine source is `../nexus-mobile`; final publication paths must be derived from its relocated build outputs, not invented here. Library-only, executable-only and source-only projects use this same contract.

## Scope

### Concrete change inventory and removals

- **Dialect/model:** canonical nxproject language; one project metadata/publication/build model; typed requirement references and source provenance. Remove duplicate Project/Package roots, Kind-dependent semantics and old description model if replaced. Do not retain forwarding type aliases.
- **Loading/discovery:** reshape obNXBuildDescriptionLoader into the canonical project loader; reuse NexusScript Live. Extract useful catalog validation from obNXPackageContractValidator into the shared owner and remove the old validator API. Add explicit workspace catalog selection and identity/descriptor checks.
- **Resolution/plans:** one resolver and graph/context owned by the planning service; effective-directory collections and edges in plans. Replace CreatePlan's zero-build rejection. Keep no consumer-specific closure algorithms.
- **Option generators:** FPC/LLVM receive an effective environment without mutating authored settings; local/SDK configuration stays distinct. Preserve independent runtime-package options. Add explicit object-input support only where the actual native-link scenario requires it.
- **Native engine adapter:** nxbuild currently has only FPC/LLVM operations. Add one narrow external-process operation using executable plus argument array, working/output directories and the existing synchronous executor. It can invoke existing MSBuild/CMake/PowerShell-based native builds without importing Forge's operation hierarchy or implementing a general scripting engine. Installed tools come from environment configuration.
- **CLI/editor query:** `/project`, `/action=plan|build`, target selection and explicit local catalog binding use the shared service. Provide a machine-readable rendering of the same read-only resolved plan for editor context; this serializes an existing plan, not a second JSON project-description format or JSON translation before Live analysis. Include per-operation FPC paths/target settings and actionable resolution diagnostics.
- **Workbench:** rename the nxpackage application/project to nxproject and update file filters, captions, tests and documentation. Retain TNXScriptEditor's editing/undo/save ownership. Move semantic project/catalog checks into the shared service; editor inspection does not invoke producers or require installed build outputs. No duplicate requirement parser inside the GUI.
- **NexusLS/NexusCode:** update generators to emit canonical Project/FPC syntax; update three project-generation NXTests and stale options-model callers. NexusProjectAdapter forwards project/target/catalog context and reads resolved options through the shared query path rather than walking dependencies in TypeScript. Stop relying on an empty context/global unit-path fallback to conceal unresolved project dependencies. Keep editor file discovery distinct from dependency discovery.
- **Descriptors/catalogs:** inventory all 110 existing projects, 21 legacy build-extension files and 39 Package.nxscript files; merge colocated same-identity descriptions. Rename catalog records/locators and dialect references. Preserve licenses/metadata. Migrate known source-only providers, native producers and all first-party consumers of the changed contract, including lab/package/compiler test recipes. Do not keep the old formats as aliases.
- **Documentation/tests:** nxbuild/nxpackage READMEs, packages/README.md, affected AGENTS instructions, lab build/catalog examples, package build documentation, installation/tool lookup paths and inline generated fixture strings. Retire negative tests that enforce the rejected Project publication restriction; replace with positive universal-capability tests. Preserve still-useful source-mask, ordering, output, tool-failure, target and native package coverage.

### Abbrevia consolidation

Make the provider repository authoritative for Abbrevia's source/header publication and native codec producers. Move the useful nxbuild recipe out of the lab into that project and remove the duplicate Forge-owned package definition as its public build contract. Keep the lab as a consumer/example.

Separate the genuinely distinct `.nxpk` runtime-package build into an ordinary runtime-package build project requiring the provider, so a source/static-unit consumer does not acquire a new mandatory runtime-package SDK prerequisite. That project explicitly owns its compiler-native SDK/package options. This distinguishes real build products without reintroducing project/package entity kinds.

Migrate a lab direct source consumer and Abbrevia's test consumer to Requires. Native object layout and Pascal `{$L}`/library directives must agree with the published directories; retain platform subdirectories where the existing sources require them. Do not change codec implementation to accommodate an incorrectly planned path.

### Real Win64 engine integration

Create an engine Project in `nexus-mobile` and a separate integration Project referencing the bridge and engine. Use the existing native solution as the initial producer. Do not claim the bridge builds the engine, or that Clang directly replaces the existing solution.

Before running it, split the dependency script's explicit acquisition preparation from its build-only use of already provisioned pinned sources. The nxbuild producer must not silently fetch sources. A missing source/tool is an actionable prerequisite failure; provisioning remains an owner-controlled existing workflow, not a new package manager. Add parameters only as necessary for build-only inputs and external output directories.

Review all MSBuild props and dependency-copy destinations. Relocate generated artifacts to the authorized external worktree, or run the existing checkout-relative build in a declared isolated source snapshot under that worktree and publish its actual generated directories. Recommend the isolated-snapshot route initially because overriding only OutDir does not cover the verified copy steps. The snapshot is an ordinary producer preparation operation, never an edited test copy or a patched source tree used to hide failures; it preserves the engine inputs, records source identity, and is not created during plan inspection. Define its invalidation/update from the current engine source so it cannot silently build stale input.

Derive engine library/header publications from inspected native outputs. Run an actual Win64 engine -> plugin link/load scenario on Windows before claiming that acceptance criterion. Linux graph/argument tests are useful but cannot substitute for MSBuild execution. Planning alone will not prove the solution's current health or that every third-party build input is already provisioned.

## Out Of Scope

- Forge source, dialect, templates, executor, or runtime reconciliation. Migrating its own `.nxproject` as an nxbuild consumer is different from redesigning Forge.
- The old Forge dialect and obNXForge imports will need a separate follow-up once the old nxpackage language/validator are removed. Until reconciled, Forge's build/descriptor validation path may be unavailable; report that consequence explicitly. Do not retain a duplicate contract, alias or adapter solely to conceal it.
- Compiler package formats/flags, compiler or RTL changes, codec changes, new threads, generalized caches, package acquisition/version solving/trust redesign, resource import filters, re-export controls, collision registries and speculative categories.
- Broad repair of existing obsolete Lazarus integration. Generate the approved native Nexus project shape and retire obsolete assumptions on that path; do not introduce lazbuild use.
- The paused compiler identifier-naming goal.

## Staged Implementation Plan

Each stage is part of one final migration; staging is not permission to leave two permanent contracts.

1. **Capture baseline and prepare the cutover.** Reconfirm inventory/source identities and record real current NXTest results after implementation is authorized. Save the current native nxbuild self-build command/recipe and executable as a seed for the tool's own replacement. Use existing unmodified descriptions for that initial tool build; do not invent compiler bootstrap changes. Establish external output roots and identify all runtime consumers of the old contract, with Forge explicitly deferred.
2. **Implement the canonical contract and loader.** Add universal metadata, typed requirements and directory publications; catalog locators with provenance; target-aware owned project values. Move useful validation to the shared owner. Permit zero operations. Compile the new tool using the existing installed nxbuild and still-unmodified self-build recipe before removing that recipe's old dialect. No new runtime compatibility branch is required for the old seed tool to compile new Pascal source.
3. **Implement graph resolution and read-only plans.** Resolve full closure, cycles/missing identities, publisher-relative paths, deterministic category aggregation and once-per-context ordering. Add resolved environment/graph diagnostics and machine-readable plan output. Keep planning free of outputs and processes. Test incomplete generated directories without preparing them.
4. **Connect options and execution.** Feed effective collections into FPC/LLVM; add the narrowly necessary link-input/external-process capability. Execute dependency-first, preserve per-project order and exit codes. Run producer/source-generation/failure scenarios on actual files with the same authored descriptors. Keep execution sequential.
5. **Migrate providers and consumers coherently.** Populate actual publications and requirements, merge duplicate metadata/build descriptions, migrate catalogs and the full inventory. Consolidate Abbrevia and migrate its direct/static consumer plus nxbuild's own transitive source dependencies. Then switch to the newly built nxbuild for migrated recipes. Remove legacy language files/root support once active migrated paths use the new model; record Forge's deferred consequences instead of maintaining aliases.
6. **Migrate editor/workbench consumers.** Rename/reshape the workbench, repair generated project syntax and current-model test callers, and connect the VS Code language-server context to the shared resolved plan. Verify unsaved editing and disk discovery without executing builds. No second graph implementation.
7. **Integrate and validate the actual engine project.** Add its project/catalog entry, external native build invocation, build-only prerequisite handling and output isolation. Add target-selected integration requirements and run the native Win64 engine/plugin acceptance scenario where tools are available. Record an explicit platform blocker if Windows tools/runners are absent; do not report end-to-end completion based on Linux stubs.
8. **Remove rejected machinery and finish migration evidence.** Delete obsolete duplicate APIs/files, old `.nxpackage` roots/aliases, manual dependency path copies, restrictions/tests/docs. Search the complete repository set, review the final diff and run the approved verification matrix. Publish precise results and deferred Forge/platform limitations. Do not silently repair unrelated bugs found during this work; discuss them with the owner.

## Sub-Agent Delegation

Implementation remains local. No sub-agent use is authorized by this request or this plan; later implementation approval alone would not authorize it.

## Verification Plan

These are future checks after authorization, not checks executed while writing this plan. Use NXTest for new behavioral regressions. Use checked-in source and descriptors directly; no edited copies to convert failures to passes.

### Focused tests

- Universal root accepts identity, every publication category, executables/libraries and no-operation source providers; rejects the retired Package root and old dialect/extension entry points after cutover.
- Requires binds actual catalog references, retains source provenance, validates catalog-to-project Id agreement and locates external identities only through an explicit local index. Missing descriptors/records, conflicting locators and cycles provide complete diagnostic chains before execution.
- Direct, three-level transitive and diamond graphs inherit **every** category. A shared producer executes once for the selected context. Different target selections yield separate valid outputs and no mixed-target reuse.
- Relative paths are publisher-owned with nested modules/catalogs, different roots, spaces and platform-specific paths. Directory normalization deduplicates paths without discarding provenance; link argument repetitions/order remain intact.
- A producer creates source/header/object/library directories from nothing. Its consumer sees the same ordinary publications and runs afterward. Producer failure preserves its code, identifies the failing project/operation and leaves a consumer marker absent. Planning creates no marker/directory and invokes no producer.
- Test exact FPC `-Fu`, `-Fi`/`-I`, `-Fo`, `-Fl` and LLVM `-I`, `-L` mappings. System include paths remain distinct. Test real native object linking after production and missing-object diagnostics. Unit directories do not become C source files.
- Runtime-package options still produce their existing SDK/identity/package flags only when explicitly authored; project Requires emits no automatic `-FP`.
- NXTest regression for the old Workbench Project publication restriction becomes a positive test. Retain editor undo/save/source-byte ownership and imported-reference editing boundaries. Generated descriptions pass the same loader/resolver, including quoted names and wire serialization.
- Editor plan/query produces the same effective FPC paths as build planning. TypeScript forwards context rather than resolving a second graph; query failure becomes an editor diagnostic instead of an implicit global-path fallback.

### Compiler-backed migration evidence

1. Create/migrate a real Abbrevia source/static-unit consumer whose descriptor has Requires and **no Abbrevia resource directory literals**. Build and execute a compression round trip, including its required native codecs where available. Save the descriptor hash, resolved plan and commands.
2. Change only Abbrevia's publication to a second real source directory containing the same tested inputs. Re-plan and build without touching the consumer. Assert that the old directory disappears and the new publisher-relative directory appears in the consumer's effective arguments; compare the unchanged consumer hash. Use a real fixture arrangement/source relocation in the test setup, not an amended source implementation to hide a failure.
3. Rebuild nxbuild itself and its NXTests from migrated descriptors requiring NexusScript/FCLProcess/etc. Prove that transitive Core/serialization/Mustache paths now originate in providers rather than duplicated consumer lists. Verify actual compiled behavior, not just strings.
4. Build a native Clang producer and FPC consumer using only requirements for resource paths; also exercise the converse Clang link operation with an object produced by another project. Include a generated header/source and a diamond producer marker.
5. On native Win64 with prerequisites provisioned, build the actual engine, then the bridge/integration consumer, verify import-library architecture/exports and load/run the plugin against the resulting host. Record exact solution/configuration/artifact locations and process results. On Linux, validate graph/category/target plan behavior and native mixed compiler scenarios; explicitly leave native Win64 execution unverified until run there.

### Commands and regression entry points

The existing Linux tools were found at `../../worktree/nexus/nxbuild-next/x86_64-linux/nxbuild` and `../../worktree/nexus/nxbuildTests/x86_64-linux/nxbuildTests`; `/usr/bin/clang-18` is present. Presence is not a successful build/run. Let `$NXBUILD`, `$NXBUILD_TESTS`, `$PROJECT_GENERATION_TESTS`, `$PROJECT_TESTS` and `$OUT` denote the newly validated binaries and a unique external worktree directory. Native settings must point to the selected existing NexusFPC SDK; do not alter its bootstrap stages/options.

```sh
"$NXBUILD" /action=plan /project=projects/nxbuild/nxbuild.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD" /action=build /project=projects/nxbuild/nxbuild.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD" /action=build /project=projects/nxbuild/test/nxbuildTests.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD_TESTS"
"$NXBUILD" /action=build /project=projects/nxbuild/test/nxbuildProjectGenerationTests.nxproject /targetos=linux /targetcpu=x86_64
"$PROJECT_GENERATION_TESTS"
"$PROJECT_TESTS"
```

PROJECT_TESTS denotes the migrated workbench/shared-project NXTest runner, whose new path must be recorded when the old nxpackage project is renamed. Also build/test the NexusScript engine/editor suites affected by reference/schema changes. Compile NexusLS and execute its applicable native test modules; report the existing Windows-only test-module boundary rather than treating a Linux subset as full coverage.

For the extension, run `npm run compile` in `projects/nexuscode` with existing dependencies, configure TypeScript output externally for this validation, and verify the project task/query flow manually in VS Code. Do not install tools/dependencies or run package publishing as an implicit part of these commands.

Focused reference searches must cover nested package repositories and siblings, not only Nexus's tracked files:

```sh
rg -n --hidden -g '!**/.git/**' -g '!**/node_modules/**' 'nxpackage\.Language|nxbuild\.Language|LocalPackage|ExternalPackage|PackageIndex|TNXPackageContractValidator' projects packages ../nexus-lab ../nexus-mobile ../nexus-fpc
rg -n --hidden -g '!**/.git/**' -g '!**/node_modules/**' 'FPCBuildOptions Compiler|ProjectKind:|BuildTool:|BuildArguments|\.InputFile|\.OutputFile' projects/nxbuild projects/ls projects/nexuscode
```

Review matches by meaning: retain genuine compiler-native packages and unrelated option classes; record deferred Forge references explicitly. Re-inventory old extension/descriptor names and prove every active provider has one canonical description. Review source-tree cleanliness after execution. GUI checks cover opening/editing a publisher, catalog and consumer, updating a requirement, diagnostics, undo/save/reload and a zero-operation project without building it.

## Risks And Questions

The universal entity, automatic all-category inheritance, directory publication, normal project build relationships and removal of unsupported compatibility contracts are settled. The following are narrower design choices or verified integration limits:

1. **Discovery binding:** recommend reference-valued Requires plus an explicit local workspace index for ExternalProject resolution. It preserves existing NexusScript identities and avoids a new name grammar or discovery scan. `/catalog` and machine-readable plan syntax are proposed CLI additions for review, not implemented APIs.
2. **Output-root normalization:** the current environment's relative OutputRoot cannot safely be reused at every publisher depth unchanged. Recommend a single resolved absolute external workspace output root in the invocation/environment context, then target/project subdirectories. Agree its concise binding syntax during contract review; do not insert machine paths into every descriptor or add compiler bootstrap processing.
3. **Abbrevia build products:** recommend a source/native provider plus an ordinary runtime-package producer requiring it. This prevents a static source consumer from accidentally needing the package SDK while retaining the existing `.nxpk` capability. Verify real codec filename/subdirectory requirements during migration.
4. **Win64 engine prerequisites and output locations:** source and recipe exist, but current script acquisition and copy destinations make a naive process wrapper insufficient. Recommend build-only operation against provisioned sources and an exact isolated worktree snapshot until native output paths can be relocated coherently. Missing prerequisites/Windows execution are blockers to that scenario, not grounds to invent success or broaden into a package manager.
5. **Forge fallout:** removing its imported old dialect/validator makes its current dependent code require follow-up. This is a documented consequence of the explicitly deferred reconciliation, not a reason to preserve the wrong nxbuild model. Do not claim Forge builds/tests pass in this migration.
6. **Scope size:** the inventory is larger than the request's representative examples. Metadata-only providers, existing build descriptions, catalog entries, inline test fixtures and editor-generated strings must all be migrated; otherwise manual-path and dual-model behavior survives. Recount at implementation start because repositories can change independently.

## Approval Gate

This artifact supplies architecture analysis and a work plan only. No implementation code or descriptor changes, builds/tests, engine preparation, source acquisition or migration are authorized by it. Implementation begins only when the human owner directly approves the plan and authorizes the work. If a verified implementation obstacle materially changes these contracts, stop and discuss it rather than silently work around it.

Creating, committing and pushing this single work-plan artifact is the planning handoff required by the repository protocol. It authorizes no implementation, Forge reconciliation, sub-agent delegation or resumption of the paused compiler naming goal.
