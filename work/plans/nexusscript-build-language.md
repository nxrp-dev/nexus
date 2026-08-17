# Work Plan: NexusScript Build Language

## Inputs

- Human-owner request in conversation: design a Build script language and its
  validator, as a replacement for psMake and the script/parsing portion of the
  current Nexus build tooling.
- Current NexusScript compiler, dependency model, composition/reference rules,
  and declarative validator under `NexusTools/Script`.
- Current NexusTask language, parser, resolver, target projection, executor,
  actions, scripts, fixtures, and tests under `NexusTools/Task`.
- Current NexusBuild project loader, planner, and executor under
  `NexusTools/Build`.
- Existing architecture plan `work/plans/nexustask-declarative-build-system.md`
  as design history, not as authority over the current NexusScript contract.
- Repository architecture-change protocol and folder instructions.

This is a work plan only. It authorizes no implementation, build, migration,
archive, deletion, or runtime execution.

## Objective

Define one NexusScript-based Build language, describe it declaratively in
`Build.Validator.nxscript`, and move build-script interpretation onto the
existing generic NexusScript compiler and Validator.

The completed architecture replaces:

- psMake as the repository/build/deployment orchestration language;
- NexusTask's custom lexer, parser, source model, scalar resolver, structural
  expansion resolver, and duplicate language-level validation;
- JSON or other ad hoc script loading in NexusBuild where the same build
  information belongs in the Build document.

It retains and reshapes useful runtime behavior rather than rewriting working
process execution without cause: action implementations, ordered execution,
target selection, diagnostics, planning/inspection, and Pascal/Lazarus build
planning remain ordinary Pascal responsibilities downstream of a validated
compiled NexusScript document.

## Architectural Boundary

```text
Build source (`*.Build.nxscript`, decorative convention only)
    -> generic NexusScript compilation
       - modules
       - references
       - composition
       - source/provenance
       - dependency-cycle handling
    -> validation against Build.Validator.nxscript
    -> Build document adapter
    -> semantic planning and target selection
    -> ordered action execution
```

The generic NexusScript compiler must not know about builds, targets, actions,
files, Git, npm, FPC, Lazarus, Inno Setup, psMake, or NexusBuild.

`Build.Validator.nxscript` defines the structural Build vocabulary. Pascal code
implements behavior that cannot be expressed as structural validation, such as
path resolution, process invocation, target selection, filesystem checks, exit
status, and action-specific runtime planning.

There will be no second Build lexer, parser, reference syntax, include syntax,
composition system, source-range model, or generic tree model.

## Language Shape

### Document association

An executable Build document explicitly associates with the Build validator:

```text
doctype "Build.Validator.nxscript";
```

The filename convention remains decorative. Build selection comes from the
document's explicit doctype association and the API/command being invoked, not
from parsing filename components.

### Definition order

All Build definitions use NexusScript's settled `Kind Name` order:

```text
LazBuild BuildLanguageServer {
    Project: "../../../NexusTools/LS/nexusls.lpi";
    Quiet: true;
}
```

The current NexusTask `Name Action` interpretation is not retained. A migrated
declaration such as `BuildLanguageServer LazBuild` becomes
`LazBuild BuildLanguageServer`.

### Root build and ordered steps

`Build` is the root definition kind. Action definitions are direct children in
declaration order. `Group` provides named nested sequencing without performing
an external action itself.

```text
Build BuildNexusInstallerWin64 {
    Group Stage {
        DeletePath CleanStage {
            Path: "../../../dist/nexus-win64";
            Recursive: true;
            MissingOk: true;
        }

        LazBuild BuildLanguageServer {
            Project: "../../../NexusTools/LS/nexusls.lpi";
            Quiet: true;
        }
    }

    InnoSetup PackageInstaller {
        Script: "../../../NexusTools/Installer/win64/NexusSetup.iss";
    }
}
```

Execution is pre-order and declaration-ordered: a `Build` or `Group` is entered,
then each applicable child runs in source order. Action implementations do not
control child traversal.

### Targets

