# Work Plan: NexusScript Named Array Entry Lookup Refinement

## Inputs

- Source request: the human owner's request to propose a correction for the
  false lookup cycle encountered while moving schema-shaped definitions into
  an explicit `Tables: [...]` array.
- Related discussion and fixed decisions:
  - arrays are explicitly declared by `[ ... ]` and remain ordered arrays;
  - `_nx` metadata preserves entry identity for generic JSON consumers;
  - references are generic NexusScript references, not foreign-key behavior;
  - the compiler completes lookup and reference projection before emission;
  - JSON emission is mechanical and Mustache templates perform no lookup,
    inference, or domain logic;
  - established scoping, composition, rebinding, and projection contracts are
    not open for redesign in this correction.
- Existing language plans:
  - `work/plans/nexus-declarative-language.md`;
  - `work/plans/nexusscript-array-reference-composition.md`.
- Current implementation:
  - `NexusTools/Script/src/obNexusScriptCompiler.pas`;
  - `NexusTools/Script/src/obNexusScriptModel.pas`;
  - `NexusTools/Script/tests/tsNexusScriptTests.pas`.
- Reproduction input:
  `NexusTools/Script/tests/fixtures/json/ExplicitTables.nxscript`, where
  `@Demo.Tables.PERSON` currently reports
  `NXS5002 Value dependency cycle at Tables`.
- Repository constraints: preserve all unrelated worktree changes, follow
  `.ai/standards/pascal.md`, and stop for human review if implementation
  reveals that an established language contract must change.

## Summary

Refine compiled-value evaluation so an explicitly qualified path can traverse
an array property that is already being evaluated and resolve one of that
array's named entries without re-entering evaluation of the entire property.

The current cycle is false. While `Tables` evaluates its entries, evaluation
of `ADDRESS` follows `@Demo.Tables.PERSON`. Downward lookup finds the `Tables`
property and unconditionally calls `EvaluateProperty`. Because `Tables` is
already marked `Resolving`, the compiler reports a whole-property dependency
cycle before it attempts to select `PERSON`.

The correction will retain the whole-property cycle guard, add entry-level
evaluation state, and centralize named-array-entry resolution. A resolving
array may serve as an addressable container, but only the requested entry is
evaluated on demand. Re-entry into that same entry remains a real cycle.

This is an evaluator-granularity correction, not a new lookup feature and not
a change to NexusScript scope rules.

## Verified Findings

- The established lookup contract requires:
  - single-segment references to inspect the current scope only;
  - the first segment of a qualified reference to match the current scope, an
    enclosing scope, or an explicit module alias;
  - all remaining segments to resolve strictly downward;
  - no implicit sibling lookup;
  - every reference to resolve during compilation.
- `@Demo.Tables.PERSON` from a definition inside `Demo.Tables` satisfies that
  contract: `Demo` explicitly selects an enclosing scope, then `Tables` and
  `PERSON` are strict downward traversal.
- Named scalar and structural array entries are already addressable. Existing
  tests cover `@Items.Label`, `@Items.Local`, and
  `@Items.Local.Value` and assert exact array-item provenance.
- Array entry order, effective names, duplicate detection, complete
  whole-array reference results, composition merging, effective-scope
  rebinding, and structural projection are already established behaviors.
- `ResolveDown` currently calls `EvaluateProperty` immediately after finding
  any property, before checking whether the next path segment selects a named
  array entry.
- `EvaluateProperty` has one `Resolving` flag for the complete property.
  `EvaluateValue` evaluates array items sequentially, but compiled array items
  have only an `Evaluated` flag and no in-progress state.
- `FindNamedItem` searches `EffectiveName`. Explicit entry names and inline
  definition names are available before full entry evaluation, while the
  effective name of an unnamed reference entry may require that entry's
  reference to resolve.
- Merely skipping `EvaluateProperty` when the array is resolving would handle
  an already-evaluated earlier entry, but it would not correctly support a
  later entry, an as-yet unresolved effective name, or a genuine entry cycle.
- The current explicit-`Tables` reproduction fails before JSON emission or
  Mustache rendering. The defect is in compiler evaluation, not in the JSON
  emitter or templates.

## Architecture Problem

