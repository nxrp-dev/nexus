# Work Plan: NexusScript Array References and Composition

## Inputs

- Source request: attached design request for two missing NexusScript array
  behaviors:
  1. references to complete array-valued properties;
  2. effective-name array merging during inherited composition.
- Human-owner instruction: produce a work plan only; do not implement.
- Current language contract:
  `C:\Users\kcollins\Downloads\nexus-declarative-language-contract.md`.
- Current implementation and tests under `NexusTools/Script`.
- Existing constraints:
  - preserve array order, optional entry names, inline definitions, reference
    provenance, and current definition-reference projection behavior;
  - preserve left-to-right composition precedence with local values last;
  - preserve inherited-reference rebinding against the effective definition;
  - keep the generic compiler free of schema vocabulary;
  - do not modify production `NexusTools/Schema` before cutover;
  - preserve unrelated worktree changes;
  - follow `.ai/standards/pascal.md` and repository architecture protocols.

## Summary

Extend the compiled value and composition pipeline so arrays are complete
first-class effective values.

First, a property reference resolving to an array-valued property will own a
complete effective array result while retaining its source reference and
resolved-property provenance. Consumers can traverse the referenced array
directly without locating or dereferencing the original property.

Second, when composition combines same-name properties whose effective values
are arrays, merge their entries by effective name rather than replacing the
lower-precedence array. Named replacements retain their established position;
new named entries and all higher-precedence unnamed entries append in source
order. Non-array property replacement remains unchanged.

The controlling merge rule is:

> Apply array contributors in composition-precedence order. Replace an existing
> named entry in place when a higher-precedence entry has the same effective
> name; otherwise append the higher-precedence entry. Unnamed entries never
> match and always append.

## Verified Findings

- `TNexusScriptCompiledValue` currently records source `Kind`, ordered `Items`,
  entry/effective names, scalar effective text, owned structural definition,
  evaluation state, and non-owning resolved property/definition/value
  provenance.
- Compiled values currently have no explicit owned effective-value result for
  a reference whose target is an entire array.
- Property-reference evaluation currently evaluates the resolved property and
  copies only `EffectiveText` and `HasEffectiveText` to the reference value.
  It does not clone the target property's array items.
- Named individual array-entry references already resolve through
  `FindNamedItem` and retain `ResolvedValue` provenance. That path must remain
  distinct from whole-property array references.
- `CloneValue` already preserves complete ordered items, entry names, effective
  names, inline definitions, resolved targets, scalar results, structural
  values, and evaluation state.
- `CloneProjectionValue` intentionally applies definition-reference projection
  behavior and is not appropriate for ordinary whole-array property
  references or composition merging.
- Composition currently runs before ordinary value/reference binding.
- During composition, a higher-precedence same-name property completely
  replaces the lower-precedence property through `RemoveProperty` plus
  `CloneValue`.
- Composition sources are applied left to right, then local properties are
  applied last.
- Explicit entry names and inline-definition declared names are available
  before binding. The effective name of an unnamed reference entry is not
  reliably known until the reference resolves.
- Inherited references must bind against the final effective composed
  definition. Resolving contributor arrays in their source definitions before
  merging would violate that existing rule.
- Duplicate effective names within one source array are currently detected
  during array evaluation.
- Arrays may contain named and unnamed scalar values, inline definitions,
  definition references, mixed entries, and nested arrays.
- Current reference-array projection, schema consumer, and full inForce/Storm
  parity tests pass. Production `NexusTools/Schema` remains unchanged.

## Architecture Problem

### Whole-array references

The compiler models a reference expression and scalar effective text on one
compiled value, but it has no general representation for a reference whose
effective result is another complete collection value. Merely copying scalar
text loses the array. Pointing consumers at `ResolvedProperty.Value` would
make every consumer perform language-level dereferencing and would expose
target ownership instead of a self-contained compiled result.

The compiler must materialize an owned array result while separately retaining
the originating reference and resolved-property provenance.

### Array composition

The current same-name property override is correct for non-array properties
but too coarse for arrays. Replacing the complete inherited array discards
lower-precedence entries that have no higher-precedence counterpart.

