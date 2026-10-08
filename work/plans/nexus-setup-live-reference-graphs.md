# Work Plan: Nexus Setup, Live Emission, and Reference Graphs

Status: Work plan only; no implementation authorization from this document.
Prepared: 2026-10-06.

## Inputs

- The owner's conversation request: a combined work plan for everything discussed here, including Setup and the Live emitter.
- `C:/Users/kcollins/Downloads/nexus-setup-design.14.md` (Setup design version 14).
- `C:/Users/kcollins/Downloads/nexusscript-live-emitter-design.1 (2).md` (Live emitter design version 1).
- The owner's subsequent corrections: ordinary object/reference cycles belong in the compiled graph, Live, and SQLite; the bounded, Mustache-friendly representation is a JSON output policy. A scalar alias cycle such as `A: @B; B: @A;` remains a compilation error.
- The owner's persistence direction: retain original NexusScript source, compile it through the common compiler, and consume native objects. Use `.nx/` for private metadata when needed rather than making compiled JSON authoritative.
- The owner's correction to this plan: do not modify Forge in any way. Regression builds/tests are allowed. Analysis of migrating Forge to Live is separate future work, only after the system has been proven functional for Setup.
- Current source, repository instructions, `.ai/protocols/architecture-change.md`, and `nexus-source-tree-structure-canonical.5.md`.

The supporting documents are design input, not implementation authority. The owner's later reference-graph clarification supersedes the Live document's literal requirement to leave every existing compiler behavior unchanged. It does not authorize a compiler rewrite. Historical plans remain historical and will not be rewritten.

## Summary

Establish one semantic reference graph, correct the JSON/SQLite boundary, complete the native Live emitter, and make Setup consume that graph directly. Build Setup around the declarative installation semantics actually established in version 14, with product-local ownership and shared NexusScript infrastructure.

This is not a second compiler, a generic package manager, or a Forge redesign. Forge remains entirely unchanged and serves only as an existing regression consumer. Analysis of migrating Forge is outside this work and must wait until the system is proven functional for Setup. Setup's installation requirements and feature-selection closure are Setup behavior, not new policy for PackageManager or Forge. NexusTask remains removed.

The eventual path is:

```text
Original NexusScript + declared dialect/includes/modules
                       |
               Common compilation
                       |
             Compiled semantic graph
              /          |          \
       bounded JSON   SQLite graph   Live object graph
         Mustache     rows + links          |
                                     Setup domain model
                                            |
                           selection + detected machine state
                                            |
                                installation plan/providers
                                            |
                          execution results + retained metadata
```

All three outputs use the same successful compilation. Output selection does not change which ordinary reference graphs the language accepts.

## Verified Current State

These findings are from source inspection. No builds or tests were run for this work plan.