The compiler currently treats dependency state at property granularity while
the language exposes named entries inside an array as independently
addressable values.

For ordinary property references, re-entering a resolving property correctly
signals a value dependency cycle. For a path that continues into a named array
entry, however, the array property is both:

- the value currently coordinating evaluation of all its entries; and
- the addressable container through which one distinct entry is selected.

The single property-level `Resolving` flag conflates those roles. It cannot
distinguish legal lookup of a distinct entry from illegal recursion into the
same value. This produces the false `Tables` cycle and makes success depend on
whether the target entry happened to be completed before lookup.

The evaluator must track the smallest addressable dependency node. Properties
remain dependency nodes, and named array entries become dependency nodes when
lookup enters an array that is currently being evaluated.

## Target Contract

### Owner

The NexusScript compiler owns all reference lookup, dependency evaluation,
cycle detection, and completed projection. The compiled value model owns only
the minimal state required to represent evaluation progress and results.

The JSON emitter serializes the completed compiled model. Mustache templates
consume that serialized model without performing lookup or reconstructing
references.

### Lookup behavior

- `@Demo.Tables.PERSON` resolves from an entry below `Demo.Tables` by the
  already-established ancestor-qualified, strictly-downward lookup rules.
- `@PERSON` from a sibling entry does not gain implicit sibling lookup and
  remains unresolved unless `PERSON` is a member of the current scope.
- Module-qualified, local, ancestor-qualified, and structural downward paths
  retain their current first-segment and traversal rules.
- A path ending at an array property still requires the complete property
  result and does not bypass whole-property cycle detection.
- A path continuing through an array property selects a named entry using the
  final effective-name rules already used by arrays.
- Selecting a structural entry and continuing farther down the path uses the
  entry's completed structural projection and the existing strict downward
  traversal.

### Entry evaluation behavior

- Introduce an entry-aware evaluator operation owned by the compiler, such as
  `ResolveNamedArrayItem`, rather than teaching callers or consumers how to
  inspect partially evaluated arrays.
- When the containing array property is not resolving, retain the normal
  complete-property evaluation path before entry selection.
- When the containing array property is resolving, do not recursively invoke
  complete-property evaluation merely to enter the array.
- Locate and complete the requested entry on demand:
  - an explicit entry name is addressable from `EntryName` before the entry's
    body is complete;
  - an inline definition without an explicit entry name is addressable by its
    declared definition name;
  - an unnamed reference entry is evaluated as needed to establish the
    referenced definition's effective name;
  - ordinary scalar entries without an effective name remain unaddressable by
    name.
- Entry evaluation must be order-independent. Both an earlier and a later
  named entry may be referenced through the explicit array path.
- Add an in-progress state to `TNexusScriptCompiledValue` so recursive
  evaluation of the same entry produces the existing deterministic value-cycle
  diagnostic category instead of recursing indefinitely or being mistaken for
  a whole-property cycle.
- Keep the property-level guard for true property cycles and whole-array
  dependency cycles.
- Clear in-progress state through `try/finally`; do not leave a value marked as
  resolving after a diagnostic or failed projection.
- Preserve the current owned results and provenance:
  `ResolvedValue` identifies the exact winning array entry, scalar effective
  text is copied as today, and structural references materialize the same
  complete receiver-named projection as today.

### Composition and effective names

- Resolve against the effective array after composition contributors have
  been merged according to the existing precedence rules.
- Do not look through discarded contributor entries or bind against a source
  definition instead of the effective composed definition.
- Preserve replacement-in-place ordering, local-last precedence, inherited
  reference rebinding, and duplicate effective-name diagnostics.
- If on-demand name establishment discovers a duplicate, compilation still
  fails through the existing duplicate-name contract; lookup must not choose a
  duplicate as if the array were valid.

### State flow

```text
reference path
  -> existing scope/first-segment selection
  -> strict downward property selection
  -> complete property normally
     OR, only when continuing into a resolving array,
        resolve and complete the requested entry
  -> continue downward through the completed entry when requested
  -> materialize the existing scalar/array/structural result
  -> emitter serializes the completed result
```

No domain-specific interpretation is added at any stage.

## Scope