Merging immediately inside the existing composition loop is also incorrect.
An unnamed reference entry may acquire its effective name only after binding,
and inherited references must rebind against the final effective composed
scope. The compiler therefore needs to preserve ordered contributor layers
until the effective definition exists, then resolve and merge them there.

## Target Contract

### Ownership

- Generic value, binding, and composition behavior:
  `NexusTools/Script/src`.
- Focused language and parity verification:
  `NexusTools/Script/tests` and `NexusTools/Script/parity`.
- Production NexusSchema remains read-only.

### Complete array-reference result

For:

```text
Thing Root {
    Values: [First: one, Second: two];
    Other: @Values;
}
```

`Other` retains:

- source kind and expression provenance identifying `@Values`;
- non-owning resolved-property provenance identifying `Values`;
- an owned effective array result containing complete cloned entries;
- source order;
- explicit and implicit effective names;
- scalar values;
- inline definitions;
- definition-reference entries using their already-defined projection
  semantics;
- nested arrays;
- entry-level reference and source provenance.

The owned result must not alias the target property's owned item list. Destroying
the reference result must not affect the target property, and vice versa.

The compiled model should represent the distinction explicitly: source
expression identity remains a reference, while the effective result is an
array. Prefer one owned `EffectiveValue`-style result over duplicating array
items into a reference node while leaving its effective type ambiguous.
Concrete field and class names remain implementation details, but consumers
must have one direct, documented route to the effective value and must not
dereference `ResolvedProperty` themselves.

References to scalar properties continue to expose effective text. References
to definitions continue to use structural reference projection. References to
named array entries remain unchanged.

Forward, local, qualified, inherited, and module-qualified array-property
references follow the existing lookup and rebinding rules.

### Array composition contributors

When same-name properties meet during composition:

- if both values are arrays, retain them as ordered precedence contributors
  for later effective merging;
- otherwise, keep the current higher-precedence whole-property replacement;
- an array versus non-array collision is ordinary property replacement, not an
  array merge and not a category ambiguity;
- contributors are ordered using existing precedence: inherited sources from
  left to right, then local last.

The contributor representation belongs to the compiler/compiled value model.
It is not a new source syntax, dictionary type, or consumer-visible collection
kind.

### Effective array merge

After composition establishes the effective definition, bind each contributor's
entries against that effective scope and determine each entry's effective name.
Then fold contributors from lowest to highest precedence:

1. begin with an empty effective array;
2. process entries in contributor source order;
3. if an entry is named and that effective name already exists, replace the
   existing entry at its current position;
4. if a named entry has no match, append it;
5. if an entry is unnamed, append it;
6. continue through every contributor, ending with the local contributor.

Example:

```text
Base.Fields    = [ID: one, Name: two, base-unnamed]
Derived.Fields = [Name: changed, Extra: three, local-unnamed]
```

produces:

```text
[ID: one, Name: changed, base-unnamed, Extra: three, local-unnamed]
```

The replacement entry is a complete higher-precedence entry. Do not recursively
merge its scalar, array, or structural contents merely because it replaced an
entry by name.

Effective names use the existing rules:

1. explicit array-local name;
2. otherwise the declared name of an inline or referenced definition;
3. otherwise unnamed.

Name comparison follows the compiler's existing identifier/name comparison.
The final array preserves effective-name uniqueness.

### Duplicate behavior

- Duplicate effective names inside one contributor/source array remain
  compile-time errors.
- The same effective name across different precedence contributors is a legal
  override.
- Duplicate detection must retain contributor boundaries long enough to
  distinguish those cases.
- Unnamed entries never participate in duplicate-name matching.

### Provenance

Every final entry retains the provenance of the contributor entry that won or
was appended. A replacement does not retain the lower-precedence entry as its
target; it occupies that entry's position but remains the higher-precedence
entry with its own source, reference, and definition provenance.

The final effective array should also retain enough property/contributor
provenance for diagnostics to identify duplicate names within a source array
and binding failures in the correct declaration.

## Scope

