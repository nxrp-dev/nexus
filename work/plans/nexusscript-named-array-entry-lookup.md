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

The correction will retain the whole-property cycle guard, separate effective
array preparation from entry-body evaluation, add explicit entry-level
evaluation states, and centralize named-array-entry resolution. Composition
will first assemble the final winning entries without evaluating their bodies.
Only after that effective array exists may its entries be evaluated normally or
on demand. A resolving array may then serve as an addressable container, while
re-entry into the same entry remains a real cycle.

This is an evaluator-granularity correction, not a new lookup feature and not
a change to NexusScript scope rules.

## Verified Findings

- The established lookup contract requires:
  - single-segment references to inspect the current scope only;
  - the first segment of a qualified reference to match the current scope, an
    enclosing scope, or an imported root;
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
- Array composition currently evaluates every contributor before it clears and
  rebuilds the effective value's `Items`. While a contributor is evaluating,
  the effective value can therefore still contain only the items cloned from
  the latest source property rather than the final winning entry set.
- `ApplyProperty` stores the composition layers in
  `CompositionContributors`, but initializes the merged value by cloning the
  higher-precedence property. Inspecting that value's current `Items` during
  contributor evaluation is not equivalent to inspecting the effective array.
- Evaluating a contributor entry against the effective scope can legitimately
  refer back through the effective array property. The final array structure
  must therefore exist before contributor entry bodies are evaluated.
- `EvaluateValue` currently sets `Evaluated := True` unconditionally in a
  `finally` block. A value that emitted an unresolved-reference, cycle,
  projection, or duplicate-name diagnostic can consequently appear completed
  during the remainder of compilation.
- `EvaluateProperty` clears its property-level `Resolving` flag only on the
  ordinary return path rather than through `try/finally`.
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

Two additional timing problems must be corrected with that granularity.

First, a composed array is not safely addressable until its effective winning
entry set exists. The current evaluator evaluates contributor bodies before it
folds those contributors into `AValue.Items`. A callback from a contributor
body cannot find the final winner by inspecting that incomplete value, and
resolving directly against a contributor would give `ResolvedValue` the wrong
identity after the contributor is discarded or replaced.

Second, entry-level on-demand evaluation requires completion to mean success.
The current `Evaluated` Boolean records that control left `EvaluateValue`, even
when evaluation emitted a fatal diagnostic. That state is insufficient once a
later lookup can encounter the same partially materialized value.

The evaluator therefore needs two explicit concepts:

- array preparation state, distinguishing an unprepared array from one whose
  final effective winning entries have been assembled; and
- value evaluation state, distinguishing pending, resolving, successfully
  completed, and failed values.

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
- Replace the ambiguous completed/not-completed Boolean behavior with an
  explicit value evaluation state equivalent to:
  - pending: evaluation has not started;
  - resolving: evaluation is currently active;
  - completed: evaluation finished successfully;
  - failed: evaluation produced a diagnostic that prevents a valid result.
- Evaluator operations return success or failure and propagate that result.
  They must not infer local success merely from returning control or from the
  global diagnostic count.
- A failed value is terminal for that compilation. Later lookup returns failure
  without exposing its partial scalar, array, or structural result and without
  repeatedly evaluating it.
- When the containing array property is not resolving, retain the normal
  complete-property evaluation path before entry selection.
- When the containing array property is resolving, do not recursively invoke
  complete-property evaluation merely to enter the array.
- Entry lookup during active property evaluation is permitted only after that
  array's effective structure is prepared. It must never inspect the incidental
  pre-merge contents of a composed value.
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
- Re-entry into an entry whose evaluation state is `resolving` produces the
  existing deterministic value-cycle diagnostic category instead of recursing
  indefinitely or being mistaken for a whole-property cycle.
- Keep the property-level guard for true property cycles and whole-array
  dependency cycles.
- Clear the property-level `Resolving` flag through `try/finally`.
- Transition a value to `completed` only after successful evaluation. A
  diagnostic or propagated child failure transitions it to `failed`; exception
  unwinding must not leave it marked `resolving`.
- Preserve the current owned results and provenance:
  `ResolvedValue` identifies the exact winning array entry, scalar effective
  text is copied as today, and structural references materialize the same
  complete receiver-named projection as today.

### Effective array preparation

- Add a compiler-owned preparation operation, such as
  `PrepareEffectiveArray`, with preparation state equivalent to unprepared,
  preparing, prepared, and failed. Preparation is distinct from entry-body
  evaluation because a prepared array can contain pending or resolving entries.
- For an ordinary non-composed array, preparation establishes the addressable
  identities of its existing entries without evaluating their bodies.
- For a composed array, preparation processes contributors in established
  precedence order and constructs the final `AValue.Items` before evaluating
  any winning entry body.
- Resolve each contributor to an array shape. A contributor that is a
  whole-array reference resolves its target property and prepares that target's
  effective array without forcing completion of every target entry.
