# Work Plan: NexusPackageManager and Independent NexusScript Entities

Date: 2026-10-05
Status: planning document; implementation has not begun.

## Inputs

- The owner's conversation request of 2026-10-05: create the GUI project `NexusPackageManager` under `projects/PackageManager`; give Package, PackageIndex, and Project independent conceptual and physical ownership there; remove their ownership from Forge.
- Repository instructions: `AGENTS.md`, `.ai/protocols/architecture-change.md`, `.ai/protocols/codex-workplan-format.md`, and `.ai/standards/pascal.md`.
- Inspected evidence: current Forge dialects, package runtime, CLI, examples, tests, documentation, repository package index, and the existing NexusTestUI GUI structure.
- The current request replaces the direction in `work/plans/forge-package-definition-boundary.md`. In particular, its proposed package-domain location under `packages/package`, Forge package operation, and `AutoResolve` contract do not apply to this work.
- The owner requires direct functional and technical work descriptions without stages, gates, or approval checkpoints. This document uses that structure instead of the default staged template.
- Preserve the existing uncommitted work. It includes substantial Forge changes and deleted/renamed package scripts; inspect the working files as evidence rather than restoring HEAD or treating either version as authoritative. Implementation remains local; no sub-agent work was requested.

## Purpose and Architecture Problem

Create a practical GUI development environment for three standalone NexusScript entity types. Package describes a package, PackageIndex catalogs packages, and Project describes a project. NexusPackageManager owns their definitions, models, loading, validation, and interaction.

Forge currently conflates a package entity with a build request, target variant, dependency traversal, artifact-presence rule, and FPC invocation. Renaming or relocating that runtime would carry the same assumptions into the new project. Replace the domain design from intrinsic requirements, migrate useful data and shared infrastructure, and remove the obsolete execution architecture.

Forge remains a generic execution/task system. This work adds no mechanism for Forge to consume the new entities.

## Verified Findings

| Evidence | Confirmed behavior and implication |
| --- | --- |
| `projects/forge/language/definitions/NexusPackage.ForgeDef.nxscript` | The working dialect defines a runnable `NexusPackage`, allowed at the root and under Group. It mixes Version/Author/License with target Dimensions, Requirements, Outputs, PackageOutput bindings, Compiler, Source, EntryPoint, UnitOutput, search paths, and Defines. These fields do not collectively constitute an independent package model. |
| Deleted `Package.ForgeDef.nxscript` in HEAD | The previous `Package` rule also mixed metadata, target dimensions, dependency definition references, physical outputs, and task containment. Neither spelling is a compatibility requirement. |
| `projects/forge/src/obNXForgePackages.pas` | TNXPackageRequest and TNXForgePackages depend directly on Forge. Requests are keyed by source filename, definition name, and target selections. They recursively obtain dependencies, bind outputs, check filesystem readiness, create output directories, write build logs, and run package compilation. There is no stable global package identity. |
| `obNXForge.pas`, `tpNXForge.pas`, and `cli/NexusForge.lpr` | Forge has package dispatch, ExecutePackageBuild, fokNexusPackage, and a /package CLI path. Removing only the package unit or language file would leave architecture behind. |
| Generic Forge language definitions | FPC, CSV, Git, and MSBuild explicitly permit PackageOutput references in ordinary task properties. These references must be removed while preserving legitimate generic property references and task behavior. |
| `projects/forge/language/PackageIndex.Language.nxscript` | Packages currently lists directories; Discovery lists Git repository strings. The language requires a nonempty Packages array. No PackageIndex reader was found in the searched Forge/package implementation. The new local reader is required work, not an existing runtime to move. |
| Repository and example indexes | `packages/Packages.PackageIndex.nxscript` lists 15 directories. Both it and the Forge example declare a sibling PackageIndex.Language.nxscript that is absent beside them. Directory entries do not establish package descriptor existence or package identities. |
| Project evidence | No Project or NexusProject language rule or Forge project runtime was found. `projects/forge/doc/packages-design.md` reserves NexusProject as a future concept. Establish the new Project model directly and remove that reservation from Forge documentation; do not invent a project runtime to migrate. |
| Shared infrastructure | `packages/nxscript` already owns compilation sessions, source providers, language validation, compiled definitions, definition views, and source diagnostics. Its instructions place product dialects with their product owners. `packages/gui` provides Nexus controls and skins over fpGUI; NexusTestUI demonstrates their application lifecycle. |
| Other project systems | NexusCode and the Pascal language server already have separate .nxp/Pascal project work. That is a different existing concern, not a Forge NexusScript Project implementation, and does not supply an authoritative model for this request. |

