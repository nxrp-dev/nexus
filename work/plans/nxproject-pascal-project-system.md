# Work Plan: NXProject Pascal Project System

## Inputs

- Source request: `work/requests/nxproject-pascal-project-system.md`
- Related workflow notes:
  - `.ai/protocols/architecture-change.md`
  - `.ai/protocols/codex-workplan-format.md`
  - `.ai/protocols/subagents.md`
  - `.ai/standards/pascal.md`
- Existing constraints:
  - This is a work plan only.
  - No implementation begins until Kevin directly authorizes it.
  - Scope stays on the Pascal language-server side.
  - Do not expand into VS Code UI, task generation, debug integration, or project tree behavior.
  - `.nxp` is the canonical project descriptor target; this is replacement architecture, not `.lpi` compatibility emulation.

## Summary

The current Pascal project model is a useful first pass, but it is not yet a Nexus project system. `TNXPascalProject` directly owns common project identity, variable resolution, project-root path resolution, Pascal target/toolchain state, and FPC build options. The LS project service creates `.nxp` files by hand-writing minimal JSON instead of constructing and saving the project object.

The correction should introduce a real common project ancestor:

```text
TNXProject
  TNXPascalProject
```

The implementation should also add an explicit path-entry ownership model so discovered/toolchain/framework paths do not become indistinguishable from project-owned or user-added paths.

## Verified Findings

- `NexusLS/src/obNXPascalProject.pas` currently defines `TNXPascalProject = class(TNXPersistObject)` at line 52.
- `TNXPascalProject` owns common project fields now: `ProjectFileName`, `ProjectRoot`, `SourceRoot`, `OutputRoot`, and `Variables`.
- `TNXPascalProject` also owns Pascal-specific fields now: `ProjectKind`, `TargetPlatform`, `Toolchain`, and `FPCBuildOptions`.
- `ResolvePath` currently resolves variables, then resolves relative paths against `ProjectRoot`.
- `ApplyToBuildOptions` and `ResolveBuildOptionPaths` mutate the stored `FPCBuildOptions` object while resolving paths.
- `NexusLS/src/service/obNXLSProjectService.pas` currently creates `.nxp` content in `NXLSMinimalNexusProjectJSON` by manually writing JSON with `class`, `name`, and `projectRoot`.
- `NexusLS/src/obNXLSLSPModel.pas` currently configures CodeTools from `TNXLSSettings.FPCOptions`, populated from initialization options.
- `NexusLS/src/obNXLSSettings.pas` currently supports `program`, `codeToolsConfig`, and `fpcOptions`, but no `.nxp` project-file setting.
- Existing tests cover `TNXPascalProject` variable/path resolution and FPC build-option argument generation in `NexusLS/NexusLSTestModule/tsNXLSCoreTests.pas`.
- No existing usable `TNXProject` ancestor was found.

## Architecture Problem

The current model mixes three responsibilities:

- common Nexus project identity and path resolution
- Pascal-specific project behavior
- generated/effective compiler configuration

It also mixes raw stored project state with resolved/effective state. `ApplyToBuildOptions` resolves paths by mutating `FPCBuildOptions`, which means loading/saving and language-server configuration can accidentally rewrite project intent.

Path ownership is also underspecified. User-managed paths and auto-discovered/toolchain/framework paths need distinct identity, because refresh logic must not overwrite user intent.

## Target Contract

### Base Project

- Owner: `TNXProject`
- Responsibilities:
  - project name
  - project type/kind identity for tools
  - `.nxp` file name
  - project root
  - project format/schema version
  - user variables
  - built-in variable expansion without mutating user variables
  - project-root-relative path resolution
  - common validation surface
- State flow:
  - stores raw project state
  - resolves values and paths on demand
  - does not persist generated/effective compiler state
- Rendering/input/persistence behavior:
  - not applicable to rendering/input
  - persists through `TNXPersistObject`
  - serializes real class identity through the existing `Class` field

### Pascal Project

- Owner: `TNXPascalProject`
- Responsibilities:
  - Pascal project kind
  - main file/program/package/library file
  - source root and output root
  - Pascal target platform
  - Pascal toolchain
  - Pascal path entries
  - raw FPC build options
  - generated effective FPC options for CodeTools/language-server use
