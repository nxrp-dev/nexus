# Work Plan: Separate Package Definitions from Forge Execution

Status: proposed; implementation requires owner approval.

## Inputs

- Source requests: the owner's package-definition boundary request and its 2026-10-04 revision excluding dependency-resolution design.
- Related discussion: a package is an independent entity; the package index discovers definitions; Forge owns runnable work. The Render output-directory question remains paused separately.
- Constraints: qualified package identities are opaque text, not a naming grammar; no project redesign; packages must not depend on project-owned dialects; preserve the existing dirty worktree.

## Summary

Move package identity, metadata, and declared dependency identities into a package-owned NexusScript descriptor. Make the index an explicit catalog of those descriptors. Replace runnable Forge `NexusPackage` with an operation that references a package identity and carries execution-specific inputs and outputs. The new Forge package operation accepts Boolean `AutoResolve`, default `false`. Neither `false` nor `true` performs implicit dependency-resolution work in this change; `true` is reserved for future work whose semantics are not designed here.

## Verified Findings

- [`NexusPackage.ForgeDef.nxscript`](../../projects/forge/language/definitions/NexusPackage.ForgeDef.nxscript) currently declares `NexusPackage` as a Forge root/Group child. It mixes `Version`, `Author`, `License`, `Requires`, and target dimensions with `Compiler`, `Source`, `EntryPoint`, output paths, unit/include paths, and defines.
- [`obNXForgePackages.pas`](../../projects/forge/src/obNXForgePackages.pas) identifies requests by definition source path, name, and selected targets rather than a stable package ID. Its current path recursively obtains dependency definitions, checks physical outputs, writes build logs, and invokes FPC through [`obNXForge.pas`](../../projects/forge/src/obNXForge.pas). The `/package` CLI selects a definition name in a Forge document.
- Current `Requirement.Package` values are references to Forge `NexusPackage` definitions. `PackageOutput` can bind a dependency output into another operation's input. These are current execution mechanisms, not suitable package identity fields.
- [`PackageIndex.Language.nxscript`](../../projects/forge/language/PackageIndex.Language.nxscript) defines one index type with `Packages` as directory paths and `Discovery` as repository strings. [The local index](../../packages/Packages.PackageIndex.nxscript) explicitly lists 15 directories. A repository search found no index reader; the index is currently a declared catalog, not an acquisition mechanism.
- Both checked-in index examples declare a sibling `PackageIndex.Language.nxscript`, but neither directory contains that file. Dialect lookup must be specified rather than assuming sibling resolution.
- Among the indexed `packages/` directories, the only checked-in Forge package descriptor found is [`Serialization.Forge.nxscript`](../../packages/foundation/serialization/Serialization.Forge.nxscript). The other entries cannot be converted to descriptor paths by merely changing the index syntax.
- Existing Forge tests cover mixed package compilation, dependency-provided compiler paths, prebuilt output reuse, child-task rejection, and the one-root rule. Tests of the old recursive behavior must not become requirements for the new boundary.

## Architecture Problem

The same `NexusPackage` node is a package definition, selected build variant, artifact-presence rule, and compiler invocation. Dependencies link executable Forge definitions rather than stable package identities. The index points to folders rather than independently defined descriptors. Separating these roles does not require deciding what Forge will eventually do with declared dependencies.

## Target Contract

| Concern | Owner and intended behavior |
| --- | --- |
| Package identity | Descriptor: one required, stable, globally unique qualified text value. Treat it as opaque: no splitting, prefix semantics, inferred host, case folding, or embedded version semantics. A local catalog can detect duplicate exact identities among entries it loads. |
| Intrinsic data | Descriptor: package metadata, such as version/author/license, and dependency identities as text. One descriptor describes one package. Declaring a dependency does not locate, validate availability of, or act on that package. |
| Index | Package-owned dialect and reader: an explicit list of descriptor-file paths relative to the index. Each descriptor supplies its own identity and metadata; the index does not duplicate them or recursively discover unlisted packages. Keep `Discovery` as sister-repository references, without cross-repository package ownership or download behavior. |
| Forge operation | A runnable, verb-named operation references one package identity and carries selected targets, build inputs, and concrete output paths for its explicit work. Package descriptors and indexes are not executable Forge definitions. |
| `AutoResolve` | Boolean property on that Forge package operation, default `false`. With `false`, Forge performs no implicit dependency-resolution work. With `true`, Forge accepts the value but also performs no implicit dependency-resolution work yet. Document `true` as future work; do not define its eventual semantics here. |

The package descriptor and index dialects should belong to the package domain under `packages/`, not to `projects/forge`; `packages/package/language/` is the proposed location. Forge can consume compiled descriptors through NexusScript, but package code must not reference project-owned definitions. A Group may sequence explicit Forge tasks, but this plan assigns no dependency semantics to that sequence.