## Ownership and Initial Entity Contract

All three language definitions and their domain implementation live under `projects/PackageManager`. Actual package and project descriptor documents may stay beside the resources they describe; importing a product dialect does not transfer ownership of those resources to the application.

The proposed initial properties below are the minimum working contract for exercising the relationships. They are not a claim that the models are mature or a requirement to preserve the old schema.

| Type | Initial entity data | Relationship and behavior |
| --- | --- | --- |
| Package | Required `Id` text; its NexusScript definition name as a local display label; optional `Description`, `Version`, `Author`, and `License` text; optional `Requires` array of package ID text. | Dependencies describe relationships only. They do not import other descriptors, require availability, locate packages, order work, or trigger any action. Version is descriptive text with no ordering or solving semantics. |
| PackageIndex | Its definition name; a `Packages` array of explicit local Package descriptor filenames. Empty arrays are valid. | Explicitly loading an index reads its listed descriptors and presents identity, metadata, source location, and diagnostics. It does not traverse package dependencies, scan directory trees, or consult unlisted indexes. |
| Project | Its own definition name; optional `Description`; optional `Packages` array of associated package ID text. A Project may have no package associations. | A Project is an independently loadable entity, not a task or a package build variant. Its package associations neither contain Package definitions nor make packages project-owned. They remain valid declarations when no matching package is loaded. |

Package identity is a stable, globally unique qualified textual identifier supplied by the package author. Require a nonempty textual value and preserve it exactly. Do not split it, enforce a qualification grammar, normalize case, infer repository/namespace/host meaning, embed version meaning, or generate an identity from its filename or definition label. Use exact identity comparison independently of platform-dependent filename comparison. Local indexing detects collisions among loaded descriptors; it cannot certify worldwide uniqueness.

A package's identity survives a file move or display-label change. A change to Id is an explicit identity change, not a rename inferred by the application. Dependency IDs and Project package associations use the same opaque value contract. The global package-ID requirement does not introduce a global Project identity scheme.

Resolve index entry paths relative to the defining index file, never the process working directory. Distinct descriptor paths claiming the same package Id are a collision, not candidates for automatic selection. Repeated entries for the same canonical descriptor path are an index diagnostic. Report missing, invalid, and conflicting entries with their source paths; retain valid entries for inspection and clearly mark the index as having errors.

Keep intrinsic entity values distinct from document location, compile state, GUI selection, and diagnostics. None of the entities contains target OS, target CPU, build configuration, toolchain choice, compiler options, selected source masks, task sequences, output readiness, build logs, or execution state.

## Required Functional and Technical Work

### Create the GUI project and its independent home

Create this structure using the repository's Pascal unit naming and output conventions:

```text
projects/PackageManager/
  AGENTS.md
  README.md
  NexusPackageManager.lpi
  src/
    NexusPackageManager.lpr
    uiNXPackageManagerMain.pas
    obNXPackageManagerDocuments.pas
    obNXPackage.pas
    obNXPackageIndex.pas
    obNXProject.pas
  language/
    Package.Language.nxscript
    PackageIndex.Language.nxscript
    Project.Language.nxscript
  examples/
  test/
    NexusPackageManagerTests.lpi
    NexusPackageManagerTests.lpr
    tsNXPackageManagerTests.pas
```

Add tp/ut units only for actual shared declarations or cohesive helpers that arise during implementation. Do not create a framework of services, repositories, plugins, or extension points in anticipation of future features.

The .lpr is a GUI entry point using the existing fpGUI/Nexus controls and skin lifecycle. Derive its build configuration from the working NexusTestUI patterns, selecting only required GUI, NexusScript, and foundation paths. Place executable and unit outputs under `output/NexusPackageManager/$(TargetCPU)-$(TargetOS)`. Compiler output macros are application build infrastructure, not entity properties. Neither the application nor its test project may use Forge units, templates, language files, or source search paths.