The old parenthesized target list is removed because parentheses already mean
NexusScript composition. Applicability is an ordinary validated property:

```text
LazBuild BuildApplication {
    Targets: [Debug, Release];
    Project: Application.lpi;
}
```

Rules:

- `Targets` is optional and contains unique scalar text values;
- no `Targets` property means the definition applies whenever its parent does;
- an explicit list means the definition applies only when the selected target
  occurs in that list;
- an excluded parent excludes its complete subtree;
- target comparison follows the Build contract and must be decided once during
  contract drafting, rather than inheriting an accidental parser comparison;
- target selection is a planning/runtime concern, not NexusScript conditional
  syntax and not a generic Validator feature.

The initial contract will preserve current single-target execution. It will not
introduce Boolean target expressions, negation, matrices, or arbitrary
conditions.

### Reuse and external documents

Build reuse uses settled NexusScript facilities:

- `module` exposes definitions under an explicit alias;
- definition composition reuses and specializes groups or actions;
- ordinary references reuse scalar configuration values;
- normal NexusScript cycle, collision, precedence, and provenance rules apply.

Example:

```text
module Common "Common.Build.nxscript";
doctype "Build.Validator.nxscript";

Build Release {
    Group Prepare (Common.Prepare) {}
}
```

There is no replacement for the old `<"file":Node>` syntax. It is removed,
not translated into a second expansion mechanism.

`include` does not imply Build execution. It retains only its NexusScript
artifact-set meaning. Build execution starts from the selected root definition
in the entry compiled document; module, doctype, and include dependencies do
not become implicit build roots.

### Values and references

Properties use the existing NexusScript `ValueExpression` model. Text,
integers, Booleans, arrays, references, and text composition remain available
where the validator permits them.

The Build layer consumes effective compiled values. It must not reparse source
text or implement a second scalar-substitution language.

Relative filesystem paths resolve against the source document that declared
the effective property. An override therefore resolves from the overriding
declaration's document, while an inherited property retains its declaration
provenance. This preserves reusable external build definitions without making
path behavior depend on the process working directory.

### Names and selection

- Build and action names use ordinary NexusScript definition names.
- Child names are unique within their effective parent under core compilation
  rules.
- A file may contain reusable non-root definitions and one or more `Build`
  roots.
- The command/API selects a Build root by name when more than one is available.
- A single Build root may be selected implicitly; zero or ambiguous roots are
  errors for execution but remain legal for reusable module documents.

## Initial Build Vocabulary

The first validator covers the behavior already exercised by current Nexus
build and installer scripts. It does not import obsolete psMake actions merely
for compatibility.

Structural kinds:

- `Build`
- `Group`

Executable action kinds:

- `Trace`
- `WriteTextFile`
- `CopyFile`
- `DeletePath`
- `Archive`
- `Git`
- `Npm`
- `Fpc`
- `LazBuild`
- `InnoSetup`

The contract inventory will record every property for these actions, including
required/optional status, scalar category, finite values, defaults, path
semantics, and whether text lists remain delimited text or become proper
NexusScript arrays. At minimum it must cover the properties currently consumed
by `obNXTaskActions.pas`:

- common: `Targets`;
- Trace: `Message`;
- WriteTextFile: `Path`, `Text`;
- CopyFile: `Source`, `Destination`, `Overwrite`, `Recursive`,
  `CleanDestination`, `ExcludeNames`;
- DeletePath: `Path`, `Recursive`, `MissingOk`;
- Archive: `Operation`, `Source`, `Destination`, `Overwrite`, `Recursive`,
  `ExcludeNames`;
- Git: `Repository`, `Directory`, `Branch`, `Submodules`;
- Npm: `Command`, `Script`, `Arguments`, `Executable`, `WorkingDirectory`;
- Fpc: `Source`, `Executable`, `OutputDirectory`, `OutputName`, `SearchPath`,
  `UnitOutputDirectory`;
- LazBuild: `Project`, `BuildAll`, `Quiet`, `Executable`,
  `PrimaryConfigPath`, `LazarusDirectory`;