## Scope

- Add a package-domain descriptor dialect and small validated model; relocate/revise the index dialect and make the local and hosted example indexes list descriptor files.
- Add the Forge package operation and `AutoResolve` property; change direct package selection to use descriptor identity and explicit build inputs/outputs. Remove old implicit dependency traversal rather than replacing it with a resolver.
- Migrate actual package descriptors and affected Forge recipes, CLI behavior, tests, and documentation needed for the new boundary. Inventory all 15 indexed directories; do not infer a descriptor from a directory.
- Retire runnable `NexusPackage` after the direct operation and consumers have moved; add no compatibility alias without a verified current need.

## Out Of Scope

- Resolving, finding, obtaining, downloading, building, ordering, or selecting variants of declared dependencies; recipe lookup, automatic dependency output binding, and cycle handling. `AutoResolve = true` does not implement any of these.
- A general package manager, remote acquisition, cross-repository catalog, version-range solver, or identity naming convention.
- `NexusProject`, general Project semantics, unrelated Forge operations/Group rules, and the paused Render output-directory decision.
- NexusScript reference/target changes without a concrete failure under the new package dialect.

## Staged Implementation Plan

1. **Fix the ownership boundary.** Confirm the minimal intrinsic descriptor fields and obtain owner-supplied qualified IDs for migrated packages. Keep selected targets, build inputs, and physical outputs on the Forge side. No dependency-execution policy decision is needed.
2. **Create package descriptors.** Add the package-owned dialect and loader/model. Require one opaque identity per descriptor; record declared dependencies as opaque identity text rather than `@NexusPackage` references. Loading a descriptor must not resolve its dependencies.
3. **Make indexes catalog descriptors.** Change `Packages` entries from directory paths to explicit descriptor paths, retain the local/hosted index type and `Discovery`, and specify dialect resolution for both settings. Detect missing descriptor files and duplicate package IDs among indexed entries; never recursively scan for packages.
4. **Move explicit work into Forge.** Add a verb-named package operation that looks up the directly selected package and carries its own execution inputs and concrete outputs. Add `AutoResolve` with default `false`; parse/store both Boolean values, and ensure neither triggers dependency traversal or other implicit work. Retire the existing recursive dependency path. Reuse existing process/template machinery where it fits.
5. **Migrate and retire.** Convert indexed packages and package examples/tests to descriptors plus separate Forge work. Where a recipe currently relies on `PackageOutput` or dependency traversal, make its immediate execution inputs explicit; do not invent a replacement dependency policy. Update CLI/docs to distinguish discovery from execution and state that `AutoResolve = true` is accepted but not yet functional. Remove the runnable `NexusPackage` rule and old path/name package identity logic after consumers move.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan and any later implementation approval do not authorize sub-agent use.

## Verification Plan

- During implementation, compile with `lazbuild projects/forge/NexusForge.lpi`, `lazbuild projects/forge/test/NexusForgeTests.lpi`, and `lazbuild packages/nxscript/test/NexusScriptTests.lpi` after structural changes, then run the focused test executables. No builds or tests are part of this planning pass.
- Test descriptor/index validation for opaque package and dependency IDs, missing/duplicate package IDs, explicit paths, local and hosted index loading, unchanged `Discovery`, and no recursive scan. Validate a descriptor without invoking Forge.
- Test direct Forge package selection and execution with explicit inputs. Cover omitted, `false`, and `true` `AutoResolve`, using a declared but unavailable dependency: all three cases must perform no implicit dependency lookup or work. Retain direct FPC/artifact tests where applicable; do not carry forward tests that require automatic dependency execution.
- Exercise migrated examples. Search for remaining executable `NexusPackage` definitions, package-to-project dialect references, old path/name package identity logic, and old recursive dependency traversal. Treat the Render directory issue separately.

## Risks And Questions

- **Required owner input:** canonical qualified IDs for existing packages. A local index can detect collisions it sees, but cannot prove worldwide uniqueness.
- Most indexed directories currently lack package descriptors. The index migration must author or otherwise account for each listed descriptor so that local discovery remains truthful.
- Existing `PackageOutput` references and target-conditioned `Requirement` selections cannot be copied wholesale into a descriptor of dependency identities. Inventory their users and make any work required by migrated Forge recipes explicit. Future dependency output/variant policy remains undecided.
- The working tree contains uncommitted package/Forge changes from the paused prior pass. Preserve those changes and re-evaluate them against this plan before implementation; do not treat draft code as architectural authority.

## Approval Gate

This is a plan only. No implementation, builds, tests, program launch, or archive creation is authorized by it. Begin implementation only after the owner explicitly approves the plan and supplies the package identities needed for migration. Dependency-execution policy is not an approval prerequisite for this work.