The project AGENTS.md references the applicable Pascal standard and states the independent domain ownership. README documents how to build and open the supplied examples.

### Define and load the three NexusScript types

Create owner-local dialects for roots named exactly `Package`, `PackageIndex`, and `Project`. Each depends on the reusable NexusScript Language dialect, never Forge. Each entity document contains one corresponding entity root. Reuse normal NexusScript module/include support where needed for source composition; do not make such source imports into package dependency resolution.

Describe the initial properties and arrays with strict language rules. Reject unknown properties, unknown children, execution properties, and Forge task nesting. Replace old Requirement/Selection definition references with text dependency identities. Do not create NexusPackage/NexusProject aliases or retain an old Package dialect beside the new one.

Use TNexusScriptCompilationSession and TNexusScriptValidator to compile the declared dialect and validate the entity document. Give entity loading a PackageManager-owned diagnostic surface, using existing diagnostic codes and source ranges where available. Do not call CompileForgeDocument or use ENXForge.

Project the validated compiled definitions into small explicit entity objects. The language rules define accepted syntax; entity code supplies semantic checks such as nonempty IDs and catalog collisions. Do not add another parser or route ordinary typed property access through Forge's JSON/template build pipeline.

Load without target selections. The entities must not require target context to have meaning; report target-conditioned entity data as outside this standalone contract. Keep generic NexusScript target capability unchanged for other consumers.

For the editor, use the existing source-provider extension point for an in-memory overlay of the current document, delegating other local source reads to the file provider. Keep that small adapter under PackageManager. This allows validation before saving without modifying the compiler or depending on language-server code.

### Provide the useful development GUI

Provide one main window with ordinary Open, Reload, Validate, Save, Save As, and Close actions. Use the existing tree/list, memo/editor, panel, button, and dialog controls.

The window provides:

- A document/entity view identifying the loaded type and file. For an index, show its listed packages and the state of each entry.
- An editable NexusScript source view, preserving the original source rather than regenerating it from the entity projection.
- A details view showing the current validated entity values, including opaque package IDs, descriptive metadata, dependency IDs, and Project package associations.
- A diagnostics view with source filename, line/column, message, and a way to navigate to the current document's reported location.
- Explicit navigation from an index entry to its local package document, and reload of an index after descriptor changes.

For already loaded catalog entries, the details view may show exact-ID matches for declared dependencies and Project associations. This is a view of current data, not a lookup request: never load another file or index merely because an ID appears. An unmatched association is displayed as having no loaded match, not as an invalid entity or a request to acquire it.

The document owner holds source text, dirty state, source path, validation results, and entity projections. Entity objects do not depend on forms. GUI selection references the owner's current snapshot and is cleared or rebound before that snapshot is replaced. On validation failure, retain the editable draft and show errors; clear the current entity projection or visibly identify a retained last-valid projection as stale. Never present old values as the newly validated draft.

Save writes the source document on an explicit user action. Permit saving an invalid development draft with visible diagnostics. Confirm discard/reload when there are unsaved edits; Save As changes the source location and requires revalidation of relative references. Preserve source comments and avoid semantic rewriting or injecting fields.

Use synchronous, explicit operations for this bounded local application. Do not introduce threads for validation orchestration or generic background activity. If a concrete blocking operation later proves to freeze GUI progress, document that operation and its ownership before deciding how to isolate it.

Include small valid Package, PackageIndex, and Project examples and invalid samples that demonstrate diagnostics. The GUI exercises definition editing, validation, local catalog loading, and relationship inspection. It has no install, publish, download, resolve, build, target-selection, or execution controls.

### Reevaluate and account for the existing definitions and code