1. **There is already a common compiler and compiled model.** `packages/nxscript/src/obNexusScriptModel.pas` retains definition/property/value objects and reference associations through `ResolvedDefinition`, `ResolvedProperty`, and `ResolvedValue`. Owned structure is separate from these borrowed target pointers. `StructuralDefinition` currently also carries owned reference projections.
2. **The projection policy currently leaks into compilation.** `obNexusScriptCompiler.pas:1272` builds bounded reference copies; `PrepareReferenceProjection` at line 2009 recursively prepares them. The definition-reference branch at line 2202 can reject direct object cycles with `NXS5004`. This happens before choosing an emitter.
3. **The test suite encodes the same misplaced boundary.** `packages/nxscript/test/tsNexusScriptTests.pas:3442` expects a mutual direct-object cycle to fail compilation. `TestReferenceArrayProjection` at line 3628 allows reference-array cycles but expects structural arrays to disappear from referenced projections. Its direct-cycle cases at line 3716 expect failure. The accepted array cycles do not establish general graph support.
4. **Scalar evaluation cycles are separately diagnosed.** `EvaluateValue` uses evaluation state and `NXS5002`. Existing scalar/property/array-entry alias-cycle tests must remain negative. Module/include/dialect loading cycles and composition cycles are also separate concerns; this plan does not liberalize them.
5. **JSON depends on prebuilt projection state.** `obNexusScriptJSON.pas:229` uses artifact helpers and serializes `StructuralDefinition`. The Mustache-friendly projection contract is documented in `packages/nxscript/doc/include-presentation.md`. It can be retained without making it a language restriction.
6. **SQLite is currently a relational projection, not a complete reference graph.** `obNexusScriptSQLite.pas` creates property-named tables, `nx_id`, ownership foreign keys, and array ordinals. `FindDefinitionStorage` deliberately excludes references from ownership classification. There is no corresponding reference-edge persistence. The README explicitly says arbitrary reference relationships are not represented. Ownership classification is not the bug; absence of a separate relationship representation is.
7. **Imported references already have relevant preservation machinery.** `obNexusScriptImport.pas` owns retained private targets through `TNexusScriptImportContext`, maps object identities, and remaps references after registering owned structure. This is a useful existing implementation to review and reuse conceptually, not a reason to create another import system.
8. **Public contribution membership is distinct from reachability.** `TNexusScriptDefinitionView` includes non-imported roots and included documents, but does not treat reference targets as new contributions. Live and SQLite must preserve reachable private targets without promoting module-only targets into public roots or changing JSON collections.
9. **Live is started, not delivered.** Two untracked draft units exist: `packages/nxscript/src/obNexusScriptLive.pas` and `tpNexusScriptLive.pas`. They propose a caller-owned snapshot, per-emission identity maps, and centrally owned nodes. They have not been compiled, registered in tests, or verified. Their current shape has no authority merely because it was written.
10. **The existing emitter base is stream-oriented.** `TNexusScriptEmitter.WriteArtifact(TStream)` and its factory serve JSON/SQLite artifacts. Native Live output should return an object document; it should not pretend to write a stream or overload the CLI format system with an in-memory-only result.
11. **No Setup engine, application, or Setup dialect was found in current owned implementation source.** The canonical layout explicitly places the Setup product under `projects/setup/`. The earlier Inno installer plan is historical, references removed NexusTask infrastructure, and is not a current implementation specification.
12. **One installed-product consumer does exist.** `projects/nexuscode/src/toolchain/nexusInstall.ts:68` reads `HKLM\Software\NexusRP\Nexus\NexusRoot`, then derives installed paths. Its current layout assumptions need checking against the actual Nexus installation scenario. The plan does not silently change them or treat the historical layout as the desired new layout.
13. **The package workbench remains an independent consumer.** PackageManager currently owns provisional Package/PackageIndex/Project declarations and uses compiled reference targets for boundary checks. Its README expressly excludes package acquisition/resolution. Setup work does not supply those excluded behaviors by implication.

## Target Reference Contract

Compilation separates binding an object association from evaluating a value. Resolving a definition reference records its concrete target without recursively materializing that target into the referring value. All owned declarations still receive their normal composition, binding, and validation; a back-edge must not cause a target's remaining properties to be skipped.

Following a property or value alias far enough to compute a scalar remains evaluation. If that chain has no concrete terminating value, compilation fails. A reference to an inline or named-array definition must retain its actual definition identity as well, not become an exception that depends on declaration order.

| Input relationship | Compilation | JSON | SQLite | Live |
| --- | --- | --- | --- | --- |
| Direct self/mutual definition references | Succeeds | Reject an actual recursive expansion at emission | Persist real links | Connect real objects |
| References through structural arrays | Succeeds | Keep the existing structural-array omission in reference projections | Persist entries and target links | Preserve entries and target objects |
| Several references to one target | Succeeds | Existing finite projected copies | One target identity, multiple links | One target object, multiple links |
| Scalar/property aliases ending in a concrete value | Succeeds | Existing effective value | Effective value plus retained association | Effective value plus target navigation |
| Scalar/value alias cycle with no terminating value | Fails | No output | No output | No output |

For direct cycles, JSON emission failure is the proposed relocation of the existing restriction, not a new source-language error. Existing acyclic JSON shape, receiver naming, metadata, collections, scalar arrays, and deliberate structural-array omissions remain unchanged. Do not introduce `$ref` objects, arbitrary maximum depths, truncation strings, or another Mustache contract.