- `NexusTools/Script/src/obNexusScriptModel.pas`
  - owned effective value for non-scalar property-reference results, if needed;
  - ordered array-contributor representation and ownership, if needed.
- `NexusTools/Script/src/obNexusScriptCompiler.pas`
  - complete array-reference materialization;
  - preservation of source versus effective value identity;
  - deferred effective-scope array contributor binding and merge;
  - array-aware same-name property composition;
  - clone and ownership handling.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - focused whole-array reference and composition cases.
- `NexusTools/Script/parity/PARITY.md` only if verified parity documentation
  requires an updated statement.
- Fresh validated source archive after an approved implementation pass.

## Out Of Scope

- Source syntax changes.
- A separate dictionary/map type.
- Positional identity or positional override for unnamed entries.
- Recursive merging inside a replaced array entry.
- Changes to definition-reference projection or non-scalar-array omission.
- Changes to named individual array-entry references.
- Changes to scalar text composition.
- Changes to non-array composition precedence or replacement.
- Changes to module or scope lookup.
- Consumer-side dereferencing.
- Schema-specific behavior in the generic compiler.
- Production NexusSchema edits or cutover.
- Compatibility shims or unrelated refactoring.
- Changes to unrelated dirty worktree files.

## Staged Implementation Plan

### Stage 1: Lock down whole-array reference behavior

Add failing focused tests for:

- unnamed scalar array property reference;
- named scalar array property reference;
- mixed named and unnamed array property reference;
- inline-definition array property reference;
- array containing definition-reference entries;
- nested array property reference;
- forward array property reference;
- qualified array property reference;
- inherited array reference rebinding against the effective definition;
- reference-level `ResolvedProperty` provenance;
- entry-level names, order, values, structural results, and provenance;
- target and effective-array ownership independence.

Keep named individual array-entry tests unchanged as regression coverage.

### Stage 2: Add an owned effective array result

Extend the compiled value model with the smallest explicit representation for
an owned non-scalar effective result.

- A reference expression remains identifiable as `nsvReference`.
- Its resolved target remains non-owning provenance.
- Its effective array is independently owned.
- Destruction and cloning preserve one clear owner.
- Complete array cloning uses full compiled-value cloning, not
  definition-reference projection filtering on the array as a whole.
- Definition-valued entries inside the cloned array retain their already
  materialized projected structures.

Update property-reference evaluation so a resolved array property populates
the owned effective result after evaluating the target property. Do not set or
infer scalar text for the array.

### Stage 3: Lock down array composition behavior

Add failing focused tests for:

- inherited array with local additions;
- named replacement retaining the inherited position;
- two inherited sources with rightmost precedence;
- local named entry winning over every inherited source;
- new named entries appending in source order;
- lower and higher unnamed entries both preserved in deterministic order;
- mixed named and unnamed contributor arrays;
- explicit-name override of an implicit definition name;
- implicit definition-reference names resolved in the effective scope;
- duplicate names inside one contributor remaining errors;
- the same name across contributors acting as an override;
- non-array property replacement remaining unchanged;
- array-versus-non-array higher-precedence replacement remaining unchanged.

### Stage 4: Preserve array contributors during composition

Replace immediate whole-array replacement with explicit ordered contributor
retention only when both same-name property values are arrays.

- Preserve each contributor as a complete independently owned value.
- Preserve declaration/source boundaries for duplicate diagnostics.
- Preserve precedence order exactly.
- Do not evaluate inherited entries in their source scope.
- Continue using the existing path for non-array properties.

Avoid a general recursive collection-merge abstraction. This mechanism is
specific to same-name array-property composition.

### Stage 5: Resolve and merge in the effective scope

During binding of the effective composed definition:

- evaluate contributor entries against the effective definition;
- validate duplicates within each contributor;
- derive final effective names;
- fold contributors using replace-in-place/append rules;
- store one final ordered effective array;
- retain winning entry provenance;
- ensure later references to the property receive the merged array;
- ensure references inherited through composition see the final merged result.

The merge must be idempotent and must not rerun destructively when the property
is referenced multiple times.

### Stage 6: Integration and parity verification

Run all existing generic, projection, module, schema-consumer, and artifact
parity tests. Confirm:

