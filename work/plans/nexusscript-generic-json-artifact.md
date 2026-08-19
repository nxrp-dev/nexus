# Work Plan: NexusScript Generic JSON Replacement Parity

## Inputs and Authorization

- Human-owner requirement: NexusScript must compile generically to JSON, and
  that unmodified JSON must have exact replacement parity with NexusSchema.
- Human-owner correction: a Schema-specific conversion on the NexusScript side
  defeats the parity test.
- Current NexusScript compiler, session, CLI, renderer, validators, fixtures,
  and tests.
- Current NexusSchema parser, metadata transformation, JSON serialization,
  Mustache templates, and controlled legacy fixtures.
- Repository architecture-change protocol and Pascal standards.

This is a work plan only. It authorizes no implementation, build, test, archive,
or unrelated repository change.

## Fixed Acceptance Criterion

Parity means exactly:

```text
legacy NexusSchema input
    -> unchanged NexusSchema parser
    -> unchanged metadata transformations
    -> unchanged MetaDataToMustacheJSON
    -> expected JSON

equivalent NexusScript input
    -> generic NexusScript compiler
    -> generic NexusScript JSON serializer
    -> actual JSON

expected JSON = actual JSON byte for byte
```

Both JSON strings must then produce byte-identical output through the same
unchanged Mustache template.

The comparison permits no Schema consumer, baseline projection, adapter,
normalization, sorting, alternate expected JSON, rewritten parity template, or
special behavior selected by doctype, filename, or definition kind.

The existing NexusSchema JSON and rendered artifact are fixed replacement
targets. If generic NexusScript output differs, correct the generic serializer
or the NexusScript source representation until the direct outputs match.

## Verified Current Defect

`NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas` interprets compiled
definitions through hard-coded `Schema`, `Type`, `Template`, `Table`, `Field`,
`Attributes`, and `Data` meanings. It reconstructs `TMetaDataModuleList`, after
which the CLI runs `TMetaDataTransform` and `MetaDataToMustacheJSON`.

The current tests therefore prove that a second Schema parser can recreate the
legacy metadata model. They do not prove that generic NexusScript compilation
produces the replacement JSON. The problem is also in the executable:
`TNexusScriptCommand.Execute` unconditionally uses this class for raw JSON,
`/template`, and `/manifest`, so non-Schema documents cannot produce artifacts.

## Correct Architecture

```text
artifact source documents
    -> TNexusScriptCompilationSession
    -> effective TNexusScriptCompiledDocument objects
    -> generic structural JSON serializer
    -> one JSON artifact
    -> stdout/file, existing Mustache, or existing manifest batching
```

The serializer reflects generic compiled structure only. Schema-specific
artifact organization must exist declaratively in the NexusScript documents;
the serializer must not infer or manufacture it.

## Generic JSON Serializer

Add:

```text
NexusTools/Script/src/obNexusScriptJSON.pas
```

It may depend on `fpjson` and the generic NexusScript model. It must not depend
on NexusSchema metadata, validator vocabulary, doctypes, filenames, parity
fixtures, or Mustache.

### Structural rules

1. A root definition's effective name becomes a JSON member name; its contents
   become that member's JSON object.
2. A direct child definition's effective name becomes a member name of its
   containing object; its contents become that member's JSON object.
3. Definition kind remains language/validation information. It creates no JSON
   wrapper and is not emitted unless declared as ordinary data.
4. A property name becomes a JSON member name.
5. A scalar or text-composition property becomes its compiled `EffectiveText`
   JSON string. Do not infer Boolean, numeric, or null types from spelling.
6. An array property becomes a JSON array in effective compiled order.
7. An unnamed scalar array entry becomes a JSON string.
8. A named scalar array entry becomes `{ "Name": effective-name,
   "Value": effective-text }`.
9. An inline or referenced definition-valued array entry becomes a JSON object.
   Its first member is `Name` containing its effective local name, followed by
   its compiled properties and children under these same rules.
10. A local entry-name override changes only the emitted `Name`; the compiled
    materialized contents remain unchanged.
11. Compiled definition, property, child, and array order controls JSON order.
12. JSON escaping is owned solely by the JSON library.

Names such as `NexusSchema`, `MetaData`, `Modules`, `Tables`, `Fields`,
`Attributes`, `Name`, `Value`, and `Comma` have no serializer meaning. They
appear only when the compiled document declares them.