## Compiler and JSON Work

- Remove compulsory recursive reference projection from semantic binding. Preserve composition, lexical lookup, target selection, scalar calculations, and source diagnostics. Do not add `compile-live` or `compile-sqlite` modes.
- Keep owned inline definitions and borrowed reference targets distinct. In particular, do not put a borrowed target into `StructuralDefinition` while its destructor still owns/frees that field.
- Provide the smallest common semantic access needed to read effective text/arrays/definitions and inspect original targets. Put real shared object behavior with the compiled model, not in product code or convenience re-exports. This access must not manufacture JSON copies.
- Preserve immediate reference association and effective target/value as distinct facts where aliases require both. Do not confuse a projection's receiver name with the original target's identity.
- Move the bounded projection responsibility into JSON emission. Maintain the existing scalar/structural-array rules and metadata. Track the active expansion path to diagnose direct recursion; repeated references in independent branches are not cycles.
- Keep the shared definition view as a contribution/ownership view. Add graph reachability at the appropriate emitter boundary rather than changing that view into a recursive resolver.
- Review imports/cloning, dialect normalization, validation, editor inspection, and language-server navigation where they currently rely on `StructuralDefinition`. Update only dependencies exposed by this boundary change. Validate referenced kinds through semantic targets, and traverse declarations once rather than recursively treating every reference as a new declaration.
- Review shared artifact helpers and NexusScript manifest consumers where the representation correction affects them. Preserve the existing JSON/effective-value contract consumed by unchanged Forge. Do not modify any Forge call site, source, test, project file, dialect, template, example, or documentation.
- Move the direct-object-cycle assertions to successful compilation plus emitter-specific assertions. Move bounded-projection shape assertions to JSON tests instead of requiring those copies in the semantic graph. Keep scalar-alias and source-loading-cycle assertions intact.

This is a focused correction of representation ownership, not replacement of the parser, compiler, session, or compiled document.

Forge regression builds/tests are permitted, with ordinary build/test outputs only. If a regression fails, diagnose the shared NexusScript change and correct it within this work's boundary; do not adapt Forge or its assertions. If preserving the existing consumer contract exposes a genuine conflict, report it and leave the affected work unresolved rather than expanding scope. Forge migration analysis and implementation are not part of proving Setup functional.

## SQLite Reference Work

SQLite and Live consume semantic references, not JSON artifact copies. SQLite's relational output must record relationships independently of ownership.

- Keep current readable definition/property/scalar-array tables where their meaning remains correct. Retain ordinals, entry names, owner relationships, optional values, and dialect-driven empty-array shapes.
- Register semantic definitions, properties, and values by object identity for the emission. Generated database IDs are output-local handles, not package IDs or new language identities.
- Add an emitter-owned relational node/reference representation that can address definition, property, and value targets. Each reference occurrence records its owner/slot, array position or label where applicable, and target ID/type. Where a scalar alias is also projected as text, retaining the link must not discard its effective text.
- Persist target content, not merely dangling target IDs. Reachable imported/private targets need storage even when they have no public contribution table. Record them as private graph members; do not invent a public root or falsely give them the referrer's ownership.
- Allocate IDs and insert node rows before inserting relationship rows, inside the existing transaction. Use real foreign-key constraints and verify them. Self-links and mutual links then require neither recursive embedding nor insert-order guesses.
- Preserve whole-array aliases and repeated references without duplicating the semantic target. Keep distinct composition results distinct; do not merge unrelated objects just because names or source ranges match.
- Keep metadata names emitter-owned and diagnose schema-name collisions rather than overwriting user declarations. Review replacement of emitter-owned tables so rerunning emission does not leave stale graph rows or remove unrelated database tables.
- Exercise both `WriteDatabase` and serialized stream output, dialect and dialectless input, and imported targets. Do not implement a general SQLite-to-Live loader as part of correcting persistence.