- InnoSetup: `Script`, `Quiet`, `Executable`, `Arguments`, `Defines`,
  `OutputDirectory`, `OutputBaseFilename`, `WorkingDirectory`.

Before freezing the validator, each current NexusTask script and each current
NexusBuild project-loading field will be mapped to this vocabulary. A property
with no current required use will not be generalized speculatively.

## Build Validator Design

Create `NexusTools/Build/validator/Build.Validator.nxscript` with:

- `doctype` association to the existing NexusScript self-validator;
- `UnknownDefinitions: Reject`;
- one `Definition` rule for every accepted Build/action kind;
- `UnknownProperties: Reject` for every kind;
- exact required properties and scalar/effective categories;
- finite `AllowedValues` where a real enum exists, such as archive operation;
- `Parents` rules that permit actions only under `Build` or `Group` as
  appropriate;
- `Children` rules on `Build` and `Group` permitting the action vocabulary and
  enforcing any justified cardinality;
- names required for Builds, groups, and executable actions;
- ordinary scalar arrays for `Targets` and any list properties converted from
  delimiter-encoded strings.

`Parents` and `Children` remain independent according to the current Validator
contract. No reciprocal declaration is required merely to satisfy the
self-validator.

The validator will be validated against `Validator.nxscript`, and positive and
negative Build documents will be validated against it.

Do not add regex, predicates, callbacks, expressions, or Build-specific logic
to the generic Validator. If a concrete Build constraint cannot be expressed
with the current validator vocabulary, classify it as either:

1. a Build semantic/runtime check; or
2. a genuine generic validator gap requiring a separately reviewed contract
   amendment.

## Runtime Ownership

### NexusScript

Owns generic parsing, compilation, references, composition, modules, source
ranges, provenance, and dependency cycles. It remains domain-neutral.

### NexusScript Validator

Owns declarative structural validation of the compiled Build document against
`Build.Validator.nxscript`.

### NexusBuild

Becomes the owner of Build-language adaptation, selection, planning,
inspection, and execution. Its current Pascal/Lazarus planning behavior remains
available as direct services or action implementations instead of being
encoded in another file parser.

### NexusTask

Acts as the migration source for action implementations and verified behavior.
After parity is established, its custom language front end is removed. The
final architecture must not leave NexusTask and NexusBuild as two public Build
languages with overlapping responsibilities.

The implementation plan must decide whether the `NexusTask` executable is
removed outright or temporarily retained as a thin invocation alias only after
checking current external use. No compatibility alias is presumed by this
plan.

## Semantic Checks Outside the Declarative Validator

The Build adapter/planner owns checks that depend on execution meaning:

- selected Build root exists and selection is unambiguous;
- selected target is valid for the requested invocation;
- action kinds have registered runtime implementations;
- paths resolve from declaration provenance;
- filesystem inputs exist when the action requires them;
- output paths and working directories are coherent;
- cross-property requirements that cannot be expressed structurally;
- process/tool discovery and command construction;
- dependency/process failures and exit codes.

These checks produce source-aware diagnostics tied to the relevant compiled
definition/property ranges. They do not mutate the compiled NexusScript
document.

## Migration Safety Boundary

The existing NexusTask and NexusBuild paths remain usable while the new Build
validator, adapter, and executor path are constructed beside them.

No production build or installer script is cut over until the new path can:

- compile and validate every migrated repository Build document;
- produce the same target projection and ordered action plan;
- reproduce action command lines and filesystem intent;
- run the repository's actual staged build and installer construction;
- match expected diagnostics for representative invalid scripts.

Cutover is one final stage. Legacy parsers are not incrementally modified to
become NexusScript parsers.

## Implementation Stages

### Stage 1: Freeze the Build-language contract

- Inventory current NexusTask scripts/actions and NexusBuild project fields.
- Identify the subset of psMake capabilities still required by current Nexus
  workflows; do not treat unused historical features as requirements.
- Write the concise Build language contract covering roots, action ordering,
  targets, reuse, path provenance, diagnostics, planning, and execution.
- Produce representative Build source for the installer pipeline and ordinary
  FPC/Lazarus builds.