- existing `Fields` arrays remain ordered and unique;
- definition-reference projection still omits non-scalar arrays only in
  projected definitions;
- ordinary whole-array references remain complete;
- composition and module complete cloning remain distinct from projection;
- inForce and Storm metadata JSON remain exact matches;
- rendered Firebird outputs remain exact matches.

If an existing fixture begins exercising array merging, verify the resulting
order directly rather than updating a baseline without explanation.

### Stage 7: Final architecture and ownership review

Review for:

- no aliasing of owned item lists between target and referenced arrays;
- no double-free or stale contributor ownership;
- no loss of entry/reference/source provenance;
- no accidental projection filtering in complete array references;
- no premature source-scope binding of inherited contributors;
- no positional matching of unnamed entries;
- no change to general non-array override behavior;
- no schema vocabulary in generic source;
- no production NexusSchema changes;
- no generated binaries under `NexusTools/Script`.

Create and validate the required source archive.

## Sub-Agent Delegation

- Proposed role: reuse the named `NexusScript parity worker` for the coherent
  compiler/model/test implementation.
- Worker ownership:
  - `NexusTools/Script/src` model and compiler changes;
  - focused tests;
  - parity execution and verified documentation update.
- Main Codex responsibilities:
  - review effective-value ownership and contributor lifecycle;
  - verify inherited references bind in the final effective scope;
  - reject projection-helper reuse in complete array copying;
  - independently run clean builds, every test, focused searches, and archive
    validation.
- Coordination risk: the model, composition loop, binder, and tests share tight
  ownership seams. One worker should receive the complete approved slice rather
  than splitting writes between agents.

## Verification Plan

### Clean builds

```powershell
lazbuild --build-all NexusTools\Script\NexusScript.lpi
lazbuild --build-all NexusTools\Script\tests\NexusScriptTestModule.lpi
```

### Full test host

```powershell
.\output\NexusTestHost\nxtest_host.exe `
  .\output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll `
  run-all
```

Inspect every reported status. Require all focused tests and both artifact
parity cases to pass; do not rely on process exit code alone.

### Focused checks

- Search the generic source for schema-domain vocabulary and require no hits.
- Prove complete array-reference copying does not call projection-filtering
  helpers.
- Prove general definition-reference projection remains unchanged.
- Prove array merge is entered only for same-name array-versus-array property
  composition.
- Prove unnamed entries are appended and never matched by position.
- Verify `NexusTools/Schema` has no diff.
- Verify genuine `@` references and 493/22 inline field counts remain in the
  parity fixtures.
- Verify no `.o`, `.ppu`, `.a`, `.dll`, or `.exe` files exist under
  `NexusTools/Script`.

### Archive

Run `scripts\New-NexusSourceArchive.ps1`. Inspect the ZIP and require the
compiler, model, tests, parity files, `.nx` fixtures, this plan, and no generated
binaries.

## Risks And Questions

- The effective name of an unnamed reference entry cannot be inferred safely
  from source spelling because the target may be a scalar property or a
  definition. Deferred effective-scope resolution is mandatory.
- Contributor boundaries must survive until duplicate validation. A repeated
  name within one source array is an error; the same name across precedence
  layers is an override.
- Whole-array references require an owned result. Returning the target's item
  list would create aliasing and consumer-side dependency on compiler lifetime.
- Complete array references must not use the definition-reference projection
  helper to clone the array. Structural entries already carry their own
  projected values and should be cloned as they stand.
- Replacement position belongs to the lower-precedence named slot, but the
  replacement entry retains higher-precedence provenance.
- The deterministic unnamed-entry rule is fully specified: retain all lower
  unnamed entries and append all higher unnamed entries in contributor source
  order. No positional identity is introduced.
- No unresolved design question blocks implementation. If the current model
  reveals an unclassifiable effective-name case beyond those listed, stop with
  that minimal example rather than inventing matching behavior.

## Approval Gate

No implementation begins until the human owner explicitly authorizes this
plan. Creating, committing, and pushing this plan does not authorize compiler,
model, test, fixture, consumer, build, test, archive, or cutover work.
