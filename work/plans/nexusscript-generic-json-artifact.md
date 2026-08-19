# Work Plan: Mechanical JSON Serialization of Compiled NexusScript

## Inputs and Authorization

- Human-owner requirement: NexusScript source is already structurally
  JSON-friendly.
- Human-owner clarification: compilation resolves references, inheritance,
  composition, includes, effective names, and effective values. JSON generation
  only serializes that completed result.
- Current NexusScript compiler, compiled model, compilation session, CLI,
  Mustache rendering, NexusManifest batching, and tests.
- Repository architecture-change protocol and Pascal standards.

This is a work plan only. It authorizes no implementation, build, test, archive,
or unrelated repository change.

## Goal

Implement one generic NexusScript JSON serializer with this boundary:

```text
NexusScript source
    -> generic compilation
       - resolve references
       - flatten composition and inheritance
       - materialize definition-valued entries
       - calculate effective values and names
       - assemble ordered artifact documents
    -> fully effective compiled tree
    -> mechanical JSON serialization
```

The JSON serializer does not interpret the document. It writes the effective
tree that the compiler has already produced.

## Architectural Rule

The serializer must not:

- resolve or traverse source references;
- interpret provenance;
- apply composition or inheritance;
- copy template members;
- infer relationships;
- classify definition kinds;
- derive foreign keys, constraints, attributes, or other domain concepts;
- consult a validator or doctype;
- inspect filenames;
- special-case Schema or any other language;
- expose compiler bookkeeping as artifact data.

If the effective compiled tree still contains a relationship requiring
interpretation, unresolved composition, or an unevaluated value, compilation
is incomplete. Correct the compiler or report a compiler error; do not repair
it in the serializer.

## Verified Compiler Responsibilities

The existing compiler already owns:

- scalar reference resolution and `EffectiveText`;
- text composition;
- structural reference resolution and provenance;
- materialization of inline and referenced definitions in arrays;
- effective local names for array entries;
- composition flattening and precedence;
- inherited reference rebinding;
- array composition and projection;
- module compilation;
- ordered artifact-document assembly for includes.

The JSON work must consume these completed results rather than reimplementing
them.

## JSON Mapping

The mapping is direct and generic.

### Documents

- Serialize `TNexusScriptCompilationSession.ArtifactDocuments` in their
  existing deterministic order.
- The entry document is first, followed by included artifact documents under
  the session's existing rules.
- Definitions from successive artifact documents append to the corresponding
  definition-kind arrays.
- Module-only and doctype-only documents remain absent because the session
  already excludes them from `ArtifactDocuments`.

### Definitions

At any document or definition scope:

- group effective definitions by their declared `Kind`;
- use the exact kind text as the JSON member name—no pluralization,
  singularization, aliasing, or naming table;
- the member value is an ordered JSON array;
- each definition becomes one JSON object;
- each definition object contains one `Name` selected by the precedence below;
- definition properties become direct members of that object;
- child definitions are grouped by kind through the same recursive rule.

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

This is the complete structural convention. `Project` and `Target` have no
built-in meaning; any kinds follow the same rule.

The emitted `Name` is selected in this order:

1. an explicit array-entry local name;
2. an effective scalar property named `Name`;
3. the definition or definition-valued entry's effective name.

When the scalar `Name` property supplies the emitted member, do not emit it a
second time as an ordinary property. This accommodates ordinary documents that
distinguish source identity from an effective output name without exposing two
JSON members with the same name.

### Properties and scalar values

- A property name becomes its JSON member name exactly.
- A completed scalar value becomes its `EffectiveText` JSON string.
- Empty effective text remains an empty JSON string.
- NexusScript has no core semantic primitive type system, so ordinary scalar
  spelling is not guessed into JSON Boolean, number, or null values.
- Text composition and scalar property references are indistinguishable from
  other completed scalar values at serialization time.

### Arrays