### Multiple artifact documents

Includes currently contribute separately compiled documents to
`ArtifactDocuments` in deterministic entry-first order. Exact Storm parity
requires those documents to contribute to one artifact. Aggregate them
generically by structural name:

- the first occurrence establishes member order;
- equally named root or child objects merge recursively;
- equally named arrays append in artifact-document and item order;
- object/array/scalar category conflicts are errors;
- duplicate scalars are errors unless their effective text is identical, in
  which case the first value and position remain;
- new member names append in encounter order.

This is generic include-artifact behavior, not Schema behavior. Module-only and
doctype-only documents remain excluded under existing session rules. Do not
introduce a second document model merely to merge output.

## Declarative Schema Artifact Shape

The current `.Schema.nxscript` fixtures are shaped for the unwanted consumer.
For example, `Schema inForce` relies on procedural code to manufacture
`NexusSchema.MetaData.Modules`, move settings into attributes, flatten types,
group tables, and synthesize field data. That source cannot serialize directly
to the legacy JSON because the required structure is absent.

Rewrite the controlled NexusScript Schema fixtures and `Schema.Language` so the
compiled generic structure directly contains the fixed artifact shape:

```text
NexusSchema
  MetaData
    Attributes
    Data[]
    AttributeSets[]
    Modules[]
      Name
      Types[]
      Templates[]
      Tables[]
      AttributeSets[]
      Attributes
```

Entries must directly declare every member expected by the unchanged JSON and
Mustache contract, including names, values, fields, indexes, foreign keys,
references, attributes, table names, field types, constraint names, and comma
markers. Use existing references, composition, arrays, inline definitions, and
text composition to avoid repetition.

The generic serializer must not synthesize anything formerly supplied by
`TMetaDataTransform` or `MetaDataToMustacheJSON`. If a required value cannot be
expressed using settled NexusScript semantics, stop and return that exact
language limitation for owner review rather than hiding it in serialization.

`Schema.Language.nxscript` may contain Schema vocabulary because it is the
domain-specific language definition. The compiler and serializer may not.

## CLI Correction

Modify `NexusTools/Script/cli/obNexusScriptCommand.pas` to:

1. compile normally;
2. optionally validate through the declared doctype;
3. serialize `ArtifactDocuments` once through the generic serializer;
4. emit that JSON directly without a rendering option;
5. pass that exact string to the existing `/template` operation;
6. pass that exact same string to every `/manifest` entry.

Remove dependencies on `obNexusScriptSchemaConsumer`,
`obMetaDataModuleList`, `obMetaDataTransformations`, and `obMetaDataJSON`.
Add no `/consumer`, `/format`, `/json`, doctype dispatch, registry, callback, or
output abstraction.

## Remove the Incorrect Consumer

Delete `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`. Remove it
from both Lazarus projects, all `uses` clauses, helpers, and tests. Delete
`TestSchemaConsumer` and `LoadNexusScript`. Do not rename, relocate, retain, or
replace the class with another compiled-document-to-Schema mapping.

## Parity Test Reconstruction

The expected side remains unchanged:

```text
controlled .nxs fixture
    -> TNexusSchemaParser
    -> TMetaDataTransform
    -> MetaDataToMustacheJSON
```

The actual side becomes only:

```text
equivalent .Schema.nxscript fixture
    -> TNexusScriptCompilationSession
    -> generic NexusScript JSON serializer
```

For both inForce and Storm:

1. compare expected and actual JSON strings exactly;
2. report the first differing byte for diagnosis only;
3. render both through the same unchanged
   `DatabaseSchema.create.mustache`;
4. compare rendered output exactly;
5. for Storm, prove included documents aggregate in established order.

Do not parse and compare trees, normalize whitespace, omit fields, rewrite
expected data, or insert any mapping on either side. The test passes only when
generic output is already the replacement artifact.

## Focused Tests

Add domain-neutral serializer tests for:

- arbitrary root and child names producing nested objects;
- scalar properties using `EffectiveText`;
- empty objects and arrays remaining present;
- named and unnamed scalar array entries;
- inline and referenced definition entries serializing identically after
  compilation except for explicit local naming;
- deterministic ordering and JSON escaping;
- artifact-document object merging and ordered array appending;
- scalar duplicates and structural category conflicts failing clearly;
- a valid non-Schema document producing JSON through the CLI.