Exact internal SQL names and columns will be written down with a small hand-authored expected-schema fixture during implementation. The model above is the required contract; it must not degenerate into saving only source strings that need to be reparsed to follow a stored reference.

## Complete the Live Emitter

Keep Live reusable under `packages/nxscript/`; it must not depend on Setup, Forge, PackageManager, fpGUI, or any other project.

The eight questions from the Live design have the following source-grounded answers:

1. Compiled definition/property/value instances provide identity within a compilation. Do not invent durable identity from a short name or pretend object addresses persist across recompilation.
2. Resolved target pointers and reference/source ranges are retained. `StructuralDefinition` copies are representation artifacts, not the definitive target association.
3. Targets are followable without reparsing `SourceText`; imported target retention already uses pointer remapping.
4. Ownership lists/parents and reference associations are different relationships. Output copying must respect that distinction.
5. Source ranges, contributor ranges, reference ranges, and retained original/receiver names support attribution. They do not by themselves guarantee one globally unique logical identity across every imported copy.
6. Import contexts own private target snapshots. Live must copy everything it needs before the session is released and verify alias/sharing behavior within that retained context.
7. Scalar evaluation cycles are language errors. Bounded reference projection and `NXS5004` direct-object-cycle rejection are the misplaced output limitations addressed above.
8. Consumers need semantic navigation and effective values, not composition contributor chains or JSON artifact helpers.

Implement a caller-owned, self-contained `TNexusScriptLiveDocument` snapshot. Register nodes before following associations; allocation/population/wiring may use two explicit passes or an equally clear preregistration approach. The choice must be demonstrated with forward/back references and cycles, not defended only by inspection.

The document owns each node exactly once. Children, parents, array membership, and reference targets are borrowed navigation links. Freeing the document must not recursively free through those links. Failed emission frees the partial document and returns no usable half-built result.

The public API supports definition/property/child lookup, ordered and named array entries, effective text, effective definition access, and typed reference-target navigation. Setup should not need casts or knowledge of which compiler bookkeeping field to inspect. Review the draft's generic `Reference.Target` against actual consumer examples and add only the necessary typed access, not an arbitrary-object mapper.

Retain useful provenance without requiring ordinary consumers to read it. Preserve entry visibility separately from reachable private targets. Emit two independent snapshots from one compiled document and verify that neither references the other's nodes or retains borrowed compiler memory.

Keep Live outside the stream-only artifact base unless a real shared behavior warrants changing that base. Do not add a fake stream method or a meaningless `/format=live` disk artifact. Future external-reference hooks, byte output, and reverse loaders remain outside this implementation.

## Setup Ownership and Native Model

Create the concrete Setup product under `projects/setup/`, with `src/`, `language/`, `test/`, `doc/`, and examples only as needed. Its Setup dialect belongs with that product. Common language/reference mechanisms stay in `packages/nxscript/`. No package may reference outward into `projects/setup/`.

Use ordinary Pascal classes for the established domain concepts: product metadata, feature hierarchy, logical locations, file payloads, shortcuts, installable dependencies, acquisition data, and installer-provider data. Put pure enums/records in `tp...` units and objects in `ob...` units. Do not introduce parallel Feature/Component hierarchies or an embedded task/program language.

Build the Setup model from the Live snapshot, not JSON and not a second parse of NexusScript. The Setup document owns its model; its references between features, locations, and dependencies are non-owning. If it retains Live nodes for provenance, the document explicitly owns their Live snapshot as well. Separate immutable declared installation intent from mutable selection, detected machine state, and execution results.

Product identity is stable and separate from display name/version. Dependency identity is the identity of the declared dependency object; a shared target must not become several independent installs. Do not equate Setup product/dependency identities with Package identities without a real scenario requiring that association.

Develop the Pascal model and executable scenario expectations before finalizing the Setup dialect. Version 14's mockups are not syntax. Encode the settled semantics using the existing language-definition machinery, including real scoped `@` references and kind restrictions. Do not create a new reference dialect or change cross-root lookup rules to make a mockup work.

