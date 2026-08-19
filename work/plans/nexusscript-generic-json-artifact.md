# Work Plan: Finalized NexusScript Tree and Mechanical JSON Emission

## Inputs and Authorization

- Human-owner requirement: NexusScript source is deliberately JSON-friendly.
- Human-owner requirement: the compiler resolves relationships, references,
  inheritance, composition, effective names, effective values, and artifact
  dependencies before JSON emission.
- Human-owner requirement: the JSON emitter serializes the finalized tree and
  performs no compilation or interpretation.
- Human-owner clarification: source/provenance information is intended to be
  available to Mustache if needed, but adding or perfecting that output is
  deferred from this correction.
- Current NexusScript compiler, model, session, CLI, Mustache rendering,
  NexusManifest batching, and tests.
- Repository architecture-change protocol and Pascal standards.

This is a work plan only. It authorizes no implementation, build, test, archive,
or unrelated repository change.

## Goal

Establish this boundary:

```text
NexusScript source
    -> compiler and compilation session
       - parse declarations
       - resolve references
       - flatten composition and inheritance
       - materialize structural values
       - calculate effective scalar values and names
       - assemble included artifact documents
       - produce one uniform finalized tree
    -> mechanical JSON emitter
    -> raw JSON, Mustache, or NexusManifest outputs
```

The emitter receives no unresolved or alternate compiler representation. It
does not decide what compilation meant.

## Architectural Boundary

### Compiler responsibility

The compiler owns every operation that converts source relationships into final
structure:

- property-reference resolution;
- structural-reference resolution;
- whole-array reference resolution;
- definition materialization;
- composition flattening and precedence;
- inherited-reference rebinding;
- array composition and projection;
- effective array-entry names;
- effective scalar text;
- module resolution;
- ordered include/artifact assembly;
- rejection of incomplete or invalid results.

The compiler must expose one uniform final tree after those operations finish.
No caller should need to inspect `EffectiveValue`, `StructuralDefinition`,
`ResolvedDefinition`, `ResolvedProperty`, composition contributors, source
reference kinds, or evaluation flags to discover the final value.

### Emitter responsibility

The JSON emitter knows only the finalized tree's public structure:

- documents;
- definitions;
- definition kinds and effective names;
- properties;
- scalar values;
- arrays;
- structural values and child definitions.

It recursively writes those nodes to JSON. It performs no validation beyond
ordinary JSON construction failures such as duplicate member names that the
final-tree contract should already prevent.

The emitter must not:

- inspect compiler reference or provenance fields;
- follow an alternate/effective-value pointer;
- resolve, materialize, compose, merge, or copy definitions;
- interpret definition kinds or property names;
- consult a validator or doctype;
- infer domain relationships;
- manufacture Schema, Build, Mustache, or other consumer data;
- expose Pascal class names or compiler bookkeeping.

## Finalized Effective Tree

### Purpose

The current compiled model retains source form, provenance, resolved targets,
and alternate effective values because the compiler and validator need them.
That is not a clean emitter API.

Add a finalized tree produced by the compiler/session after successful
compilation. It is a projection of the already-completed result, but the
projection is owned by compilation—not by JSON emission.

### Minimal model

Add pure structural types, conceptually:

```text
TNexusScriptEffectiveDocument
  Definitions[]

TNexusScriptEffectiveDefinition
  Kind
  Name
  Properties[]
  Children[]

TNexusScriptEffectiveProperty
  Name
  Value

TNexusScriptEffectiveValue
  Category = Scalar | Array | Definition
  ScalarText
  Items[]
  Definition
```

Use project naming and ownership conventions in the actual Pascal declarations.
Place the real definitions in a generic Script model unit, not in the CLI or
JSON unit.

The tree contains no reference category. A resolved property reference is a
scalar, array, or structural value. A definition reference that is legal in
the final language result is already a structural value. Composition is already
reflected in the definition members.

### Construction

Add one compiler-owned finalization pass after normal compilation succeeds.
This pass may inspect all compiler internals because resolving their meaning is
its responsibility.

For every compiled value, finalization selects the already-computed result:

- completed scalar -> scalar node;
- completed array, including a whole-array reference -> array node;
- materialized inline or referenced definition -> structural node;
- composed definition -> ordinary definition containing its effective members.

If the compiler cannot produce exactly one of those final categories, final
compilation fails. The JSON emitter never receives the incomplete result and
never diagnoses reference/materialization state.

### Ownership

- The compilation session owns finalized artifact documents.
- Finalized documents own definitions.
- Definitions own their properties and children.
- Properties and arrays own their effective values/items.
- Structural values own finalized copies appropriate to their effective
  location; the final tree contains no shared ownership or back-reference that
  could recurse during emission.
- The emitter borrows the completed tree for the duration of serialization.

### Source and provenance information

The intended long-term design permits source/provenance information to remain
in the finalized tree and therefore be available in emitted JSON for unusual
Mustache needs.

This work does not design, remove, relocate, or serialize that information.
Build the finalized model so optional source/provenance members can be added
later without changing the structural node categories or making the emitter
interpret compiler state. Do not add a sidecar architecture.