- Bring any genuine language-level ambiguity back to the human owner as a
  specific example before implementation.

Acceptance: every syntax form has NexusScript semantics, every runtime concept
has one owner, and no old parser construct survives without a current use.

### Stage 2: Write and self-validate Build.Validator.nxscript

- Add the validator under `NexusTools/Build/validator`.
- Describe the exact initial definition/action vocabulary.
- Add focused positive and negative validator fixtures.
- Validate the Build validator against the existing Validator validator.
- Prove unknown actions, unknown properties, missing required properties,
  wrong scalar categories, illegal nesting, and invalid finite values fail.

Acceptance: valid Build documents pass declaratively and structural failures do
not depend on action-class code.

### Stage 3: Add the Build document adapter

- Compile Build source through `TNexusScriptCompilationSession`.
- Validate the entry compiled document through its explicit doctype.
- Map compiled Build/action definitions into a small runtime plan model, or let
  the planner read compiled definitions directly where that remains clear.
- Preserve effective-value and source provenance.
- Add source-aware Build semantic diagnostics without duplicating structural
  validation.

Acceptance: no NexusTask lexer/parser/model/resolver unit is referenced by the
new loading path.

### Stage 4: Port target planning and action execution

- Move or reshape the current useful action implementations behind NexusBuild's
  Build runtime.
- Keep traversal in one executor and actions limited to their own behavior.
- Implement Build-root selection and current single-target applicability.
- Retain plan/inspect output so execution can be reviewed without side effects.
- Ensure tool invocation uses argument arrays rather than shell command-string
  construction where the current implementation already does so.

Acceptance: compiled, validated Build documents produce deterministic ordered
plans and execute through one registry/runtime.

### Stage 5: Integrate Pascal project building

- Map the current NexusBuild JSON-loaded project information to explicit Build
  definitions/properties or focused `Fpc`/`LazBuild` action configuration.
- Reuse `TNXPascalProject`, `TNXFPCBuildOptions`, and current planners where they
  remain useful runtime models.
- Remove JSON/ad hoc loading only after equivalent Build documents are proven.
- Avoid reproducing the full FPC option surface in the first validator unless
  current project files actually require it.

Acceptance: NexusBuild no longer needs a separate script/configuration parser
for behavior represented by the Build language.

### Stage 6: Migrate repository scripts beside the legacy path

- Convert all current `.nxtask` samples and production scripts to NexusScript
  `Kind Name` syntax and explicit `doctype` association.
- Replace parenthesized targets with `Targets` properties.
- Replace external node expansion with modules and composition.
- Convert delimiter-encoded lists to arrays where the contract selects arrays.
- Add migrated installer staging, packaging, and combined Build documents.

Acceptance: every production script compiles, validates, and produces an
expected plan without invoking the old parser.

### Stage 7: Prove replacement parity

- Compare old and new plan/inspection output for every migrated script.
- Compare action order, target applicability, resolved paths, defaults, command
  lines, and declared filesystem effects.
- Execute safe focused action tests in isolated temporary directories.
- Run the real Nexus Win64 staging and Inno Setup pipeline from an absent
  ignored `dist` directory, verify representative payload and exclusions, then
  remove generated output.
- Build and run the relevant NexusScript, Validator, NexusBuild, and Build
  runtime test suites.

Acceptance: the new path fully performs current repository builds and installer
construction without manual supplementation.

### Stage 8: Final cutover

- Switch NexusBuild's public Build command path to the validated NexusScript
  implementation.
- Remove the custom NexusTask lexer, parser, source model, resolver, expansion
  syntax, and duplicate structural validator.
- Remove obsolete `.nxtask` scripts and fixtures after their replacements pass.
- Remove JSON/ad hoc Build project loading that has been replaced.
- Remove or explicitly justify any remaining NexusTask executable/API surface.
- Update installer staging so the correct final Build executable and validator
  documents are distributed.

Acceptance: there is one Build language, one generic parser/compiler, one
declarative Build validator, and one Build execution path.

### Stage 9: Final verification and archive