- A property whose effective value is an array becomes a JSON array.
- Preserve effective compiled item order.
- An unnamed scalar entry becomes a JSON string.
- A named scalar entry becomes an object containing `Name` and `Value`.
- A definition-valued entry becomes the ordinary definition object described
  above.
- Use the array entry's `EffectiveName` as the definition object's `Name`, so
  local naming overrides are already reflected.
- The definition object's properties and children come from its materialized
  `StructuralDefinition`.
- Mixed arrays remain valid and serialize item by item without imposing a
  narrower type rule.

Example:

```nxscript
Values: [One, Second: Two];
Fields: [CustomerID: @Core.ID, @Core.Name];
```

conceptually becomes:

```json
{
  "Values": [
    "One",
    { "Name": "Second", "Value": "Two" }
  ],
  "Fields": [
    { "Name": "CustomerID" },
    { "Name": "Name" }
  ]
}
```

The actual definition-valued objects also contain all effective properties and
children materialized by compilation.

### Direct definition references

- A property reference that resolves to scalar text serializes as that scalar
  effective text.
- A definition-valued array reference serializes as its materialized effective
  definition.
- A property that resolves only to a definition and has no effective JSON value
  is a compiler/result-model issue. The serializer must not emit a reference
  object, recursively copy the target, or invent a textual fallback.
- Add a focused pre-serialization validation that rejects such incomplete
  values with the compiled source location. If current language semantics say
  the value should materialize, fix materialization in the compiler before
  serialization.

### Name collisions

The source language's unified member namespace prevents a property from
colliding with a child definition's name, but JSON child collections are keyed
by child kind. Therefore explicitly check whether a property name equals a
child-kind collection member at the same effective scope.

If such a source is currently legal, stop and return the minimal example for a
language-contract decision. Do not silently rename either JSON member and do
not add `Properties`/`Children` wrapper objects merely to avoid the question.

The ordinary `Name` property follows the explicit precedence above and is not a
collision.

## Serializer Ownership and API

Add:

```text
NexusTools/Script/src/obNexusScriptJSON.pas
```

Expose one narrow function that accepts the ordered artifact documents and
returns JSON text. Keep traversal helpers private.

Use `fpjson` for JSON ownership and escaping. Build an owned JSON tree and
serialize it only after the entire artifact succeeds.

Do not introduce:

- a consumer interface;
- a serializer registry;
- callbacks or plugins;
- a visitor framework;
- a JSON mode or format switch;
- validator-dependent output.

## CLI Integration

Modify `NexusTools/Script/cli/obNexusScriptCommand.pas` so it:

1. compiles the input once;
2. optionally validates only when `/validate` is requested;
3. serializes `ArtifactDocuments` once;
4. emits that JSON directly without a rendering option;
5. gives that exact JSON string to `/template`;
6. gives that exact same JSON string to every `/manifest` entry.

Preserve all existing stdout/file, Mustache, and NexusManifest behavior after
the JSON string has been produced.

## Remove the Incorrect Path

Delete:

```text
NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas
```

Remove from the NexusScript executable and actual-output test path:

- `TNexusScriptSchemaConsumer`;
- `TMetaDataModuleList`;
- `TMetaDataTransform`;
- `MetaDataToMustacheJSON`;
- all NexusSchema metadata and transformation units.

Delete `TestSchemaConsumer` and the metadata-producing `LoadNexusScript`
helper. Do not retain or rename the consumer.

Remove the current inForce and Storm assertions from the generic serializer
acceptance suite because they exercise the rejected Schema conversion path.
Update `parity/PARITY.md` to state that legacy Schema artifact parity is
deferred and is not evidence for or against the mechanical JSON serializer.
Do not replace those tests with a weaker comparison in this work.

## Tests

### Mechanical serialization

Add focused tests for:

- multiple root definitions grouped by exact kind;
- root and child definition order;
- direct scalar properties;
- empty effective text;
- quoted text and JSON escaping;
- text composition and scalar references appearing only as final text;
- nested child definitions grouped recursively by exact kind;
- unnamed and named scalar array entries;
- inline definition-valued array entries;
- referenced definition-valued array entries;
- effective local-name overrides;
- composed definitions containing their final effective properties, children,
  and arrays exactly once;