For this correction, only the effective declarative content is required in the
finalized tree and JSON.

## Mechanical JSON Contract

### Documents and includes

- Serialize the session's finalized artifact documents in existing
  `ArtifactDocuments` order.
- The entry document is first; included documents follow under existing session
  rules.
- Append definitions from later artifact documents to the corresponding
  exact-kind arrays.
- Module-only and doctype-only documents remain absent because the session
  already excludes them from the artifact set.

### Definitions

At document scope and within every definition:

- group definitions by exact `Kind`;
- use the exact kind text as the JSON member name;
- make the member value an ordered JSON array;
- make each definition a JSON object;
- emit `Name` using the finalized definition's effective output name;
- emit properties as direct members;
- emit child definitions recursively through the same exact-kind array rule.

No pluralization, aliases, envelopes, grouping tables, or domain-name mapping
are permitted.

Example:

```nxscript
Project Example {
    Output: build/example.exe;

    Target Compile {
        Platform: win64;
    }
}
```

becomes:

```json
{
  "Project": [
    {
      "Name": "Example",
      "Output": "build/example.exe",
      "Target": [
        {
          "Name": "Compile",
          "Platform": "win64"
        }
      ]
    }
  ]
}
```

### Effective names

Finalization—not the emitter—selects the definition object's output name:

1. explicit array-entry local name;
2. effective scalar `Name` property when one is intentionally declared;
3. effective definition name.

When an effective `Name` property supplies the output name, it is consumed into
the finalized definition name and does not remain as a duplicate property.

This rule preserves both ordinary definition identity and the existing ability
to give a structurally placed definition an effective local/output name.

### Properties and scalars

- Emit each property under its exact name.
- Emit a scalar node as its finalized text.
- Preserve empty text as an empty JSON string.
- Do not infer JSON Boolean, number, or null values from spelling. NexusScript
  core scalars are text.
- A scalar reference or text composition has already become an ordinary scalar
  node and receives no special treatment.

### Arrays

- Emit an array node as an ordered JSON array.
- Emit an unnamed scalar entry as a JSON string.
- Emit a named scalar entry as `{ "Name": name, "Value": text }`.
- Emit a definition-valued entry as the ordinary definition object described
  above.
- The entry's effective local name is already the finalized definition name.
- Emit mixed arrays item by item without validator involvement.

### Structural properties

When a property has a finalized structural value, emit the definition object
directly as that property's JSON value. Do not wrap it in reference metadata and
do not group it again by kind because the property name already supplies the
JSON member name.

Example finalized structure:

```nxscript
Alias: @Root.Base;
```

where compilation materializes `Base`, emits conceptually as:

```json
"Alias": {
  "Name": "Alias",
  "Text": "original",
  "Inner": [
    {
      "Name": "Inner",
      "Value": "nested"
    }
  ]
}
```

The emitter sees only a structural property named `Alias`; it does not know
that the source used a reference.

### Member collisions

The finalized tree must reject before emission:

- two properties with the same effective name;
- a property whose name collides with an emitted child-kind collection name;
- a remaining property named `Name` after effective-name finalization;
- any other two members that would occupy the same JSON object key.

Return a compiler/finalization diagnostic with source location. Do not add
`Properties` or `Children` wrappers to avoid collisions and do not rename JSON
members.

## JSON Emitter

Add:

```text
NexusTools/Script/src/obNexusScriptJSON.pas
```

Expose one narrow function accepting finalized artifact documents and returning
JSON text. Keep recursive writing helpers private.

Use `fpjson` for object ownership, arrays, strings, escaping, and formatting.
Construct the complete owned JSON tree before returning text.

The JSON unit must depend only on the finalized generic model and ordinary
runtime/JSON units. It must not depend on the compiler implementation,
validator, CLI, NexusSchema, metadata, Mustache, or source model.

## CLI Integration

Modify `NexusTools/Script/cli/obNexusScriptCommand.pas` so it:

1. compiles the input once;
2. optionally validates when `/validate` is requested;
3. obtains the session's finalized artifact tree;
4. serializes it once;
5. emits that JSON directly without a rendering option;
6. gives that exact JSON string to `/template`;
7. gives that exact same JSON string to every `/manifest` entry.

Preserve current stdout/file, Mustache, and NexusManifest behavior after JSON
creation.

## Remove the Incorrect Path

Delete:

```text
NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas
```

Remove from the NexusScript executable and actual-output tests:

- `TNexusScriptSchemaConsumer`;
- `TMetaDataModuleList`;
- `TMetaDataTransform`;
- `MetaDataToMustacheJSON`;
- all NexusSchema interpretation.

Delete `TestSchemaConsumer` and the metadata-producing `LoadNexusScript`
helper. Remove the current inForce and Storm assertions from the generic
serializer suite because they test the rejected conversion path. Mark their
legacy artifact-parity status as deferred in `parity/PARITY.md`; do not replace
them with a weaker comparison.

## Tests

### Compiler finalization tests

Prove that the finalized tree contains no alternate compiler state:

