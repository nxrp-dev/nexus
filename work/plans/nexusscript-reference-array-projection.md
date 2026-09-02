# Work Plan: NexusScript Reference Array Projection

## Inputs

- Source request: direct human-owner request to define a work plan for finite
  definition-reference materialization.
- Language direction established in discussion:
  - references to definitions materialize directly accessible structural
    values while retaining target provenance;
  - arrays remain ordered collections and are fully evaluated in their owning
    definitions;
  - when a definition is materialized as the value of a reference, scalar
    arrays are copied;
  - non-scalar arrays are omitted entirely from the materialized copy;
  - an array is non-scalar when any effective entry is definition-valued;
  - named scalar entries remain scalar, while inline definitions and references
    resolving to definitions are non-scalar;
  - a mixed array containing any non-scalar entry is non-scalar as a whole.
- Current language contract:
  `C:\Users\kcollins\Downloads\nexus-declarative-language-contract.md`.
- Existing constraints:
  - keep the generic compiler domain-neutral;
  - do not modify production `NexusTools/Schema` before the parity gate;
  - do not replace references with consumer-interpreted text;
  - preserve unrelated worktree changes;
  - follow `.ai/standards/pascal.md` and the repository architecture protocol.

## Summary

Change definition-reference materialization from an unrestricted deep clone to
a finite reference projection. The source and ordinary compiled target remain
complete. A structural value created from a definition reference copies the
target's effective scalar properties, scalar arrays, and structural members,
but omits every non-scalar array throughout the projected definition tree.

This makes cyclic schema relationships finite without introducing pointers,
depth limits, unresolved references, consumer-side dereferencing, or textual
reference substitutes. The materialized root continues to retain provenance to
the complete resolved target.

The controlling rule is:

> Reference materialization copies scalar arrays and entirely omits non-scalar
> arrays. It does not change the complete effective definition that serves as
> the reference target.

## Verified Findings

- `TNexusScriptCompiledValue` currently owns `StructuralDefinition` and retains
  non-owning `ResolvedDefinition`, `ResolvedProperty`, and `ResolvedValue`
  provenance.
- Definition references are evaluated in
  `NexusTools/Script/src/obNexusScriptCompiler.pas` by binding the resolved
  target and calling the general `CloneDefinitionAs` operation.
- The same general compiled-definition cloning machinery is also used by
  composition, modules, and other compiler-owned copies. The projection rule
  therefore must not be inserted into the general clone operation.
- Arrays retain ordered compiled `Items`; they are not represented by a
  synthetic wrapper definition.
- Each compiled array item records its effective name, value kind, resolved
  targets, optional inline-definition provenance, scalar result, and optional
  structural definition.
- Inline definition entries use the dedicated `nsvDefinition` value kind.
- Named scalar items and scalar property references retain scalar effective
  values; references resolving to definitions own structural materializations.
- The schema parity fixtures now contain all fields as inline definitions in
  ordered `Fields` arrays: 493 in `inForceMain.Schema.nxscript` and 22 in
  `StormSpecific.Schema.nxscript`.
- Both full parity cases currently stop at `NXS5004` through
  `@inForce.PERSON`. The compiler reaches a recursive table relationship while
  deep-materializing the table's non-scalar `Fields` array.
- The isolated schema consumer uses genuine resolved-reference provenance; no
  text-reference fallback remains.
- The nine non-parity NexusScript tests pass. The two full parity tests expose
  the current structural cycle.
- Production `NexusTools/Schema` is unchanged.

## Architecture Problem

The current compiler treats a materialized definition reference as a complete
deep structural clone. That model cannot terminate when the target contains a
structural collection that eventually refers back to the target. Database
schema fields are a concrete example: a table owns a non-scalar `Fields` array,
and one of those fields may reference the same or another table.

The problem is not the source relationship. The relationship is valid, fully
resolved, and useful. The problem is copying an unbounded structural collection
into every reference value.

Removing or rewriting source references would lose language semantics.
Preserving a graph edge in the materialized result would require consumers to
dereference it. Arbitrary depth limits would make results context-dependent.
The correct boundary is to project a finite consumer-facing value: preserve
ordinary directly useful structure and scalar collections, but do not copy
structural collections into referenced values.

## Target Contract

### Owner

- Generic semantics and projection implementation:
  `NexusTools/Script/src`.
- Focused language and parity verification:
  `NexusTools/Script/tests` and `NexusTools/Script/parity`.
- Production NexusSchema remains read-only.

### Array classification

Classification uses the effective compiled entries after ordinary binding and
array evaluation:

- scalar text is scalar;
- compile-time text composition is scalar when it produces text;
- a reference resolving to a scalar property is scalar;
- an explicitly named scalar entry remains scalar;
- an inline definition entry is non-scalar;
- a reference resolving to a definition is non-scalar;
- any entry with an effective structural definition is non-scalar;
- an array containing any non-scalar entry is non-scalar as a whole.

Array entry names affect addressability and uniqueness, not scalar versus
non-scalar classification.

Nested arrays are not needed by the current schema use case. If the current
parser permits them, projection should classify them recursively: a nested
array is scalar only when every nested leaf entry is scalar. This applies the
same rule without inventing a separate collection category.

### Projection behavior

When a reference resolves to a definition:

1. bind and complete the resolved target in its original lexical and module
   context;
2. create a new reference projection named for the receiving member or array
   entry;
3. copy effective scalar properties and ordinary child definitions;
4. copy scalar arrays with their order, optional names, effective scalar
   values, and provenance intact;
5. omit a property entirely when its value is a non-scalar array;
6. apply the same omission rule recursively to ordinary child definitions
   copied into the projection;
7. retain the materialized root's resolved-target and source provenance.

An omitted array is absent from the projected definition. It is not emitted as
an empty array, unresolved value, placeholder, pointer, or metadata-only
member.

The complete resolved target remains unchanged and retains its evaluated
non-scalar arrays. Omission affects only the structural value owned by the
reference expression.

### Separation from other compiler copies

Introduce an explicit reference-projection operation rather than changing
`CloneDefinition` or `CloneDefinitionAs` globally.

- composition continues to flatten complete effective members;
- module imports continue to expose complete compiled roots under their declared names;
- ordinary compiled-model cloning continues to preserve complete values;
- inline definitions in their owning arrays remain complete;
- only structural values created by definition-reference evaluation apply the
  non-scalar-array omission rule.

### Cycle behavior

Cycles eliminated by omitted non-scalar arrays compile successfully.

Structural reference cycles that remain outside omitted arrays continue to be
compile-time errors. The existing cycle diagnostic must not be weakened into a
warning or silently ignored.

### Consumer behavior

Consumers traverse the projected reference value directly. They see scalar
arrays and ordinary copied members but cannot see omitted non-scalar arrays on
that value. Consumers do not perform reference resolution or filtering.

Consumers that care about origin may inspect the retained resolved-target
provenance. The generic compiler does not add schema-specific vocabulary or
meaning.

## Scope

- `NexusTools/Script/src/obNexusScriptCompiler.pas`
  - scalar-array classification;
  - dedicated reference-projection cloning;
  - integration with definition-reference evaluation;
  - preservation of names, ownership, and provenance.
- `NexusTools/Script/src/obNexusScriptModel.pas` only if a small explicit model
  field or helper is necessary to expose stable classification or provenance.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - focused projection, omission, scalar-array, nesting, provenance, and cycle
    tests.
- `NexusTools/Script/parity/PARITY.md`
  - replace the current cycle-blocked result with verified results if full
    parity is restored.
- Existing NexusScript schema fixtures and isolated consumer only if a test
  correction is necessary to exercise the approved semantics; do not rewrite
  genuine references or change their domain meaning.
- Fresh source archive after the approved implementation pass.

## Out Of Scope

- Any production `NexusTools/Schema` edit or cutover.
- A new reference syntax or separate relationship-reference category.
- Replacing `@` references with plain text.
- Consumer-side dereferencing or array filtering.
- Graph serialization, shared-object identity, back-reference nodes, lazy
  references, arbitrary recursion depths, or runtime resolution.
- Changes to array ordering, optional naming, effective-name uniqueness, inline
  definition syntax, or named lookup.
- Changes to composition precedence, module lookup, ordinary scope resolution,
  or scalar text composition.
- Omission of scalar arrays merely because their entries contain scalar
  property references.
- Opportunistic schema metadata, JSON, Mustache, or legacy parser redesign.
- Unrelated worktree changes.

## Staged Implementation Plan

### Stage 1: Lock down projection classification tests

Add focused compiler tests that establish the boundary before changing cloning:

- unnamed scalar array copies;
- named scalar array copies with order and effective names preserved;
- scalar property-reference array copies with effective values and provenance;
- inline-definition array is omitted;
- definition-reference array is omitted;
- mixed scalar and definition-valued array is omitted entirely;
- nested all-scalar array copies if nested arrays are currently accepted;
- nested array containing a definition-valued leaf is omitted;
- an ordinary non-array structural member still materializes;
- the complete resolved target retains every omitted array.

Assert member absence with normal compiled-model lookup rather than checking an
implementation-private flag.

### Stage 2: Separate reference projection from complete cloning

Add a dedicated function for cloning an effective definition as a reference
projection. It should:

- accept the effective target, projected parent, and receiving name;
- preserve kind, source range, module/provenance information, scalar values,
  and ordinary children;
- evaluate array classification from compiled item results;
- skip non-scalar array properties entirely;
- recursively project child definitions;
- use existing complete clone helpers for scalar values where safe;
- preserve clear ownership of every copied value and definition.

Do not add schema terms or flags to the generic model.

### Stage 3: Integrate definition-reference evaluation

Replace only the definition-reference materialization call with the new
projection operation. Keep target binding in the original lexical tree before
projection so qualified and inherited references resolve correctly.

Retain:

- receiving-member renaming;
- resolved target identity;
- reference/source provenance;
- idempotent evaluation state;
- existing cycle-stack behavior for cycles not cut by omission.

### Stage 4: Verify finite and still-invalid cycles

Add focused cases proving:

- a self-reference reachable only through a non-scalar array now compiles;
- a mutual reference reachable only through non-scalar arrays now compiles;
- the projected value entirely lacks those arrays;
- the complete original targets retain them;
- a direct ordinary-property structural cycle still fails with `NXS5004`;
- no cycle is misreported as unresolved lookup.

### Stage 5: Restore schema parity evidence

Run the complete inForce and Storm parity fixtures without modifying their
genuine references.

Expected result:

- both NexusScript fixtures compile;
- `Fields` remains present on original table and template definitions;
- materialized table references omit non-scalar `Fields` arrays;
- the isolated schema consumer still derives relationship identity from
  resolved-reference provenance;
- transformed metadata JSON matches the unchanged legacy baseline exactly;
- rendered Firebird output matches the unchanged legacy baseline exactly.

If parity still fails, report the exact remaining reference path or output
difference. Do not introduce another fallback.

### Stage 6: Final architecture and ownership review

Review the implementation for:

- no mutation of resolved target definitions during projection;
- no use-after-free or double ownership of projected definitions and values;
- no synthetic array wrapper;
- no schema-domain vocabulary under `NexusTools/Script/src`;
- no change to full cloning used by composition or modules;
- no hidden consumer-specific filtering;
- no production NexusSchema changes;
- no build artifacts inside source folders.

Create and validate the required source archive after all verification.

## Sub-Agent Delegation

This plan does not authorize or recommend sub-agent use. Implementation remains
local unless the human owner explicitly requests sub-agent use in the current
conversation. Plan approval and implementation approval do not authorize delegation.

## Verification Plan

### Clean builds

```powershell
lazbuild --build-all NexusTools\Script\NexusScript.lpi
lazbuild --build-all NexusTools\Script\tests\NexusScriptTestModule.lpi
```

### Test host

```powershell
.\output\NexusTestHost\nxtest_host.exe `
  .\output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll `
  run-all
```

Required outcome: every focused language test and both artifact-parity tests
pass. A process exit code alone is insufficient; inspect every reported test
status.

### Focused structural checks

- Search `NexusTools/Script/src` for schema-domain vocabulary and require no
  matches.
- Search for the new projection helper and prove it is called only from
  definition-reference materialization.
- Verify complete clone helpers remain used by composition/modules without the
  omission policy.
- Verify genuine `@` schema references remain in the parity fixtures.
- Verify the fixtures still contain 493 and 22 inline field definitions inside
  `Fields` arrays.
- Require an empty diff under `NexusTools/Schema`.
- Require no `.o`, `.ppu`, `.a`, `.dll`, or `.exe` files under
  `NexusTools/Script`.

### Archive

Run `scripts\New-NexusSourceArchive.ps1`, then inspect the ZIP and verify it
contains the compiler, tests, parity consumer, both `.nxscript` fixtures, this plan,
and no generated binaries.

## Risks And Questions

- Projection must classify arrays from effective compiled values, not source
  spelling. A reference to a scalar property remains scalar; a reference to a
  definition is non-scalar.
- A mixed array is omitted entirely. It must not be partially filtered because
  that would alter its order and meaning.
- Omission is recursive within the projected definition tree but must never
  mutate the complete target.
- Applying the rule inside general clone helpers would silently alter
  composition and modules; the dedicated projection boundary is mandatory.
- Scalar arrays containing named entries must retain names and order.
- Remaining structural cycles outside omitted non-scalar arrays are expected
  errors, not grounds to weaken cycle detection.
- Nested arrays should follow recursive scalar classification if supported;
  no new nested-array syntax or behavior is introduced by this work.
- No additional human decision is required for implementation unless the code
  reveals a value form that cannot be classified by the rules above without
  changing observable language behavior.

## Approval Gate

No implementation begins until the human owner explicitly authorizes this
plan. Creating, committing, and pushing this plan does not authorize compiler,
test, fixture, consumer, build, test, archive, or cutover work.