- State flow:
  - stores raw user/project configuration
  - stores path entries with explicit origin/ownership
  - generates effective FPC arguments from raw project state plus selected discovered paths
  - does not mutate stored raw path values while generating effective options
- Rendering/input/persistence behavior:
  - not applicable to rendering/input
  - `.nxp` persists base project fields plus Pascal-specific descendant fields

### Path Entry Model

Recommended model: path-entry metadata in one typed list, not separate unrelated string lists.

Use a path entry object with at least:

- `Path`
- `PathKind`
- `Origin`
- `Enabled`
- `SourceId`
- optional display/diagnostic fields if needed later

Recommended Pascal path kinds:

- source
- unit
- include
- library
- framework
- object
- executable search

Recommended path origins:

- project-owned
- user-added
- system-discovered
- toolchain-derived
- framework-derived

This keeps ordering and merging explicit while preserving ownership.

Rejected path model for this pass: dumping all paths into `FPCBuildOptions.Files.UnitPaths` or similar lists as the canonical project state. Those lists are compiler-option output surfaces, not enough to describe path ownership.

## Proposed File And Unit Structure

Expected new files:

- `NexusLib/src/obNXProject.pas`
  - `TNXProject`
  - common project validation types
  - common path origin enum if kept project-wide
  - common path entry ancestor if useful

Expected modified files:

- `NexusLS/src/obNXPascalProject.pas`
  - make `TNXPascalProject` descend from `TNXProject`
  - keep Pascal-specific target/toolchain/build-option behavior here
  - add Pascal path entry/list classes if they are Pascal-specific
  - add effective FPC argument generation that does not mutate stored options
- `NexusLS/src/service/obNXLSProjectService.pas`
  - replace hand-written `.nxp` JSON with object construction and `TNXPascalProject.JSON`
  - use project validation for plan/create messaging where practical
- `NexusLS/src/obNXLSSettings.pas`
  - add a `.nxp` project file setting if LS initialization needs an explicit project-file boundary
- `NexusLS/src/obNXLSLSPModel.pas`
  - load/apply `.nxp` project configuration for CodeTools when configured or discovered
  - continue current initialization-option behavior only as a deliberate fallback until replaced
- `NexusLS/NexusLSTestModule/tsNXLSCoreTests.pas`
  - add or update tests for project serialization, path ownership, and effective FPC arguments
- `NexusLS/nexusls.lpi`
  - add new unit references if Lazarus project metadata requires it
- `NexusLS/NexusLSTestModule/NexusLSTestModule.lpi`
  - add new unit references if Lazarus project metadata requires it

Possible modified file:

- `NexusLib/src/obNXPersist.pas`
  - only if current persistence behavior cannot support the needed object/list shape
  - default expectation is no persistence-engine change

## Proposed Serialization Shape For `.nxp`

Use the existing `TNXPersistObject` JSON mechanism as the canonical shape, not hand-written lowercase JSON.

Representative shape:

```json
{
  "Class": "TNXPascalProject",
  "ProjectFormatVersion": 1,
  "Name": "MyProject",
  "ProjectType": "pascal",
  "ProjectFileName": "MyProject.nxp",
  "ProjectRoot": ".",
  "Variables": "BuildMode=Debug\n",
  "ProjectKind": "ppkProgram",
  "MainFile": "src/MyProject.lpr",
  "SourceRoot": "src",
  "OutputRoot": "output",
  "TargetPlatform": {
    "Class": "TNXPascalTargetPlatform",
    "TargetOS": "win64",
    "TargetCPU": "x86_64",
    "FPCMode": "objfpc"
  },
  "Toolchain": {
    "Class": "TNXPascalToolchain",
    "CompilerPath": "$(FPCBin)/fpc.exe",
    "FPCSourceRoot": "$(FPCSourceRoot)",
    "FPCUnitRoot": "$(FPCUnitRoot)"
  },
  "PascalPaths": {
    "Class": "TNXPascalPathList",
    "Items": [
      {
        "Class": "TNXPascalPathEntry",
        "PathKind": "ppathUnit",
        "Origin": "porProjectOwned",
        "Path": "src",
        "Enabled": true
      }
    ]
  },
  "FPCBuildOptions": {
    "Class": "TNXFPCBuildOptions"
  }
}
```

The exact enum names may change during implementation to match local style, but the architecture rule is fixed: persisted paths must carry ownership metadata.

## Proposed Path Model

Use path entries as project state.