Retain original setup source and its required dialect/include/module documents for later compilation when lifecycle operations need them. Saving only the entry script while discarding its dependencies is insufficient. Private retained copies, selection state, installation evidence, and recovery metadata may belong under the relevant `.nx/` scope; the original authored definition remains source, not compiled JSON. Exact deployment/state placement must account for per-user versus machine installation and uninstall after payload removal.

## Setup Behaviors Covered by the Plan

### Product and recursive features

Model the product ID, name, version, publisher, copyright, icon, branding image, license, and optional descriptive/support/update URLs separately from installation behavior.

Features own child features, file payloads, and zero or more shortcuts. Grouping features may have no direct payload. Apply `Required`, initial `Default`, and independent/exclusive immediate-child selection controls at the relevant hierarchy level. Exclusivity alone does not mean exactly one child must be selected.

### Selection and feature requirements

Keep explicit selection seeds separate from implied requirements. Selecting a feature computes transitive feature-requirement membership using a visited set; ordinary self/mutual feature requirements are valid. Deselecting a seed recomputes the closure, removing only no-longer-required implicit selections. A feature still required by another selected feature cannot be removed individually; report the reason without silently deselecting its dependents.

Use the same selection calculation for interactive and unattended consumers. An inconsistent candidate selection must be explainable before machine mutation. Feature `Requires` does not establish file-copy or installer execution order.

Applicability, parent propagation, conflicting required/default exclusive choices, and requirements crossing a disabled/unselected branch need concrete scenario decisions. Do not quietly choose those policies from Inno conventions or the widget's checkbox behavior.

### Locations, files, and shortcuts

Represent a destination as a logical location plus a relative path. Support the application root, permitted relocation, and named derived locations. Resolve platform location meanings through platform code, not hard-coded environment-variable spellings in scripts. The version 14 location inventory is not evidence that every listed location already has a portable implementation.

Install individual files and directory trees with relative structure preserved. Only selected owners contribute payload. A selected parent's own payload does not depend on optional-child selection. Shortcuts belong to features and resolve both location and target against installed logical locations.

File collisions, overwrite/preservation behavior, explicit absolute paths, and optional integration choices are not settled. Define them through the Nexus scenario rather than adding convenient switches speculatively. Provider implementations must operate on concrete resolved targets, not unresolved path strings.

### Installable dependencies and providers

Compute the reachable dependency set once from the selected features, preserving shared identities and using visited semantics for transitive requirements. Detection/satisfaction, acquisition, installation mechanism, and ownership are separate data and responsibilities.

Model `Payload` and `Web` acquisition independently from `Exe`, `MSI`, and `VSIX` installation. Do not invent combined types such as `WebExe`. Detection or retained installation state determines whether work is needed. Provider success and scenario-defined evidence determine satisfaction; a separate post-install probe is not mandatory for every dependency.

An Exe provider may launch arbitrary declared external code. Setup itself does not interpret embedded Lua/Pascal/program text or become an external script runtime. Provider-specific arguments, host selection, success/restart results, and detection details must come from the concrete scenario.

Cycles in the dependency declaration graph are not generic compile errors. Collecting the graph is safe; actually satisfying a mutually blocking provider requirement may need a domain diagnostic. Do not derive a universal topological execution order, arbitrary retry policy, or generic cycle rejection from `Requires`. Specify provider preconditions and the VS Code/VSIX case explicitly.

### Execution and lifecycle

Derive a concrete installation plan from declared intent, resolved selection, actual locations, and detected satisfaction. Keep plan construction and user inspection separate from executing machine changes. Do not translate the definition into a Forge Group or Task-style procedural recipe.

Record enough evidence to distinguish owned payloads/dependencies from shared prerequisites. Installing VS Code does not grant Setup ownership of it. Removing Nexus-owned VSIX/payloads must not remove shared dependencies merely because they were reachable.

Upgrade, repair, uninstall, failure recovery, cancellation, elevation/scope, and restart handling need actual scenarios and provider contracts. Do not promise universal transactional rollback across arbitrary Exe installers. Files and Setup-owned changes can have controlled recovery; external side effects must be reported according to the provider's real capabilities.