- `NexusTools/Script/src/obNexusScriptCompiler.pas`
  - separate whole-property evaluation from entry selection when downward
    lookup enters a resolving array;
  - add the compiler-owned named-entry resolution/evaluation helper;
  - retain deterministic cycle diagnostics and existing projection behavior.
- `NexusTools/Script/src/obNexusScriptModel.pas`
  - add only the minimal compiled-value in-progress state needed for entry
    cycle detection;
  - preserve current ownership and cloning behavior. Transient resolving state
    must not be copied as a completed artifact result.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - add focused lookup, order-independence, cycle-boundary, provenance, and
    scoping regressions.
- `NexusTools/Script/tests/fixtures/json/ExplicitTables.nxscript`
  - retain as the downstream explicit-array reproduction and post-compiler
    smoke input; do not reshape its model or templates under this plan.

## Out Of Scope

- Changing the established NexusScript scoping or qualified-name rules.
- Adding implicit sibling lookup or a dictionary/object-by-name source type.
- Changing array syntax, order, composition precedence, duplicate behavior,
  effective-name rules, or inherited-reference rebinding.
- Changing reference projection depth, receiver naming, ownership, or
  provenance.
- Adding schema, table, field, primary-key, foreign-key, or other domain logic
  to the compiler.
- Reshaping the schema-generation NexusScript models into `Tables: [...]`.
- Changing `_nx`, the generic JSON shape, JSON emission, manifest behavior,
  Mustache templates, or SQL/inForce parity scripts.
- Modifying production NexusSchema.
- Refactoring unrelated compiler evaluation or cleaning the existing dirty
  worktree.

The later schema-model and template migration remains separately reviewable.
This correction only removes the compiler defect that currently blocks a valid
explicit-array model from compiling.

## Staged Implementation Plan

### Stage 1: Lock the failing contract in compiler tests

Before changing the evaluator, add focused tests that reproduce the false
cycle without involving JSON or Mustache:

- an array entry references an earlier structural entry through an explicit
  ancestor-qualified array path;
- the same case with the target declared later proves order independence;
- a path continues through the target entry to one of its properties;
- the resulting reference retains exact `ResolvedValue` provenance and the
  existing completed structural projection;
- an unqualified sibling-entry reference remains unresolved.

Confirm the positive cases fail specifically because of the current
whole-property `NXS5002` guard before editing production code.

### Stage 2: Add entry-level evaluation state

Add transient `Resolving` state to compiled values and use it at the entry
evaluation boundary.

- Check the entry guard only when evaluation is actually requested.
- Report a deterministic value dependency cycle for re-entry into the same
  entry.
- Set and clear the guard with `try/finally`.
- Keep `Evaluated` as completion state.
- Do not copy a transient in-progress flag through `CloneValue` or projection
  cloning.
- Leave the existing property-level guard in place.

Compile and run the compiler suite at this checkpoint.

### Stage 3: Centralize named-entry resolution during active array evaluation

Refactor the array branch of `ResolveDown` to distinguish:

1. a path ending at the property, which uses normal whole-property evaluation;
2. a path continuing through a completed or idle array property, which uses
   normal property completion followed by entry lookup;
3. a path continuing through the same array property while it is resolving,
   which delegates to the compiler-owned entry resolver.

The entry resolver will use already-known declared entry identity first and
evaluate only the values necessary to establish unresolved effective names.
It will return a completed `TNexusScriptCompiledValue` or no match. It will not
alter scope selection, search enclosing siblings, or expose partially completed
values to the caller.

If the selected entry is structural and more path segments remain, continue
through its completed `StructuralDefinition` using the existing strict
downward algorithm. If it is the terminal segment, return it through the
existing direct-value result so current projection/provenance handling remains
centralized in `EvaluateValue`.

Compile and run the compiler suite at this checkpoint.

### Stage 4: Prove genuine cycles and effective-array behavior remain intact

Add or retain negative tests for:

- a direct property dependency cycle;
- a whole-array dependency cycle;
- two named array entries that recursively reference one another;
- a named entry that recursively references itself;
- a direct structural reference cycle retaining `NXS5004`;
- an unresolved named entry retaining `NXS5001`;
- duplicate effective array entry names retaining `NXS5005`.