Update existing CLI and manifest tests only where they assumed Schema metadata.
Preserve stdout/file behavior, validation, single-template rendering, manifest
batching, compiled `Source`/`Output`, ordering, overwriting, traversal rejection,
and stop-on-error behavior. Prove the exact JSON emitted without a template is
the exact JSON given to `/template` and every manifest entry.

## Documentation Corrections

Update:

- `NexusTools/Script/README.md` to describe direct generic effective JSON;
- `NexusTools/Script/parity/PARITY.md` to describe the two unmodified paths;
- `work/plans/nexusscript-command-line-interface.md` to mark the
  Schema-metadata conversion boundary as superseded;
- `work/plans/nexusscript-template-manifest-rendering.md` to use the one
  generic serializer call while leaving manifest behavior unchanged.

Do not revise unrelated historical plans.

## Exact Files

### Add

- `NexusTools/Script/src/obNexusScriptJSON.pas`
- domain-neutral fixtures under `NexusTools/Script/tests/fixtures/json/`

### Modify

- `NexusTools/Script/NexusScript.lpi`
- `NexusTools/Script/README.md`
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- affected CLI and manifest fixtures
- the standard `Schema.Language.nxscript`
- `NexusTools/Script/parity/fixtures/nexusscript/inForceMain.Schema.nxscript`
- `NexusTools/Script/parity/fixtures/nexusscript/StormSpecific.Schema.nxscript`
- `NexusTools/Script/parity/PARITY.md`
- `work/plans/nexusscript-command-line-interface.md`
- `work/plans/nexusscript-template-manifest-rendering.md`

### Delete

- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`

Do not modify NexusSchema production code or its Mustache template.

## Ordered Implementation

1. Capture the exact unchanged legacy fixture JSON as the development target;
   do not create a different expected format.
2. Implement the generic serializer and domain-neutral tests, including
   artifact-document aggregation.
3. Rewrite the controlled Schema language and NexusScript fixtures so their
   compiled structure directly represents every fixed JSON member.
4. Replace parity tests and make direct inForce JSON parity pass.
5. Complete included-document aggregation and make direct Storm JSON parity
   pass.
6. Prove both datasets render identically through the same unchanged template.
7. Replace the CLI path with one generic serialization call reused by raw,
   `/template`, and `/manifest` output.
8. Delete the Schema consumer and all NexusScript-side metadata dependencies.
9. Update generic fixtures and documentation.
10. Run clean builds, the full suite, focused searches, and the standard source
    archive checkpoint.

Compile after stages 2, 5, 7, and 8 so failures stay localized.

## Verification

Run:

```text
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-all
```

The suite must prove exact inForce JSON parity, exact Storm JSON parity, exact
unchanged-template output parity for both, generic non-Schema JSON output, and
all existing compiler, validator, CLI, template, and manifest regressions.

Focused searches must prove:

- `TNexusScriptSchemaConsumer` no longer exists;
- the CLI and serializer have no `obMetaData*` or NexusSchema dependency;
- the serializer contains no conditions for `Schema`, `Table`, `Template`,
  `Field`, SQL, or Mustache;
- only the expected legacy parity path uses `TNexusSchemaParser`,
  `TMetaDataTransform`, and `MetaDataToMustacheJSON`;
- raw and both rendering modes reuse one generic JSON string.

After approved implementation, create and inspect the standard archive with
`scripts\New-NexusSourceArchive.ps1`.

## Stop Conditions

Stop and return to the human owner if exact parity requires:

- a value that settled NexusScript cannot represent;
- serializer recognition of a Schema-domain name;
- information absent from the declaratively compiled structure;
- include aggregation outside the generic rules above;
- normalization, an adapter, or a special-case transformation.

Do not hide those conditions with compatibility code.

## Non-Goals

- No alternate canonical JSON.
- No baseline projection or rewritten parity template.
- No Schema consumer under another name.
- No consumer/plugin/registry architecture.
- No language-semantic change without a separate concrete owner decision.
- No format switch, binary target, NexusSchema cutover, or filename/doctype
  inference.

## Sub-Agent Plan

No delegation is requested. The serializer, declarative fixture structure,
exact parity comparison, and CLI replacement share one tightly coupled seam,
and the worktree contains overlapping uncommitted NexusScript changes.