Recommended classes:

```text
TNXProjectPathEntry
  Path
  Origin
  Enabled
  SourceId

TNXPascalPathEntry
  PathKind

TNXPascalPathList
```

Path origins:

- `project-owned`: created by the project template or project model
- `user-added`: intentionally added/edited by the user
- `system-discovered`: discovered from local environment
- `toolchain-derived`: derived from compiler/toolchain configuration
- `framework-derived`: derived from Lazarus/LCL/framework roots

Refresh policy:

- auto-refresh may replace entries with auto origins and matching `SourceId`
- auto-refresh must not replace `user-added` or `project-owned` entries
- if a user edits an auto entry, implementation should either convert it to `user-added` or preserve an explicit override flag

Open design choice for approval before implementation:

- Option A: edited discovered paths become `user-added`
- Option B: edited discovered paths keep their origin but get `UserOverride = True`

Recommendation: Option A for the first pass. It is simpler and makes ownership obvious.

## Proposed Validation Model

Add validation to `TNXProject` and override in `TNXPascalProject`.

Recommended shape:

```text
TNXProjectValidationMessage
  Severity
  Code
  Message
  Path

TNXProjectValidationResult
  Messages
  HasErrors
```

Base validation should check:

- project name
- project root
- project file name
- project format version
- duplicate variable names

Pascal validation should check:

- valid Pascal project kind
- main file presence when the kind requires it
- source/output root consistency
- missing required toolchain values when effective compiler options are requested
- invalid or duplicate path entries
- invalid Lazarus/LCL path usage when widget/LCL configuration requires it

The project service should use this validation surface for `PlanNexusProjectCreate` and `CreateNexusProject` once the model exists.

## Staged Implementation Plan

### Stage 1: Base Project Model

- Add `NexusLib/src/obNXProject.pas`.
- Implement `TNXProject` as the common `TNXPersistObject` ancestor.
- Move common state and behavior out of `TNXPascalProject`:
  - `ProjectFileName`
  - `ProjectRoot`
  - `Variables`
  - value/path resolution
  - built-in variable handling
  - validation skeleton
- Ensure built-in variable handling does not mutate user variables.
- Register `TNXProject` for persistence.
- Compile after this stage.

### Stage 2: Pascal Project Descendant

- Update `TNXPascalProject` to inherit from `TNXProject`.
- Keep Pascal state in `TNXPascalProject`:
  - `ProjectKind`
  - `MainFile`
  - `SourceRoot`
  - `OutputRoot`
  - `TargetPlatform`
  - `Toolchain`
  - `FPCBuildOptions`
- Add Pascal-specific built-in variables through an override or extension hook.
- Register Pascal project and nested Pascal persist classes.
- Add serialization round-trip tests.
- Compile after this stage.

### Stage 3: Path Ownership Model

- Add typed Pascal path entries/list.
- Migrate project path state away from plain compiler-option string lists as the canonical path store.
- Keep `FPCBuildOptions` as raw compiler option state, not path ownership state.
- Add methods to build effective FPC options/arguments from:
  - raw `FPCBuildOptions`
  - enabled Pascal path entries
  - selected toolchain/framework discovered paths
- Ensure effective option generation does not mutate stored project state.
- Add tests for preserving user-added paths and refreshing auto-derived paths without overwriting user intent.
- Compile after this stage.

### Stage 4: Project Service Integration

- Replace `NXLSMinimalNexusProjectJSON` hand-written JSON with a real `TNXPascalProject` instance.
- Set base and Pascal fields through the object model.
- Save generated `.nxp` through `TNXPascalProject.JSON`.
- Use project validation for plan/create feedback where practical.
- Add tests for generated project JSON and reload through `TNXPersistObject.CreateObjectFromJSON`.
- Compile after this stage.

### Stage 5: Language-Server Configuration Boundary

- Add an LS initialization boundary for `.nxp` project files.
- Recommended setting name: `projectFile` or `nexusProjectFile`.
- During initialize:
  - load explicit `.nxp` if provided
  - otherwise discover a project file in the workspace root only if the rule is deterministic
  - otherwise keep current initialization-options behavior as a fallback until the replacement path is complete
- Generate `EffectiveFPCOptions` from the loaded `TNXPascalProject`.
- Keep current `program`, `codeToolsConfig`, and raw `fpcOptions` support only as an intentional fallback, not as the canonical model.
- Add tests for CodeTools option generation from `.nxp`.
- Compile after this stage.