- direct scalar;
- text composition;
- scalar property reference;
- whole-array reference;
- inline definition-valued array entry;
- referenced definition-valued array entry;
- direct structural property reference;
- local array-entry name override;
- flattened composition and inherited-reference rebinding;
- array composition/projection;
- module-resolved values;
- entry and included artifact-document order;
- rejection of any value lacking one final category;
- member-collision diagnostics.

Assertions inspect only finalized public nodes, not JSON.

### Mechanical emitter tests

Supply constructed finalized trees directly and verify:

- exact kind names become ordered arrays;
- definitions contain `Name` and direct properties;
- child kinds recurse;
- scalar strings and empty strings;
- unnamed and named scalar arrays;
- structural property objects;
- definition-valued array objects;
- mixed arrays;
- multiple artifact documents append by exact kind;
- quotes, backslashes, control characters, and Unicode escape correctly.

These tests must not instantiate the compiler, validator, or source model. They
prove the emitter is mechanical.

### End-to-end generic tests

- Compile a domain-neutral NexusScript fixture.
- Compare its finalized tree to the expected structure.
- Serialize it and use a small Mustache template directly:

```mustache
{{#Project}}
{{Name}}
{{#Target}}
{{Name}}: {{Platform}}
{{/Target}}
{{/Project}}
```

- Verify raw output, `/template`, and every `/manifest` entry use the identical
  serialized JSON string.
- Preserve existing CLI validation and NexusManifest order, path, overwrite,
  traversal, and stop-on-error tests.

Schema behavior is outside this work.

## Exact Files

### Add

- generic finalized-tree model unit under `NexusTools/Script/src/`, using the
  repository's final agreed unit name
- `NexusTools/Script/src/obNexusScriptJSON.pas`
- domain-neutral finalization/JSON fixtures under
  `NexusTools/Script/tests/fixtures/json/`

### Modify

- `NexusTools/Script/NexusScript.lpi`
- `NexusTools/Script/README.md`
- `NexusTools/Script/src/obNexusScriptCompiler.pas`
- `NexusTools/Script/src/obNexusScriptSession.pas`
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- affected domain-neutral CLI and manifest fixtures
- `NexusTools/Script/parity/PARITY.md`
- `work/plans/nexusscript-command-line-interface.md`
- `work/plans/nexusscript-template-manifest-rendering.md`

### Delete

- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`

Do not modify NexusScript syntax, validators, NexusSchema production code,
legacy Schema sources, or Mustache templates.

## Ordered Implementation Stages

1. Add the minimal finalized effective-tree model and explicit ownership.
2. Add compiler finalization for scalar, array, and structural results.
3. Cover references, effective-value indirection, composition, materialization,
   modules, includes, names, and collisions entirely inside finalization.
4. Add finalization tests proving callers need no compiler-internal inspection.
5. Add the mechanical JSON emitter and isolated constructed-tree tests.
6. Add one domain-neutral end-to-end compilation and Mustache fixture.
7. Replace CLI artifact creation with final-tree serialization once per
   invocation and reuse it for raw, `/template`, and `/manifest` output.
8. Delete the Schema consumer and all NexusScript-side metadata dependencies.
9. Remove/defer the invalid Schema parity assertions and correct documentation
   and superseded plans.
10. Clean-build, run the full suite, perform focused searches, and create the
    standard full-source archive.

Compile after stages 3, 5, 7, and 8.

## Verification

Run clean builds of `NexusScript.lpi` and `NexusScriptTestModule.lpi`, followed
by the complete registered NexusScript suite.

Focused searches must prove:

- `TNexusScriptSchemaConsumer` no longer exists;
- the CLI and JSON unit have no `obMetaData*` or NexusSchema dependency;
- the JSON unit does not reference compiler source/compiled-model internals,
  references, effective-value indirection, provenance, composition, modules,
  validators, or doctypes;
- finalization, not JSON emission, is the only code that converts compiled
  alternate forms into final categories;
- raw, `/template`, and `/manifest` reuse one JSON string;
- emitter tests operate on constructed finalized trees without a compiler.

After approved implementation, run `scripts/New-NexusSourceArchive.ps1` and
verify the finalized model and JSON emitter are present and the consumer is
absent.

## Stop Conditions

Stop and return a minimal example if:

- the compiler cannot reduce a valid compiled value to one final category;
- final structural ownership would require a recursive/shared graph;
- property and child-kind JSON member names collide under legal source;
- effective `Name` precedence conflicts with settled array-local naming;
- correct finalization would require validator or domain knowledge;
- source/provenance retention becomes necessary to complete this work rather
  than remaining a deferred emitted capability.

Do not move any such decision into the emitter.

## Non-Goals

- No Schema interpretation or legacy JSON reconstruction.
- No compiler logic in the emitter.
- No validator involvement in finalization or emission.
- No source/provenance JSON design in this pass.
- No consumer/plugin/registry architecture.
- No alternate output modes.
- No output conveniences or derived domain fields.
- No unrelated language, validation, CLI, or NexusManifest changes.

## Sub-Agent Plan

No delegation is requested. Final-tree ownership, compiler finalization, JSON
emission, and CLI replacement form one tightly coupled integration seam, and
the worktree contains overlapping uncommitted NexusScript changes.
