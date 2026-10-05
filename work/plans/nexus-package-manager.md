# Work Plan: NexusPackageManager Development Environment

Date: 2026-10-05
Status: plan only; no implementation performed.

## Inputs

- The owner's pasted request of 2026-10-05 to revise the NexusPackageManager plan.
- Repository planning and architecture protocols, plus the current Forge, NexusScript, and NexusTestUI code inspected for this plan.
- This direction supersedes the package/Forge boundary proposed in work/plans/forge-package-definition-boundary.md. In particular, a Forge package operation and AutoResolve are not part of this work.
- The existing uncommitted Forge changes are preserved. They are evidence of the old design, not authority for the new one.

## Purpose

Create projects/PackageManager with a working fpGUI application named NexusPackageManager. It is a small development workbench in which Package, PackageIndex, and Project NexusScript concepts can be opened, edited, compiled, validated, and inspected. Their language definitions and domain ownership live in that project. They are entities, not Forge tasks. The workbench may depend on shared NexusScript and GUI packages, but neither it nor its dialects may depend on Forge.

The immediate deliverable is the environment for refining these entities, not a completed package-management model. Forge temporarily returns to generic runnable work with no package- or project-specific architecture. Future Forge integration is separate work after the entities have been developed.

## Verified Baseline

- The working Forge dialect has a runnable NexusPackage definition combining package metadata with targets, requirements, outputs, compiler settings, and source selection. Its PackageOutput definition also appears in generic task property restrictions.
- Forge currently has TNXForgePackages, recursive package execution, ExecutePackageBuild, a package invocation kind, a package template, and a /package CLI path. Removing only the dialect would leave package behavior in Forge.
- Forge owns the current PackageIndex language file. Its Packages/Discovery fields reflect a previous index experiment; no PackageIndex reader was found in the inspected implementation. The repository index lists directories, and its declared sibling dialect file is absent.
- No Forge Project or NexusProject language/runtime implementation was found in the inspected files. Forge documentation reserves the idea, but there is no working project model to migrate.
- packages/nxscript already provides compilation, validation, diagnostics, and compiled-definition access. NexusTestUI shows a working fpGUI application pattern. These are reusable infrastructure, not entity schemas.

## Required Work

Create a standalone project at projects/PackageManager containing the NexusPackageManager GUI, project-local NexusScript language definitions for Package, PackageIndex, and Project, a few representative example documents, and focused tests. Keep the application and its tests free of Forge units, language includes, templates, and build-time search paths. Use the repository's normal Pascal naming and build conventions without importing NexusTestUI's unrelated test harness or benchmark code.

Begin with only enough provisional language structure to recognize and validate example documents of all three types. Package has a stable, globally unique qualified textual identity. Require an explicit nonempty identity, preserve it exactly, and treat it as opaque: no naming grammar, component parsing, case normalization, inferred repository, or embedded version meaning. Package dependency identities may be represented as declarations if useful for the initial examples, but loading or inspecting them has no resolution or execution effect. PackageIndex and Project need only enough structure to be identifiable and exercisable; do not copy their old fields or invent their final relationships to make the GUI appear complete.

Provide the practical document workflow: open a NexusScript file, edit its source, save, reload, compile and validate the current text through shared NexusScript infrastructure, show diagnostics with source locations, and inspect the resulting definition/property tree. Show whether a valid loaded root is Package, PackageIndex, or Project; invalid or incomplete source should remain editable with its errors visible. The inspection view should expose what NexusScript actually compiled, without translating it into a premature package catalog or project relationship model. Use simple fpGUI controls and a straightforward document lifecycle; do not regenerate source from the inspected tree.

Remove obsolete Package, NexusPackage, PackageIndex, Project, NexusProject, PackageOutput, and package-specific execution ownership from Forge wherever those concepts actually occur. This includes the Forge language definitions/index dialect, package runtime and dispatch, package-only invocation state, template, /package CLI path, and package-specific tests, fixtures, examples, and documentation. Remove PackageOutput-only references from generic task schemas without removing legitimate generic task behavior. Search for actual consumers before deleting files; adapt retained executable recipes to explicit generic Forge tasks where they are still useful, and retire obsolete package-execution examples rather than preserving the old architecture under new names. Do not add a compatibility layer or a replacement Forge package operation.

The existing repository package index, package directories, and project documents are not a migration requirement for this first workbench. Account for direct references to Forge-owned dialects when removing them, but do not assert that old directories or indexes already satisfy the provisional new definitions. The representative PackageManager examples, rather than a converted repository catalog, are the initial validation material.

## Deliberately Undecided

This plan does not decide the complete Package or Project schema; the representation or discovery semantics of PackageIndex entries; project-to-package associations; catalog collision policy; dependency resolution; version solving; acquisition, publishing, or installation; target compatibility; remote discovery; or future Forge integration. It does not assign TargetOS, TargetCPU, build configuration, toolchain, compiler settings, outputs, or task ordering to the standalone entities merely because Forge once held those fields. No general package-manager workflow or unrelated .nxp/project-system redesign is included.

## Verification

During implementation, build the new GUI and focused tests, and rebuild the affected Forge and shared NexusScript projects. Expected project checks include:

```text
lazbuild projects/PackageManager/NexusPackageManager.lpi
lazbuild projects/forge/NexusForge.lpi
lazbuild projects/forge/test/NexusForgeTests.lpi
lazbuild packages/nxscript/test/NexusScriptTests.lpi
```

Run focused tests that load and validate one representative document of each type, preserve opaque Package identity text, exercise unsaved-buffer validation and diagnostic locations, and confirm that inspecting dependency declarations causes no package lookup or execution. Manually launch the GUI and exercise open, edit, validate, inspect, save, reload, and error recovery for all three examples.

Search Forge language, runtime, CLI, tests, and documentation for the removed package/project concepts; inspect matches so ordinary uses of words such as "project" in generic build tasks are not mistaken for entity ownership. Verify that Forge still runs its retained generic tasks, and that PackageManager imports no Forge code or dialects. Do not run builds, tests, or the GUI as part of this planning pass.