| Existing material | Required disposition |
| --- | --- |
| Version, Author, License and useful package labels | Retain as descriptive entity data where accurate; add explicit opaque Id. Preserve description separately from identity. |
| Requirement.Package references | Replace with declared dependency ID text when the relationship is intrinsic. Do not copy target selections, compiler provisioning, or output bindings. |
| Dimension, Selection, Targets, compiler/search-path settings, Inputs, Outputs, PackageOutput | Exclude from standalone entity models. Remove package-specific definitions and runtime mechanisms. Preserve needed explicit execution selections only in ordinary Forge task documents. |
| TNXPackageRequest/TNXForgePackages | Discard the request/build architecture. Reimplement only independent entity loading or catalog behavior through shared NexusScript APIs; do not move or rename these execution classes into PackageManager. |
| Directory-based index entries | Replace with explicit descriptor paths, supported by real descriptors. Move the language ownership and useful local index example to PackageManager. |
| Discovery Git strings and hosted-repository discovery instructions | Do not migrate this remote-discovery experiment into the initial model or application. The initial index is a local catalog; remote discovery requirements remain undecided. |
| Reserved NexusProject concept | Remove Forge's ownership claim. Implement Project as the small independent entity described above, without inheriting an unimplemented Forge build contract. |
| Generic NexusScript/foundation/GUI code | Reuse from their legitimate shared package locations. Product entity rules stay under PackageManager; shared packages acquire no dependency on PackageManager or Forge. |
| Forge process, invocation, file operations, source expansion, and generic task templates | Keep under Forge for generic execution. Source selection for a compiler invocation is not Package or Project ownership. The new application does not import these facilities. |

The tiny text/path helpers inside Forge are not a reason to depend on Forge. Use existing shared facilities, or implement a small domain-local helper if no reusable owner exists. Extract supporting code into a shared package only if a concrete shared requirement justifies it; no unrelated refactoring.

Inventory actual descriptors and current consumers before conversion. In particular, account for all 15 repository-index entries: author accurate minimal descriptors using supplied identities, or remove unsupported entries and document the omissions. Never pretend a directory is already a package descriptor, and never fabricate production identities by converting directory components into a proposed naming scheme.

Keep truthful descriptors beside their package resources and point them to the PackageManager-owned language. Move only product language/model ownership and applicable examples/tests into the new project. For `Serialization.Forge.nxscript`, separate the package's actual entity information from its old source-directory output-presence task; the latter is not a descriptor property to preserve.

### Remove package and project architecture from Forge

Remove `NexusPackage.ForgeDef.nxscript`, the obsolete Package rule if present, the Forge-owned PackageIndex dialect, the package command template, `obNXForgePackages.pas`, package dispatch, ExecutePackageBuild, fokNexusPackage, and the /package CLI path. Remove dead package-only helpers and runtime state. Remove any Project language rule, dispatch, or ownership claim found by the complete consumer inventory.

Remove PackageOutput-specific definition restrictions from generic FPC, CSV, Git, and MSBuild properties. Retain their legitimate text/effective-property-reference capabilities without opening them to arbitrary entity definitions. Update Forge dialect assertions and tests so Package, NexusPackage, PackageIndex, Project, and NexusProject are absent and standalone entity documents cannot be run as Forge tasks.

Retire package-specific test registration, fixtures, dependency recursion tests, build-cache tests, and artifact-readiness tests. Preserve generic Group, command, Render, FPC, file-operation, source-selection, and diagnostics coverage. Move only applicable intrinsic entity cases into PackageManager tests; do not transplant tests that enforce discarded execution semantics.

Convert useful existing executable examples such as Hello and PasBuild to ordinary explicit Forge tasks/Groups, with their immediate input paths and execution options stated directly. Metadata useful for an independent entity can go in a separate descriptor. Dependency-provided compiler/output fixtures are obsolete architecture and should be removed, not recreated as another package-aware operation. Give retained task scripts ordinary .Forge.nxscript filenames and update their local module/template references.

Update affected CLI help, Forge documentation, repository guides, and `repo-automation/Compare-ForgePasBuild.ps1` to reference the retained generic tasks. The comparison script currently passes /package and calls PasBuild.ForgePackage.nxscript, so it is a concrete affected consumer. This is removal maintenance, not a new Forge integration design.

Record that this plan supersedes the incompatible ownership and integration directions in `forge-package-definition-boundary.md` when implementation documentation is updated. Do not leave a second active architectural direction.

Neither product depends on the other after the change. Forge has no package lookup, descriptor-consuming operation, AutoResolve switch, Project adapter, compatibility aliases, or duplicate entity models. Future consumption of mature entities is separate work.

## Scope and Exclusions

Expected changes cover the new `projects/PackageManager` project; Forge language/runtime/CLI/tests/examples/docs affected by removal; the repository package index and actual migrated descriptors; directly affected recipes, guides, and comparison automation.

