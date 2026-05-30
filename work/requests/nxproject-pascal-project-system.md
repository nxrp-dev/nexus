This is a demand for a work plan.

# Work Request: NXProject Pascal Project System

## Status

Status: Work plan requested

## Summary

The NXProject system should become the canonical Nexus project system for Pascal language-server work.

The immediate goal is to fully develop the Pascal-side NXProject model so that `.nxp` can become a direct replacement for Lazarus `.lpi` project metadata and Delphi-style project metadata use cases.

This request is focused on the Pascal language-server side only. VS Code extension integration, task generation, debug integration, and UI behavior are later concerns unless Codex identifies a language-server boundary that must be shaped now to avoid rework.

The desired architecture is a common Nexus project ancestor with Pascal-specific project behavior implemented in a descendant:

```text
TNXProject
  TNXPascalProject
```

Pascal is the first Nexus project type, but it should not be treated as the only possible Nexus project type.

## Background

The current codebase already contains Pascal-side project code centered around `TNXPascalProject`.

That class appears to contain fields such as project file name, project root, source root, output root, target platform, toolchain, FPC build options, and variables.

That direction is correct, but the architecture should be expanded so Nexus project files can serve as canonical project descriptors instead of relying on `.lpi`, `.dpr`, or separate tool-specific project metadata.

The `.nxp` file should eventually be the authoritative project file for Nexus Pascal projects.

This request is not asking for implementation yet. It asks Codex to inspect the current Pascal language-server project code and return a structured work plan for making the Pascal-side NXProject model functional and extensible.

## Current Architecture Rule

Nexus project handling should be modeled as a general project system with Pascal as the first concrete project type.

The base project type should own concerns common to all Nexus project files.

Pascal-specific behavior should live in `TNXPascalProject`.

The project file should be capable of representing both automatically discovered/default paths and user-managed project paths.

## Current Concern

The current project model appears to be Pascal-specific without a clear common ancestor for future Nexus project types.

The current model also needs a clearer policy for path ownership.

There will be paths that the system can auto-discover or auto-load, such as:

- FPC unit/source paths
- Lazarus/LCL paths when needed
- toolchain-derived paths
- platform-derived paths

There will also be user-generated or user-edited paths, such as:

- additional unit paths
- additional include paths
- project-specific source paths
- custom library/search paths
- paths added after initial discovery

The architecture should avoid mixing these into an indistinguishable list if doing so would make later behavior fragile.

The system needs to support the likely future requirement that auto-loaded paths can be pulled into the project and then inspected or modified by the user.

That policy is not fully settled yet, so Codex should call out viable design options and risks rather than assuming one without explanation.

## Desired Final State

The Pascal language-server project system should have a clear inheritance structure:

```text
TNXProject
  TNXPascalProject
```

`TNXProject` should represent common Nexus project file identity and shared project behavior.

Likely common concerns include:

- project name
- project kind/type
- project file name
- project root
- variables
- serialization/deserialization identity
- base path resolution
- project version/schema version if needed
- common validation surface

`TNXPascalProject` should represent Pascal-specific concerns.

Likely Pascal concerns include:

- source root
- output root
- main program/package/library file if applicable
- target platform
- toolchain
- FPC build options
- Pascal search paths
- Lazarus/LCL paths when applicable
- generated compile options for language-server use

The design should treat `.nxp` as the canonical Nexus Pascal project file format.

The Pascal project should eventually be able to replace `.lpi` project metadata and Delphi-style project metadata for Nexus Pascal workflows.

## Required Review

Codex should inspect the current Pascal language-server project-related code and return a structured work plan.

The review should identify:

- current project-related units/classes
- whether a usable `TNXProject` ancestor already exists
- what should move from `TNXPascalProject` into `TNXProject`
- what should remain Pascal-specific
- how `.nxp` serialization should represent project identity and Pascal configuration
- how path lists should be modeled
- how automatically discovered paths should be distinguished from user-managed paths
- how path resolution should work relative to project root and variables
- where validation should live
- whether any existing project-service or wizard code must change to support the model

## Pathing Requirements

The work plan should explicitly address path ownership.

At minimum, it should consider whether paths should be modeled as separate categories, such as:

```text
System-discovered paths
Toolchain-derived paths
Framework-derived paths
Project-owned paths
User-added paths
```

Codex should determine whether those categories need separate classes/records, separate lists, or path-entry metadata.

The design should support both:

- paths that are automatically discovered and refreshed from FPC/Lazarus/toolchain context
- paths that the user intentionally adds, removes, edits, or overrides

The plan should consider the risk that auto-refreshing discovered paths could overwrite user intent if the ownership model is not clear.

## Work Plan Requirements

The returned work plan should include:

- a summary of the current state
- the proposed class structure
- the proposed file/unit structure
- proposed serialization shape for `.nxp`
- proposed path model
- proposed validation model
- migration impact on existing `TNXPascalProject` code
- risks and open questions
- exact files Codex expects to modify
- compile/test steps Codex expects to run after approval

The plan should not begin implementation.

## Constraints

Do not treat this work request as implementation authorization.

Do not edit code until Kevin directly authorizes implementation.

Keep immediate scope on the Pascal language-server side.

Do not expand into VS Code UI, task generation, debug integration, or project tree behavior unless a language-server boundary must be defined now.

Do not assume `.lpi` compatibility is required. The goal is replacement, not compatibility emulation.

Do not design this as Pascal-only forever. Pascal is the first concrete Nexus project type, not the only future project type.

Avoid creating a path model where user-managed paths and auto-generated paths become indistinguishable if that would create future overwrite or refresh bugs.

## Acceptance Criteria For The Work Plan

The work plan is acceptable if it clearly explains:

- where `TNXProject` should live
- how `TNXPascalProject` should descend from it
- what state belongs in the base class
- what state belongs in the Pascal descendant
- how `.nxp` should serialize the base and Pascal-specific data
- how automatic and user-managed paths should be represented
- how FPC and Lazarus path discovery should fit without overriding user intent
- what exact implementation steps Codex proposes
- what compile/test validation Codex proposes

The work plan is not acceptable if it only proposes small patches around the current `TNXPascalProject` class without addressing the project inheritance and path-ownership model.

## Compile Requirements

The returned plan should identify the Pascal compile command or project build path Codex expects to use for validation.

If the current repo does not have a known reliable compile command, Codex should say so and propose the closest available validation path.

## Manual Test Requirements

The returned plan should propose manual tests for at least:

- loading a minimal `.nxp`
- loading a Pascal `.nxp` with project paths
- resolving project-root-relative paths
- preserving user-added paths
- applying auto-discovered FPC paths
- applying Lazarus/LCL paths only when needed
- verifying that generated language-server compile options reflect the project model