- Run clean builds of NexusScript, NexusBuild, affected test modules, and the
  installer pipeline.
- Run all focused and full registered tests.
- Search the final tree for old parser/resolver units, `.nxtask` production
  references, old `Name Action` examples, parenthesized target syntax, and
  direct JSON Build loading.
- Confirm `NexusTools/Script/src` contains no Build vocabulary.
- Create and validate a fresh source archive outside generated distribution
  directories.

## Test Matrix

### Compilation and declarative validation

- minimal valid Build;
- multiple Build roots and explicit selection;
- reusable module with no executable root requirement;
- unknown definition kind;
- unknown property;
- missing required property;
- wrong Boolean/integer/text/array category;
- invalid finite value;
- illegal root and parent placement;
- child-name collision after composition.

### Reuse and provenance

- local composition;
- module-qualified composition;
- scalar reference and text composition;
- inherited property resolved relative to its declaration file;
- locally overridden property resolved relative to the overriding file;
- module/dependency cycle diagnostics;
- included document does not execute implicitly.

### Targets and ordering

- no target restriction;
- matching and nonmatching explicit target;
- excluded parent excludes subtree;
- child declaration order;
- composed group order;
- multiple roots require selection;
- plan/inspect has no side effects.

### Actions

- one positive and one validation-negative fixture per action kind;
- defaults match the approved Build contract;
- paths and working directories are source-aware;
- process argument construction is deterministic;
- nonzero child exit is reported correctly;
- filesystem actions use isolated temporary roots in tests.

### Replacement parity

- all current production `.nxtask` scripts;
- installer staging and package construction;
- current NexusBuild FPC plan;
- current NexusBuild Lazarus plan;
- representative psMake capabilities that remain current requirements.

## Documentation Deliverables

- concise Build language contract;
- `Build.Validator.nxscript` as the machine-valid structural contract;
- action/property reference generated or maintained from the same approved
  vocabulary;
- migration table from NexusTask and current NexusBuild fields;
- examples for modules, composition, targets, planning, and execution;
- CLI usage and diagnostic behavior;
- explicit statement that filename conventions are decorative.

## Risks and Controls

- **Accidentally rebuilding NexusScript inside NexusBuild:** reject any new
  Build lexer, parser, reference resolver, composition engine, or generic tree
  loader.
- **Treating the declarative validator as an execution engine:** keep paths,
  targets, tools, side effects, and process status in the Build planner/runtime.
- **Blind psMake compatibility growth:** require a current script or accepted
  workflow for every migrated capability.
- **Cutting over before parity:** preserve the current production path until
  the new path passes real installer construction.
- **Path changes through reuse:** test declaration provenance explicitly.
- **Two permanent Build products:** make removal/consolidation part of final
  acceptance, not deferred cleanup.
- **Validator/runtime drift:** test each registered action against a matching
  validator rule and fail if either side lacks the other.

## Implementation Decisions

These choices do not reopen the NexusScript language contract. They must be
resolved while drafting the Build contract and validator:

- case sensitivity of Build names, target names, and action registration;
- final Build CLI command spelling and root-selection option;
- which delimiter-encoded current properties become arrays immediately;
- whether `TNXPascalProject` remains the internal FPC/Lazarus planning model;
- whether any verified external integration requires a temporary NexusTask
  invocation alias after cutover.

Any choice that changes observable Build-language behavior must be documented
with a minimal example and approved in the Build contract. Repository layout,
unit names, and internal adapter class shapes remain implementation choices.

## Delegation

No sub-agent delegation is proposed for the initial contract and validator
pass. The Build vocabulary, validator, adapter boundary, and migration mapping
form one tight semantic seam and should be reviewed coherently. If later
implementation is approved, isolated fixture migration or action-level tests
may be delegated only after the contract and ownership boundaries are fixed.

## Approval Gate

This plan stops before implementation. After review, direct human-owner
authorization is required before creating the Build validator, modifying
NexusBuild or NexusTask, migrating scripts, building, testing, deleting legacy
code, or creating an implementation archive.