Exclude dependency resolution, dependency availability enforcement, recursion/order/cycle policy, remote acquisition, remote index traversal, publishing, installation, version constraints/solving, target selection in entities, task generation, and future Forge consumption. Do not build a complete package-management interface.

Do not migrate or redesign .nxp, Pascal language-server project models, NexusCode adapters, or unrelated build systems. Do not change general NexusScript parser/reference/target semantics merely to accommodate the old Forge shape. Do not expand into the separately paused Render output-directory decision.

## Verification

The following checks belong to implementation; no builds, tests, application launch, or archives are performed while preparing this plan.

Compile the new GUI and tests, retained Forge application/tests, and shared NexusScript tests after the relevant structural changes:

```text
lazbuild projects/PackageManager/NexusPackageManager.lpi
lazbuild projects/PackageManager/test/NexusPackageManagerTests.lpi
lazbuild projects/forge/NexusForge.lpi
lazbuild projects/forge/test/NexusForgeTests.lpi
lazbuild packages/nxscript/test/NexusScriptTests.lpi
```

Run the resulting focused test executables. Verify:

- Each entity dialect loads and validates independently, using only PackageManager and shared NexusScript code.
- Package identities round-trip exactly, remain independent of source path/display label, and preserve punctuation/case without interpreting components. Missing/empty IDs fail; collisions in a loaded catalog are diagnosed.
- Dependencies and Project associations load successfully with unavailable IDs. Instrument source access so validation proves it never loads a dependency descriptor or an association implicitly.
- Indexes handle empty arrays, explicit relative paths from a different working directory, missing/invalid descriptors, repeated paths, and exact-ID collisions. Valid entries remain inspectable alongside errors. No remote reads or unlisted directory scan occurs.
- Entity schemas reject execution properties and Forge task children. Entity loading does not create output directories/logs or spawn processes.
- Editing uses current in-memory source, diagnostics have correct source locations, failed validation does not expose stale values as current, and replacing/closing snapshots leaves no dangling GUI references.
- Retained Forge generic tasks execute without any PackageManager search path or package-specific runtime.

Manually launch NexusPackageManager and open all three examples. Edit metadata and opaque dependency IDs, validate before saving, navigate an index entry, reload changed descriptors, save/reopen, test invalid syntax and semantic errors, cancel discard of a dirty draft, and exercise Save As with relative paths. Verify resize, focus, selection, diagnostics navigation, and shutdown through normal fpGUI ownership.

Use focused repository searches for remaining Package/NexusPackage/Project/NexusProject language roots in Forge, PackageOutput schema references, TNXForgePackages, ExecutePackageBuild, fokNexusPackage, /package CLI use, .ForgePackage.nxscript consumers, and Forge-owned PackageIndex paths. Inspect matches rather than treating unrelated words such as Project in an MSBuild task as domain ownership. Also inspect Pascal uses clauses, .lpi search paths, dialect includes, and templates to establish that neither product depends on the other.

Report exact failures before deciding whether they expose an implementation defect or an obsolete test requirement. Do not silently weaken a failing test.

## Risks and Unresolved Model Detail

- Production package authors must supply stable qualified identities. Test/example values demonstrate opacity only and establish no naming convention or global registration authority.
- Existing draft Forge changes must be inventoried against the new boundary. Neither the committed Package design nor its uncommitted NexusPackage replacement is authoritative.
- Project presently has no Forge language implementation to preserve. Its proposed minimal name/description/package-association model is an initial development surface; source organization and richer relationships remain undesigned until concrete standalone requirements establish them.
- The separate .nxp project system creates a naming overlap. Keep its units, format, and target/toolchain behavior outside this plan and document the distinction; do not resolve it by inventing an integration or adopting those execution fields.
- Removing PackageOutput changes several generic task schemas and recipes. Complete the directly affected call-site inventory so Forge remains usable after the obsolete architecture is removed.
- An index can display partial results, but must not silently choose among duplicate identities or report a failing catalog as valid. GUI and loader diagnostics must agree on that state.
- Source edits and compiled objects have different lifetimes. Clear or rebind non-owning UI references before releasing snapshots, and preserve unsaved source on compile/read failure.