The retained definition is not evidence that every declared action succeeded. Installation results and ownership evidence are separate private state. Cache/state loss must be distinguished from an installed product satisfying all requirements.

### Setup application and installer artifact

Give interactive Setup an fpGUI frontend over the same domain model, selection, plan, and execution state used by a noninteractive caller. Use existing Nexus skin/control behavior; do not create another widget set or use PackageManager as the installer UI. Installer branding images are presentation data, not new skinning infrastructure.

Keep feature UI nesting separate from dependency graph traversal. Shared/cyclic relationships must not cause endless expansion of a tree widget. Display selected features and requirement explanations without pretending each reference owns another feature subtree.

The distribution format and installer-builder interface remain undecided in version 14. The plan requires an artifact that carries the setup definition/source context, payload, and necessary runtime, but does not select ZIP, byte serialization, self-extracting EXE, or an Inno backend by assumption. The first actual Nexus installation inventory must determine that choice.

No new thread is justified for graph construction or selection calculations. Web acquisition or waiting for an external installer may genuinely block an interactive frontend. If a worker is introduced, document that concrete blocking boundary, reuse an existing legitimate owner where possible, and keep selection/state/UI mutation on its owning thread. Do not add a background scheduler for callbacks, progress, or cleanup.

## Concrete Nexus Scenarios and Open Decisions

Use the actual Nexus installation as the first consumer, not a synthetic generic installer. Develop fixtures for:

- Installing the actual Nexus core/toolchain files to a relocatable application root, with selected FPC/package trees and cross-compiler branches represented only where real payloads exist.
- A selected feature requiring a shared VS Code prerequisite and an owned NexusPascal VSIX, with VS Code already present, absent, or unsuitable for the declared requirement.
- Shared feature requirements, mutual feature requirements, explicit versus implied selection, and deselection explanations.
- Multiple shortcuts on one selected feature and no shortcuts from an unselected owner.
- Repair/removal of owned Nexus content while leaving shared software untouched, including a failed external install.
- Recompiling the retained original source context for lifecycle inspection and verifying that the resulting links survive the end of the compilation session.

The following decisions are missing from the supplied Setup specification and must be recorded before their affected execution paths can honestly be called complete:

1. Actual install inventory/layout and the `NexusRoot` consumer contract; machine/per-user scope and privilege behavior.
2. Feature applicability and parent propagation, including exclusive/default/required conflicts.
3. Payload overwrite/collision/preservation rules and precise ownership evidence used for removal and repair.
4. Dependency detection details, accepted versions/hosts, provider invocation/success/restart behavior, and unsatisfied cyclic-provider scenarios.
5. Installed-state location/format, retained-source completeness, upgrade/repair/uninstall/cancellation recovery guarantees, and external side-effect limitations.
6. Installer artifact format/build interface and necessary runtime delivery.

These are specific execution holes with direct consequences, not a request for a broad installer-language wish list. Reference correction, Live delivery, the established Setup class model, and feature-requirement closure do not need these answers. Record an unanswered point and continue with independent work; do not invent a policy to keep busy.

## Verification

Add tests against intended semantics, not snapshots regenerated from implementation output.

