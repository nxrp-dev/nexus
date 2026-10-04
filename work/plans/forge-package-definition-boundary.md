# Work Plan: Separate Package Definitions from Forge Execution

Status: proposed; implementation requires owner approval.

## Inputs

- Source request: owner's conversation request beginning "This is a demand for a work plan" on 2026-10-04.
- Related discussion: a package is an independent entity; the package index discovers definitions; Forge owns runnable work. The Render output-directory design question remains paused separately.
- Constraints: qualified package identities are opaque text, not a naming grammar; no project redesign; packages must not depend on project-owned dialects; preserve the existing dirty worktree.

## Summary

Move the package's identity, metadata, declared dependencies, and stable interface into a package-owned NexusScript dialect. Make the index an explicit catalog of those descriptor files. Replace the runnable Forge \`NexusPackage\` definition with verb-named Forge work that refers to a package identity and supplies execution-specific inputs and artifact paths. Do not make package descriptors or indexes executable.

## Verified Findings

- [\`NexusPackage.ForgeDef.nxscript\`](../../projects/forge/language/definitions/NexusPackage.ForgeDef.nxscript) currently declares \`NexusPackage\` as a Forge root/Group child. It mixes \`Version\`, \`Author\`, \`License\`, \`Requires\`, and target dimensions with \`Compiler\`, \`Source\`, \`EntryPoint\`, output paths, unit/include paths, and defines.
- [\`obNXForgePackages.pas\`](../../projects/forge/src/obNXForgePackages.pas) identifies requests by definition source path, definition name, and selected targets—not by a stable package ID. It validates targets, checks physical outputs, obtains dependency definitions recursively, writes build logs, and invokes FPC through [\`obNXForge.pas\`](../../projects/forge/src/obNXForge.pas). The \`/package\` CLI selects a definition name in a Forge document.
- Dependencies use NexusScript definition references (\`Requirement.Package: @...\`), so a consumer must import the dependency's Forge definition. \`PackageOutput\` then resolves a dependency output into a command input. This makes dependency identity and availability depend on Forge-document composition.
- [\`PackageIndex.Language.nxscript\`](../../projects/forge/language/PackageIndex.Language.nxscript) defines one index type with \`Packages\` as nonempty directory-path strings and \`Discovery\` as repository strings. [The local index](../../packages/Packages.PackageIndex.nxscript) lists 15 directories explicitly. The example remote index uses the same shape. A repository search found no package-index reader; the index is currently a declared catalog, not an acquisition mechanism.
- Both checked-in index examples declare a sibling \`PackageIndex.Language.nxscript\`, but neither directory contains that file. NexusScript can alternatively resolve a dialect through a configured dialect root, so the plan must define how local and downloaded indexes find their package-owned dialect; it must not assume sibling resolution works.
- Among the indexed \`packages/\` directories, the only checked-in Forge package descriptor found is [\`Serialization.Forge.nxscript\`](../../packages/foundation/serialization/Serialization.Forge.nxscript). The other indexed directories need an explicit descriptor migration rather than directory recursion or inferred metadata.
- The current Forge suite covers package compilation, a dependency-provided compiler path, prebuilt output reuse, child-task rejection, and the one-root rule. Those tests encode the present mixed model and need replacement or relocation, not blind preservation.

## Architecture Problem

The same \`NexusPackage\` node is a package's identity, a selected build variant, an artifact-presence rule, and a compiler invocation. Its dependencies are links between executable Forge definitions instead of links between packages. The index only points at folders, so it cannot directly identify an independently defined descriptor. Moving fields without changing request identity, dependency resolution, and the index would leave the same coupling under different filenames.

## Target Contract

| Concern | Owner and intended behavior |
| --- | --- |
| Package identity | Package descriptor: one required, stable, globally unique qualified text value. Treat it as opaque: no splitting, prefix semantics, inferred host, case folding, or version embedded in the identifier. The author is responsible for global uniqueness; a local catalog can detect duplicate exact identities it sees. |
| Intrinsic package data | Package descriptor: optional metadata such as version, author, and license; declared dependency identities; supported target/capability dimensions; and any stable, named exports that consumers need to reference. One descriptor describes one package identity. |
| Selected state and build inputs | Forge task: selected targets, compiler, source masks used by a build, entry point, unit/include paths, defines, working directory, and build policy. A descriptor may later describe source inventory as package data, but the current FPC \`Source\` selection is an execution input, not that inventory. |
| Outputs | Descriptor may declare stable logical export names. Forge binds those names to concrete artifact paths for an execution and owns readiness checks, output-directory preparation, and build logs. The current \`Output\` combines these two responsibilities and must be split. |
| Index | Package-owned dialect and reader: an explicit list of descriptor-file paths relative to the index. Loading each file supplies its identity and metadata; do not duplicate that metadata in the index or recursively discover unlisted packages. Keep \`Discovery\` as a list of sister repositories, local or hosted, with no cross-repository package ownership. |
| Runtime dependency handling | Package descriptor declares *which* package identities it needs. Forge resolves those through the catalog and owns target selection, ordering, obtaining/building, result binding, and cycle diagnostics. \`PackageOutput\`-style bindings are runtime Forge data, not package identity or metadata. |

The package dialect belongs with the package domain under \`packages/\`, not in the Forge definition include or the generic \`packages/nxscript\` language catalog. A dedicated \`packages/package/language/\` location is the proposed owner; the exact folder name is less important than the dependency direction. The index dialect should move to that same owner. Forge may consume compiled package descriptors through the shared NexusScript compiler but packages must not reference \`projects/forge\`.

Forge should use verb-named package operations, initially covering the current obtain/build behavior, which reference a package's opaque identity rather than defining a package inline. Group remains the ordering mechanism. The exact task spelling is not significant to the separation; do not introduce an alias that keeps \`NexusPackage\` runnable.

## Scope

- New package-domain descriptor dialect and focused validation/model code; relocation and revision of the PackageIndex dialect, local index, and remote example.
- Forge package operation definitions, request identity, catalog lookup, dependency/output binding, CLI path, and the package-related parts of \`TNXForgePackages\` and \`TNXForge\`.
- Migration of actual package descriptors and affected Forge recipes/examples, tests, and documentation. Inventory all 15 indexed directories; do not silently treat a directory as a descriptor.
- Removal of the current runnable \`NexusPackage\` Forge definition and its implicit FPC command path once the replacement is verified. No compatibility alias without a demonstrated current need.

## Out Of Scope

- \`NexusProject\` or general Project semantics; unrelated Forge operations and Group rules.
- The paused Render output-directory policy. A package/Forge split must not silently decide it.
- Remote download/transport, cross-repository catalogs, version-range solving, a package identity naming convention, or a general build-recipe registry invented merely to preserve the current implementation.
- Changes to NexusScript reference/target semantics unless a concrete failure under the new package dialect proves one is required.

## Staged Implementation Plan

1. **Freeze the ownership contract.** Confirm the descriptor's minimal fields and the stable export-name boundary. Obtain owner-supplied qualified IDs for migrated packages; do not manufacture a naming convention. Decide whether Forge must automatically build missing dependencies or whether the first implementation requires explicit Forge tasks in a Group. The former needs a Forge-side recipe lookup contract; neither the package descriptor nor the index should conceal one.
2. **Create independent package representation.** Add the package-owned dialect and a small loader/validated model. Require one package identity per descriptor, keep identity as opaque text, and express declared dependencies by identity rather than \`@NexusPackage\` references. Separate supported target dimensions from selected target values.
3. **Rework the index around descriptors.** Change \`Packages\` entries from directory paths to explicit descriptor paths; retain the single local/hosted index type and \`Discovery\`. Make dialect resolution for checked-in and downloaded indexes explicit. Validate missing descriptors and duplicate identities among indexed entries; the index remains the authoritative list, with no recursive directory search.
4. **Move execution into Forge.** Add the chosen verb task(s) that reference package identity and carry build inputs and concrete output bindings. Refactor request keys to identity plus selected variant, keep dependency cycle detection and diagnostics, and move \`PackageOutput\` resolution to Forge runtime results. Reuse the existing process/template machinery where it fits; do not make the package descriptor executable.
5. **Migrate and retire.** Convert the indexed packages and current package examples/tests to descriptors plus separate Forge work. Update the CLI and docs to distinguish catalog lookup from execution. Remove the runnable \`NexusPackage\` rule, direct Forge-definition dependency references, and the old path/name identity logic after consumers have moved.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan and any later implementation approval do not authorize sub-agent use.

## Verification Plan

- During implementation, compile the affected Forge CLI/test project and the NexusScript test project after structural changes; run the Forge and package-dialect tests. No builds or tests are part of this planning pass.
- Add focused descriptor/index tests for opaque ID preservation, missing/duplicate IDs, explicit paths, local and hosted index loading, missing descriptor paths, unchanged \`Discovery\`, and no recursive scan.
- Add Forge tests for selected targets, dependency identity resolution, explicit/missing recipe behavior chosen in stage 1, logical export-to-path binding, existing-artifact reuse, FPC execution, cycle detection, and Group ordering. Validate a descriptor without executing Forge.
- Exercise the migrated source-package and compiled-package examples. Run focused searches proving \`NexusPackage\` is absent from Forge's executable kinds, packages do not reference project dialects, and no path/name tuple remains as package identity.
- Keep the Render directory question as a separately reported failure/decision; do not make a package-model test pass by changing Render.

## Risks And Questions

- **Required owner input:** canonical qualified IDs for existing packages, plus the dependency execution policy in stage 1. A local index can detect collisions within its catalog, but no implementation can prove worldwide uniqueness.
- The current index has many directory entries without package descriptors. Converting it to file paths without authoring those descriptors would create an incomplete catalog; migration must be atomic enough to keep local discovery truthful.
- A package's logical export name may be intrinsic, while its physical path is not. Confirm the minimum stable export interface needed by current consumers before moving \`Outputs\`; avoid keeping all current output fields in the descriptor out of convenience.
- Package dependencies may be invariant, target-conditioned, or resolved to concrete variants at invocation time. Preserve this distinction rather than copying the current \`Requirement.Targets\` values wholesale into permanent package metadata.
- The working tree already contains uncommitted package/Forge changes from the paused prior pass. Preserve those changes and re-evaluate them against this plan before implementation; do not treat the current draft as authoritative merely because it compiles.

## Approval Gate

This is a plan only. No implementation, builds, tests, program launch, or archive creation is authorized by it. Begin implementation only after the owner explicitly approves the plan and resolves the stage-1 decisions.