Exercise a composed array case to confirm lookup sees the final winning entry,
keeps replacement position, and preserves effective-scope rebinding. Exercise
an unnamed referenced-definition entry to confirm its established effective
name remains addressable after on-demand evaluation.

### Stage 5: Re-run the explicit `Tables` reproduction

Run the existing CLI/model path with
`NexusTools/Script/tests/fixtures/json/ExplicitTables.nxscript` and confirm:

- compilation no longer reports a false cycle at `Tables`;
- `@Demo.Tables.PERSON` resolves to the exact `PERSON` array entry;
- the completed projection contains the information already defined by the
  referenced entry;
- the compiler introduces no schema-specific logic.

Do not adjust the generic JSON shape, isolated schema models, or Mustache
scripts in this stage. Report the corrected compiler result for review before
resuming that separately approved migration.

## Sub-Agent Delegation

No sub-agent delegation is recommended for this implementation. The change is
a tight integration seam across one recursive lookup function, one recursive
evaluator, transient compiled-value state, and their shared regression suite.
Splitting those edits would create overlapping ownership in the same compiler
and test files, while the worktree already contains related uncommitted work.

Main Codex should perform the approved implementation, preserve unrelated
changes, compile after each structural stage, review the final diff, and stop
for human direction if the required mechanism exceeds this contract.

## Verification Plan

### Compilation

```powershell
lazbuild NexusTools\Script\NexusScript.lpi
lazbuild NexusTools\Script\tests\NexusScriptTestModule.lpi
```

### Automated tests

Run the NexusScript compiler suite through the repository test host:

```powershell
output\NexusTestHost\nxtest_host.exe --module NexusTools\Script\tests\lib\x86_64-win64\NexusScriptTestModule.dll run-suite NexusScript.Compiler
```

The focused assertions must cover:

- earlier and later named-entry targets;
- terminal entry and continued structural paths;
- exact resolved-entry provenance;
- unchanged structural projection;
- explicit qualification versus rejected implicit sibling lookup;
- composed effective-array lookup and rebinding;
- property, whole-array, entry, and structural cycle boundaries;
- unresolved and duplicate-name diagnostics.

### Reproduction

Run the NexusScript CLI against the explicit-`Tables` fixture using the same
manifest/output path already used by the isolated schema-generation work.
Record the command and resulting JSON path in the implementation report. The
acceptance criterion for this plan is successful compiler resolution; SQL
parity remains outside this plan.

### Focused review

```powershell
rg -n "Resolving|ResolveNamedArrayItem|FindNamedItem|EvaluateProperty|EvaluateValue" NexusTools\Script\src NexusTools\Script\tests
rg -n "foreign|primary key|schema|table|field" NexusTools\Script\src\obNexusScriptCompiler.pas NexusTools\Script\src\obNexusScriptModel.pas
git diff --check
```

Review the focused diff to confirm no lookup branch broadens first-segment
scope selection, no consumer performs resolution, transient state is not
cloned, and no unrelated dirty file is overwritten.

## Risks And Questions

- On-demand lookup must not return a forward entry before that entry has a
  completed scalar or structural result. The entry-level guard and evaluator
  helper are required together; bypassing only the property guard is not an
  acceptable correction.
- Effective names derived from unnamed reference entries require evaluation.
  The resolver must establish those names without treating source order as
  lookup precedence or silently accepting duplicates.
- Composition contributors may still be in intermediate state while an
  effective entry is evaluated. Lookup must operate on the effective merged
  array, never on discarded contributors.
- Cycle diagnostics must remain category-correct: value/entry dependency
  cycles use the value-cycle category, while structural projection cycles keep
  `NXS5004`.
- `EvaluateValue` currently marks a value evaluated in a `finally` block even
  after diagnostics. Implementation must preserve current compiler failure
  behavior and must not expose a failed partial value as a successful lookup.
- There are no open language-design questions in this plan. If implementation
  shows that the correction requires changing scope rules, effective-name
  rules, projection semantics, composition behavior, or the consumer model,
  stop and ask the human owner instead of expanding the work.

## Approval Gate

This work plan is for review only. No compiler, model, test, fixture, emitter,
template, or schema-generation implementation begins until the human owner
explicitly authorizes this plan.