- **Compiler:** direct self/mutual definition cycles; forward/back aliases terminating in definitions; inline and named-array definitions; shared targets; full referenced arrays; imported/private targets; composition overrides. Scalar/property/value alias cycles still fail with the correct value diagnostic. Invalid properties elsewhere in a cyclic target still fail validation.
- **JSON:** preserve hand-reviewed acyclic/Mustache output and structural-array omission; bounded projections do not mutate semantic objects; direct recursive expansion fails at emission, not compilation; repeated noncyclic references succeed. Existing failed-emission/lifetime behavior remains correct.
- **SQLite:** query IDs and joins to prove both sides of direct/array cycles are actually stored, not merely that a database was written. Cover shared targets, target kinds, scalar aliases, whole-array aliases, array ordinals/labels, private target content, foreign-key integrity, re-emission, unrelated-table preservation, stream/file paths, dialect and dialectless models.
- **Live:** assert pointer identity for shared targets and cycles, ordinary lookup/effective values, full arrays, provenance, imported targets, two independent emissions, and use after compilation/session destruction. Heap-check destruction and failure cleanup. Reject incomplete compiled input explicitly.
- **Setup model/selection:** product metadata, nested features, mandatory/default/exclusive semantics that are settled, cyclic closure, explicit/implicit selections, dependency deduplication, deselection explanations, location composition, owned/unowned distinction, and model lifetime after releasing compilation data.
- **Setup execution:** use controlled providers and temporary, explicitly resolved test directories for plan/execution tests; then exercise real file/shortcut/provider/lifecycle behavior only in a disposable environment. A successful fake-provider test is not proof of MSI/Exe/VSIX integration.
- **Integration:** maintain JSON/Mustache, PackageManager reference checks/editor behavior, dialect normalization, and language-server reference/navigation coverage. Run Forge's existing regressions without modifying Forge or its tests. No source-loading rule change or product acquisition behavior may sneak in through the graph correction.

Required existing suites after shared compiler/model changes, from the repository root:

```powershell
lazbuild -B packages\nxscript\test\NexusScriptTests.lpi
& .\output\NexusScript\console-tests\x86_64-win64\NexusScriptTests.exe
lazbuild -B projects\ls\nxscript\test\NexusScriptLSTests.lpi
& .\output\NexusScriptLS\console-tests\x86_64-win64\NexusScriptLSTests.exe
lazbuild -B projects\forge\test\NexusForgeTests.lpi
& .\output\NexusForgeTests\x86_64-win64\NexusForgeTests.exe
lazbuild -B projects\PackageManager\test\NexusPackageManagerTests.lpi
& .\output\NexusPackageManagerTests\x86_64-win64\NexusPackageManagerTests.exe
```

The LS path above is the verified singular `test/` directory, not the stale `tests/` spelling in the regression document. PackageManager has an owner-paused old fixture; report it explicitly, do not run or repair it by implication. Add Live cases to both NexusScript test entry points. Create Setup's own NexusTest project under `projects/setup/test/`; its output/build settings will be defined with that project, not guessed here.

Compile frequently during the eventual implementation. Unexpected failures must be explained; do not weaken an assertion or change a fixture just to turn the suite green. The direct-object-cycle expectation changes listed above are intentional contract corrections; unrelated test changes are not included.

End-state source checks must show that shared compilation no longer performs mandatory bounded reference projection or rejects ordinary object back-edges, SQLite no longer silently drops such relationships, and Setup consumes Live rather than JSON/intermediate compiler fields. Existing loading/composition-cycle guards remain. Report actual test totals, skipped/unrun checks, platform coverage, and remaining Setup decisions.

## Scope Boundaries and Handoff

- No implementation, compilation, test execution, program launch, installer mutation, or archive creation during this planning request.
- Leave the existing uncompiled Live draft files and unrelated fpGUI submodule changes untouched during planning.
- Do not resurrect NexusTask, PasBuild, comparison scripts, or removed `.nxtask` recipes. Do not alter historical plans.
- Do not modify Forge in any way: its source, tests, project/build files, dialects, templates, examples, documentation, APIs, and behavior remain unchanged. Only regression builds/tests are allowed. Migration analysis is separate future work after Setup has been proven functional; do not begin it here.
- Do not redesign Package/PackageIndex/Project or create package dependency execution policy.
- Do not implement external `!` references, byte emitters/loaders, general reverse serialization, durable language-wide node IDs, an arbitrary Pascal-class mapper, or a new discovery registry.
- Do not promise completed Linux/macOS providers from Windows-only verification. Keep platform semantics separate and record what was actually exercised.
- Implementation remains local; no sub-agent delegation was requested or inferred.

Publish this one plan artifact for review. A later direct implementation instruction authorizes work against the agreed contract; the plan itself does not. After a completed, approved architecture implementation pass, run the existing source-archive script with its unchanged defaults and provide the verification results. Do not archive incomplete work as a completed milestone.