- Establish each contributor entry's effective identity without materializing
  its body:
  - use an explicit `EntryName` when present;
  - otherwise use an inline definition's declared name;
  - otherwise, for a definition-reference entry, resolve the target symbol and
    use its declared definition name without creating the structural
    projection yet;
  - otherwise leave the entry unnamed.
- This requires reference target/identity resolution to remain separable from
  scalar or structural result materialization. It is an internal compiler
  phase distinction, not a new source-language reference category.
- Validate duplicate effective names within each source array during
  preparation, including an ordinary non-composed array and each composition
  contributor. The same name in a later contributor remains an override under
  the established composition contract.
- Fold cloned entries into `AValue.Items` using the existing rules: replace a
  matching named entry in place, append new named entries, and always append
  unnamed entries.
- Mark the array prepared only after the complete final winning-entry set has
  been assembled successfully. Unresolved identity prevents preparation from
  succeeding. Preparation re-entry is a real value dependency cycle and uses
  the existing deterministic value-cycle diagnostic category.
- After preparation, evaluate only entries in the final effective
  `AValue.Items`. Do not fully evaluate discarded contributor entries.
- Evaluate winning entries against the effective composed scope so inherited
  references retain their existing rebinding behavior.
- All named lookup, including lookup originating from a winning entry body,
  selects from the prepared effective `AValue.Items`, never directly from
  `CompositionContributors`.
- `ResolvedValue` must therefore identify the actual winning entry stored in
  the effective array, not the contributor value from which it was cloned.
- Preserve replacement-in-place ordering, local-last precedence, inherited
  reference rebinding, and duplicate effective-name diagnostics.
- Do not look through discarded contributor entries or bind against a source
  definition instead of the effective composed definition.

### State flow

```text
composed array property evaluation
  -> mark property resolving
  -> prepare contributor array shapes and entry identities
  -> fold final winning entries into the effective array
  -> mark effective array prepared
  -> evaluate winning entries
       -> an entry reference follows existing scope selection
       -> strict downward lookup reaches the prepared array
       -> select the actual effective winning entry
       -> complete that entry on demand, with entry cycle detection
       -> continue downward through its completed structure when requested
  -> mark array completed only after every required result succeeds
  -> clear property resolving through try/finally
  -> emitter serializes only the completed compiled result
```

No domain-specific interpretation is added at any stage.

## Scope

- `NexusTools/Script/src/obNexusScriptCompiler.pas`
  - separate effective-array preparation from entry-body evaluation;
  - separate reference target/entry-identity resolution from result
    materialization where array preparation requires it;
  - assemble composed winning entries before evaluating those entries;
  - separate whole-property evaluation from entry selection when downward
    lookup enters a resolving array;
  - add the compiler-owned named-entry resolution/evaluation helper;
  - propagate evaluation/preparation success and retain deterministic cycle
    diagnostics and existing projection behavior.
- `NexusTools/Script/src/obNexusScriptModel.pas`
  - replace ambiguous value completion state with the minimal explicit
    evaluation state needed to distinguish pending, resolving, completed, and
    failed values;
  - add effective-array preparation state because a prepared array may still
    contain pending entries;
  - preserve current ownership and cloning behavior. Transient resolving state
    and failed partial state must not be copied as completed artifact results.
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

### Stage 2: Establish explicit evaluation and preparation states

Replace unconditional `Evaluated := True` behavior with explicit success
propagation and terminal state transitions.

- Give compiled values evaluation states equivalent to pending, resolving,
  completed, and failed.
- Give arrays preparation states equivalent to unprepared, preparing, prepared,
  and failed.
- Make evaluation and preparation operations return success or failure.
- Transition to completed/prepared only on success.
- Propagate unresolved references, child failures, cycles, invalid projections,
  and duplicate names as failure to the containing operation.
- Reject later access to failed partial results without re-evaluating them.
- Clear the property-level `Resolving` flag through `try/finally` while retaining
  it as the guard for true property and whole-array dependency cycles.
- Do not copy resolving, preparing, failed, or other transient state through
  `CloneValue` or projection cloning as if it were a completed artifact.

Add a focused failure-state test proving a value that reports a cycle cannot be
observed later as completed. Compile and run the compiler suite at this
checkpoint.

### Stage 3: Prepare effective arrays before evaluating entry bodies

Add the compiler-owned effective-array preparation phase.

- For each array contributor, obtain its array shape without completing all
  entry bodies.
- For a whole-array reference contributor, resolve the target property and
  recursively prepare its effective array shape.
- Establish entry identity from explicit names, inline declared names, and
  definition-reference target identity without materializing structural
  projections.
- Detect duplicate names within each contributor.
- Fold contributor entries into the final effective `AValue.Items` using the
  existing precedence, replacement-in-place, append, and unnamed-entry rules.