## Sub-Agent Delegation

- Proposed roles:
  - `NexusLS explorer` for read-only inspection of project-service, LSP initialization, and tests.
  - `NexusLS worker` for approved implementation in `NexusLS/`.
  - `NexusLib worker` only if `obNXProject.pas` is placed under `NexusLib/src/`.
- Ownership boundaries:
  - Main Codex owns final design decisions, integration, compile/test verification, and final report.
  - `NexusLib worker` owns only `NexusLib/src/obNXProject.pas` and any required project metadata updates.
  - `NexusLS worker` owns `NexusLS/src/obNXPascalProject.pas`, LS project service/settings/model changes, and LS tests.
- Main Codex responsibilities:
  - review sub-agent diffs
  - prevent duplicate path models
  - ensure stored project state and generated effective options stay separate
  - run final verification and create the archive after approved implementation
- Coordination risks:
  - `TNXProject` and `TNXPascalProject` inheritance changes cross unit boundaries, so edits must be sequenced.
  - Do not allow two workers to edit `obNXPascalProject.pas` or test files at the same time.

Delegation is useful for implementation after approval because NexusLib base model work and NexusLS Pascal integration can be separated after the base contract is settled.

## Verification Plan

Compile targets after each structural stage:

```text
lazbuild NexusLS\nexusls.lpi
lazbuild NexusLS\NexusLSTestModule\NexusLSTestModule.lpi
```

Focused greps after implementation:

```text
rg "TNXPascalProject = class\\(TNXPersistObject\\)" NexusLS NexusLib
rg "NXLSMinimalNexusProjectJSON|lProject.Add\\('class'|lProject.Add\\(\"class\"" NexusLS\src
rg "ResolveBuildOptionPaths|ApplyToBuildOptions" NexusLS\src
rg "FPCBuildOptions\\.Files\\.(UnitPaths|IncludePaths|LibraryPaths|FrameworkPaths).*Add|Assign" NexusLS\src
rg "ProjectFileName|ProjectRoot|Variables|ResolvePath" NexusLS\src NexusLib\src
```

Expected test additions:

- base project variable resolution
- base project root-relative path resolution
- Pascal `.nxp` serialization round trip
- Pascal path entry ownership serialization
- user-added path survives discovered-path refresh
- toolchain-derived path can be refreshed by `SourceId`
- generated FPC arguments include project/user/discovered paths in deterministic order
- generated FPC arguments do not mutate stored path entries or raw `FPCBuildOptions`
- project service creates loadable `TNXPascalProject` JSON
- LS initialization can build effective CodeTools options from `.nxp`

Manual tests after implementation:

- create a minimal `.nxp` through the project service and load it back
- load a Pascal `.nxp` with project-owned and user-added paths
- confirm project-root-relative paths resolve correctly
- confirm user-added paths are preserved after applying discovered FPC paths
- confirm Lazarus/LCL paths are applied only when needed by Pascal project configuration
- confirm generated language-server compile options reflect the project model

## Risks And Questions

- `TNXPersistObject` currently serializes `TStringList` as text. That may be acceptable for variables, but structured path ownership needs object/list persistence.
- Existing `TNXLSSettings` initialization options are still a live LS boundary. Decide whether the first implementation keeps them as fallback or moves immediately to `.nxp` only.
- Deterministic `.nxp` discovery needs a rule. An explicit `projectFile` setting is safer than guessing among multiple `.nxp` files.
- Current `ApplyToBuildOptions` mutates stored `FPCBuildOptions`. The replacement should generate effective options without mutation, which may require new method names and tests.
- Path origin names and Pascal path-kind enum names should be settled before implementation.
- Placement of `TNXProject` in `NexusLib/src/obNXProject.pas` is recommended because it is not LS-specific, but this creates a shared core project unit earlier than strictly needed by the LS.

Open questions for Kevin before implementation:

- Should edited discovered paths become `user-added`, or should they keep origin plus a `UserOverride` flag?
- Should LS initialization use `projectFile` or `nexusProjectFile` for the explicit `.nxp` path?
- Should Stage 5 keep current raw `fpcOptions` initialization support as a fallback during the transition?

## Approval Gate

No implementation begins until Kevin explicitly authorizes it.