- module references fully resolved before serialization;
- included artifact documents appended in session order;
- rejection of incomplete non-materialized values;
- property/child-kind and emitted-`Name` collision behavior.

Use domain-neutral kinds and properties in serializer tests.

### Mustache usability

Use a small unchanged template against the direct JSON:

```mustache
{{#Project}}
{{Name}}
{{#Target}}
{{Name}}: {{Platform}}
{{/Target}}
{{/Project}}
```

Verify raw JSON, `/template`, and every manifest entry observe the same compiled
content.

## Exact Files

### Add

- `NexusTools/Script/src/obNexusScriptJSON.pas`
- domain-neutral JSON fixtures under `NexusTools/Script/tests/fixtures/json/`

### Modify

- `NexusTools/Script/NexusScript.lpi`
- `NexusTools/Script/README.md`
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- affected CLI and manifest Mustache fixtures
- `NexusTools/Script/parity/PARITY.md`
- `work/plans/nexusscript-command-line-interface.md`
- `work/plans/nexusscript-template-manifest-rendering.md`

### Delete

- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`

Do not modify NexusScript language syntax, validators, NexusSchema production
code, or existing Schema sources as part of this work.

## Ordered Implementation Stages

1. Add domain-neutral JSON fixtures and lock the direct mapping above with
   focused tests.
2. Implement `obNexusScriptJSON.pas` for definitions, properties, children,
   scalars, and arrays.
3. Add definition-valued entries, effective local names, completed reference
   values, and artifact-document aggregation.
4. Resolve or return any genuine effective-model incompleteness discovered by
   serialization; do not add serializer interpretation.
5. Replace CLI JSON construction with one generic serializer call.
6. Verify raw, `/template`, and `/manifest` reuse the identical JSON string.
7. Delete the Schema consumer and every Schema metadata dependency from the
   NexusScript output path.
8. Correct README and the superseded CLI/manifest plan sections.
9. Clean-build, run the full NexusScript suite, perform focused searches, and
   create the standard source archive.

Compile after stages 2, 5, and 7.

## Verification

Run clean builds of `NexusScript.lpi` and `NexusScriptTestModule.lpi`, then the
complete registered NexusScript suite.

Focused searches must prove:

- `TNexusScriptSchemaConsumer` no longer exists;
- the CLI and serializer have no `obMetaData*` or NexusSchema dependency;
- the serializer contains no Schema-domain vocabulary or kind/property
  dispatch;
- the serializer never accesses source reference text to resolve values;
- raw, `/template`, and `/manifest` share one serialized JSON string;
- domain-neutral tests cover every JSON mapping rule.

After approved implementation, run `scripts/New-NexusSourceArchive.ps1` and
verify the serializer is present and the consumer is absent.

## Stop Conditions

Stop and return a minimal compiled example if:

- a supposedly compiled value still requires relationship resolution;
- a definition-valued entry is not materialized;
- property and emitted child-kind collection names collide;
- correct serialization would require consulting a validator or domain kind;
- existing compiler behavior contradicts the direct mapping above.

Fix compiler completeness only when the settled language contract determines
the result. Return genuine contract ambiguity to the human owner.

## Non-Goals

- No Schema interpretation or legacy JSON reconstruction.
- No relationship, inheritance, or composition work in the serializer.
- No validator involvement.
- No alternate JSON modes.
- No consumer/plugin/registry architecture.
- No output conveniences such as comma markers or derived domain fields.
- No template redesign beyond focused generic test fixtures.
- No unrelated language, validation, CLI, or NexusManifest change.

## Sub-Agent Plan

No delegation is requested. The effective-model boundary, serializer, CLI, and
removal of the incorrect path form one tightly coupled integration seam, and
the worktree contains overlapping uncommitted NexusScript changes.