- Mark the array prepared only after the fold succeeds.
- Evaluate only the final winning entries, against the effective composed
  scope.

Add a composed-array regression in which a lower-precedence entry refers
through the effective array to another entry while a higher-precedence
contributor also exists. Assert that lookup returns the final winning entry,
that discarded entries are not exposed, and that replacement position and
rebinding remain unchanged.

Compile and run the compiler suite at this checkpoint.

### Stage 4: Centralize named-entry resolution during active array evaluation

Refactor the array branch of `ResolveDown` to distinguish:

1. a path ending at the property, which uses normal whole-property evaluation;
2. a path continuing through a completed or idle array property, which uses
   normal property completion followed by entry lookup;
3. a path continuing through the same array property while it is resolving,
   which requires the array to be prepared and delegates to the compiler-owned
   entry resolver.

The entry resolver selects only from the prepared effective `AValue.Items`.
Entry identities have already been established during preparation, so lookup
does not search contributor layers or evaluate discarded candidates. It
completes the selected winning entry on demand, returning success with that
entry or failure. It will not alter scope selection, search enclosing siblings,
or expose pending, resolving, or failed partial values to the caller.

If the selected entry is structural and more path segments remain, continue
through its completed `StructuralDefinition` using the existing strict
downward algorithm. If it is the terminal segment, return it through the
existing direct-value result so current projection/provenance handling remains
centralized in `EvaluateValue`.

Compile and run the compiler suite at this checkpoint.

### Stage 5: Prove genuine cycles and effective-array behavior remain intact

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
name remains addressable after identity preparation and on-demand body
evaluation. Confirm failed preparation and failed entry evaluation cannot be
returned by later references as successful completed values.

### Stage 6: Re-run the explicit `Tables` reproduction

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

This plan does not authorize or recommend sub-agent use. Implementation remains
local unless the human owner explicitly requests sub-agent use in the current
conversation. Plan approval and implementation approval do not authorize delegation.

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
- composed effective-array lookup and rebinding where a contributor entry
  references both an inherited winner and a higher-precedence replacement;
- whole-array reference contributors using the prepared target shape;
- replacement position and exact `ResolvedValue` identity in the final
  effective array;
- property, whole-array, entry, and structural cycle boundaries;
- unresolved and duplicate-name diagnostics;
- failed entries and failed array preparation never appearing completed to a
  later lookup.

### Reproduction

Run the NexusScript CLI against the explicit-`Tables` fixture using the same
manifest/output path already used by the isolated schema-generation work.
Record the command and resulting JSON path in the implementation report. The
acceptance criterion for this plan is successful compiler resolution; SQL
parity remains outside this plan.

### Focused review

```powershell
rg -n "PrepareEffectiveArray|ResolveNamedArrayItem|EvaluationState|PreparationState|Resolving|Evaluated|EvaluateProperty|EvaluateValue" NexusTools\Script\src NexusTools\Script\tests
rg -n "foreign|primary key|schema|table|field" NexusTools\Script\src\obNexusScriptCompiler.pas NexusTools\Script\src\obNexusScriptModel.pas
git diff --check
```

Review the focused diff to confirm no lookup branch broadens first-segment
scope selection, no consumer performs resolution, transient state is not
cloned, and no unrelated dirty file is overwritten.

## Risks And Questions

- Effective-array preparation must not accidentally materialize entry bodies.
  Doing so would recreate the contributor callback into an array whose final
  winning-entry set does not yet exist.
- Reference-derived entry names require target-identity resolution without
  structural projection. If current reference helpers cannot keep those phases
  separate cleanly, stop for review rather than evaluating contributor bodies
  as a shortcut.
- Whole-array reference contributors can recursively require another array
  shape. Preparation-state cycle detection must distinguish that invalid cycle
  from legal entry-body lookup into an already prepared array.
- On-demand lookup must not return an entry until its scalar or structural body
  has completed successfully. Bypassing only the property guard remains an
  unacceptable correction.
- Lookup must operate only on prepared effective entries. It must never fall
  back to the higher-precedence property's incidental cloned `Items` or search
  contributor layers directly.
- Cycle diagnostics must remain category-correct: value/entry dependency
  cycles use the value-cycle category, while structural projection cycles keep
  `NXS5004`.
- Converting evaluation procedures to return success must preserve diagnostic
  accumulation while preventing failed partial results from becoming
  completed. Do not use a before/after global diagnostic count as the local
  state machine.
- There are no open language-design questions in this plan. If implementation
  shows that the correction requires changing scope rules, effective-name
  rules, projection semantics, composition behavior, or the consumer model,
  stop and ask the human owner instead of expanding the work.

## Approval Gate

This work plan is for review only. No compiler, model, test, fixture, emitter,
template, or schema-generation implementation begins until the human owner
explicitly authorizes this plan.
