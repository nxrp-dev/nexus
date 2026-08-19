# Work Plan: NexusScript Generic JSON Artifact

## Inputs and Authorization

- Human-owner correction in conversation: NexusScript must compile generically
  to JSON, and parity must test that generic result. A Schema-specific
  conversion on the NexusScript side defeats the purpose of the parity test.
- Current NexusScript compiler, compiled model, compilation session, CLI,
  manifest renderer, validator, and registered tests.
- Current legacy NexusSchema parser, metadata transformation, JSON writer, and
  controlled parity fixtures, used only as the comparison baseline.
- Repository architecture-change protocol and Object Pascal standards.

This is a planning artifact only. It authorizes no implementation, build, test
run, archive, or unrelated repository change.

## Goal

Make the NexusScript artifact path genuinely domain-neutral:

```text
NexusScript source
    -> generic compiler
    -> generic compiled document set
    -> generic JSON serializer
    -> JSON artifact
    -> optional existing Mustache rendering
```

Remove this incorrect path:

```text
generic compiled document
    -> TNexusScriptSchemaConsumer
    -> NexusSchema metadata objects
    -> NexusSchema transformations
    -> NexusSchema JSON
```

The NexusScript compiler, serializer, CLI, and renderer must contain no
knowledge of `Schema`, `Table`, `Template`, `Field`, SQL, or NexusSchema
metadata classes. The same serializer must accept every successfully compiled
NexusScript document, regardless of doctype.

## Verified Current Problem

`NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas` interprets generic
definitions as the NexusSchema vocabulary and creates:

- `TMetaDataModuleList`;
- schema settings and data entries;
- types, templates, tables, fields, attributes, and references;
- the input consumed by `TMetaDataTransform` and
  `MetaDataToMustacheJSON`.

Despite living under `parity`, that class is included in `NexusScript.lpi` and
is instantiated unconditionally by `TNexusScriptCommand.Execute`. Therefore
normal JSON output, `/template`, and `/manifest` all depend on a Schema-specific
interpretation. A valid non-Schema NexusScript document is rejected when the
consumer cannot find a `Schema` root.

The registered tests reproduce the same mistake:

- `LoadNexusScript` converts the NexusScript side through the Schema consumer;
- `TestSchemaConsumer` directly blesses the unwanted adapter;
- `TestCommandJSONArtifact` derives its expected result through that adapter;
- `InForceArtifactParity` and `StormArtifactParity` compare two
  Schema-specific metadata constructions rather than testing generic
  NexusScript JSON;
- manifest and Mustache tests consequently exercise schema JSON, not generic
  compiled output.

The README and the existing CLI and manifest plans document this temporary
artifact path as though it were the intended NexusScript contract. Those
statements must be corrected with the code.

## Required Architecture

### Generic serializer ownership

Add one serializer unit under the generic Script source tree:

```text
NexusTools/Script/src/obNexusScriptJSON.pas
```

It owns conversion from compiled NexusScript objects to JSON text. It may use
`fpjson`, but it must depend only on the generic NexusScript model and ordinary
runtime units. It must not use anything under `NexusTools/Schema`, the parity
folder, validator vocabulary, a doctype name, or filename components.

Expose a small API operating on compiled results, conceptually:

```pascal
function NexusScriptDocumentsToJSON(
  ADocuments: TNexusScriptArtifactDocumentList): string;
```

If avoiding a session-owned list type keeps the serializer independent from
the session, expose a document writer plus one small aggregate entry point in
the session or CLI. Do not create a serializer framework, visitor hierarchy,
registry, artifact consumer, or output-format abstraction.

### Serialization boundary

Serialize the effective compiled document, not source syntax and not object
internals used only during compilation.

Include only stable language-level information needed to represent the
compiled result:

- definition kind and effective name;
- compiled properties in their compiled order;
- compiled child definitions in their compiled order;
- scalar effective text;
- arrays in effective item order;
- optional effective array-entry names;
- materialized structural definitions where a value resolves to a definition.

Do not expose:

- object addresses or graph identity;
- source ranges or absolute source filenames;
- `ResolvedProperty`, compiler recursion flags, evaluation flags, composition
  scratch state, or owning Pascal class names;
- doctype compiler objects;
- schema-derived values synthesized outside normal NexusScript compilation.

### Proposed canonical JSON shape

Use an explicit, uniform representation rather than deriving member names from
definition kinds or applying English pluralization. The proposed contract is:

```json
{
  "Documents": [
    {
      "Definitions": [
        {
          "Kind": "Example",
          "Name": "Root",
          "Properties": [
            {
              "Name": "Title",
              "Value": "Hello"
            },
            {
              "Name": "Values",
              "Value": [
                "One",
                { "Name": "Second", "Value": "Two" }
              ]
            }
          ],
          "Children": []
        }
      ]
    }
  ]
}
```

Rules:

1. `Documents`, `Definitions`, `Properties`, and `Children` are always arrays,
   preserving compiled order.
2. A definition is an object containing `Kind`, `Name`, `Properties`, and
   `Children`.
3. A property is an object containing `Name` and `Value`.
4. A scalar or resolved text-composition value is emitted as its
   `EffectiveText` JSON string. NexusScript currently has textual scalar
   semantics, so the serializer must not guess JSON numbers, booleans, or null
   from spelling.
5. An array is emitted as a JSON array in effective order.
6. An unnamed scalar array entry is emitted directly as a JSON string.
7. A named scalar array entry is emitted as an object with `Name` and `Value`.
8. A definition-valued array entry is emitted as the same definition object
   shape. Its `Name` is the entry's `EffectiveName`, so a local name override is
   represented without losing the compiled structure it names.
9. An unresolved or non-materializable value is a serialization error. It must
   not become an empty string, empty object, or Schema-specific fallback.
10. Included artifact documents are emitted in the session's existing
    `ArtifactDocuments` order. Module- and doctype-only documents remain absent
    under the session rules already established for artifact membership.

Before implementation, this JSON shape is the one contract-level item the
human owner must approve or amend. The architecture does not depend on these
particular envelope/member spellings, but the spellings and scalar/named-entry
representation become observable CLI and Mustache behavior once shipped.

## CLI Correction

Modify `NexusTools/Script/cli/obNexusScriptCommand.pas` so that after optional
doctype validation it:

1. serializes `lSession.ArtifactDocuments` through the generic serializer
   exactly once;
2. uses that JSON as the default artifact;
3. passes that exact same JSON to the existing single-template renderer when
   `/template` is supplied;
4. passes that exact same JSON to every manifest entry when `/manifest` is
   supplied;
5. retains the current stdout/file behavior, template-manifest sequencing,
   relative-path handling, and diagnostics.

Remove all CLI dependencies on:

- `obNexusScriptSchemaConsumer`;
- `obMetaDataModuleList`;
- `obMetaDataTransformations`;
- `obMetaDataJSON`.

Do not add a `/consumer`, `/format`, `/json`, schema selector, doctype dispatch,
registry, callback, or public extension API. JSON remains the normal result of
generic compilation; Mustache remains an optional subsequent operation.

## Removal of the Invalid Schema Path

Delete:

```text
NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas
```

Remove it from:

- `NexusTools/Script/NexusScript.lpi`;
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`;
- all test and CLI `uses` clauses;
- helper methods and tests that instantiate it.

Do not retain, rename, relocate, or abstract the class. No current production
integration requires it, and keeping it would preserve the incorrect
architectural escape hatch.

## Honest Parity Testing

### Principle

The NexusScript side of every parity comparison must be exactly:

```text
NexusScript fixture
    -> normal compilation session
    -> generic JSON serializer
```

No Schema-specific traversal, metadata conversion, transformation, or fix-up
may occur on that side.

### Legacy baseline

The unchanged legacy NexusSchema parser may remain on the expected/baseline
side because it defines the behavior being replaced. If comparison with the
new canonical JSON requires a Schema-specific baseline projection, implement
that projection only as a test helper over the legacy result. Its direction is:

```text
legacy NexusSchema result -> expected generic JSON
```

It must never accept a NexusScript compiled document and must never be linked
into the NexusScript executable. This placement prevents the baseline helper
from compensating for errors in generic NexusScript compilation or
serialization.

Prefer checked-in expected JSON fixtures when that is clearer than maintaining
a second procedural mapper. Expected fixtures must be generated once from the
accepted baseline and then reviewed; the tests must not rewrite them.

### What parity can assert

Split the current overloaded parity claim into explicit assertions:

- the generic JSON for the migrated inForce NexusScript input matches its
  reviewed expected generic JSON exactly;
- the generic JSON for Storm plus its included artifact documents matches its
  reviewed expected generic JSON exactly and in document order;
- the CLI emits byte-for-byte the same JSON as the generic serializer;
- the existing Mustache renderer receives that identical generic JSON.

The old Schema Mustache template consumes the old metadata JSON contract and
cannot be claimed to work unchanged against a new generic JSON contract. If
final generated SQL parity remains required, handle that transparently by
adapting a test copy of the template to the approved generic representation
and compare rendered output to the unchanged legacy rendering. Any values
previously synthesized by `TMetaDataTransform` must either be represented by
normal NexusScript compilation or calculated in explicitly approved template
work; they must not be silently recreated in the generic serializer.

This plan does not claim that two structurally different JSON contracts are
byte-identical. Approval must distinguish generic compiled-JSON parity from
continued compatibility with the old NexusSchema Mustache-data shape.

## Tests

### Generic serializer tests

Add focused tests covering:

- an arbitrary non-Schema root definition serializes successfully;
- root definitions, properties, children, documents, and array entries retain
  compiled order;
- scalar and text-composition values use `EffectiveText`;
- named and unnamed scalar array entries use the approved shapes;
- inline and referenced definition-valued array entries serialize their
  materialized compiled definitions and effective local names;
- local naming overrides appear as the serialized definition name;
- JSON escaping handles quotes, backslashes, control characters, and Unicode;
- unsupported unresolved values fail with a diagnostic tied to the generic
  value, not with a Schema-vocabulary message;
- doctype and module compiler documents do not leak into the artifact document
  list, while includes retain deterministic session order.

### CLI tests

Replace `TestCommandJSONArtifact` expectations derived through Schema metadata
with direct generic-serializer expectations. Verify:

- default stdout JSON equals serializer output exactly;
- `/output` contains the same bytes and leaves stdout empty;
- a valid non-Schema document produces JSON instead of an “unable to produce”
  error;
- compilation and optional validation failures still prevent output;
- `/template` receives exactly the generic JSON emitted without a template;
- `/manifest` compiles the input once and gives the same generic JSON to every
  entry;
- existing manifest order, path, overwrite, and failure behavior remains
  unchanged.

Update Mustache fixtures to read the approved generic JSON shape. The fixtures
must demonstrate generic navigation and must not use `NexusSchema`, `Schema`,
or other domain names unless the input fixture itself declares those names.

### Parity tests

Remove:

- `LoadNexusScript` as a metadata-producing helper;
- `TestSchemaConsumer`;
- all NexusScript-side `TMetaDataModuleList`, `TMetaDataTransform`, and
  `MetaDataToMustacheJSON` calls.

Rewrite `InForceArtifactParity` and `StormArtifactParity` so their actual value
comes directly from the generic serializer. Keep the legacy parser only on the
baseline side or replace the baseline mapper with reviewed expected JSON
fixtures. Rename tests and `PARITY.md` language so they state precisely which
generic JSON and rendered-output properties are being compared.

## Documentation and Plan Corrections

Update:

- `NexusTools/Script/README.md` to define JSON as the generic effective compiled
  representation and remove the “established metadata artifact” limitation;
- `NexusTools/Script/parity/PARITY.md` to describe the honest comparison
  boundary and remove every reference to a NexusScript-side Schema consumer;
- `work/plans/nexusscript-command-line-interface.md` to mark the old
  compiled-document-to-metadata boundary as superseded by this correction;
- `work/plans/nexusscript-template-manifest-rendering.md` to replace its
  Schema artifact path with the generic serializer while leaving manifest
  behavior unchanged;
- `NexusTools/Script/NexusScript.lpi` and the test project unit lists.

Do not rewrite unrelated historical plans. Where an approved plan contains the
specific superseded architectural claim, add a concise correction rather than
recasting its unrelated design history.

## Exact Files

### Add

- `NexusTools/Script/src/obNexusScriptJSON.pas`
- reviewed generic JSON fixture files under
  `NexusTools/Script/tests/fixtures/json/` if fixture-based expected results are
  chosen

### Modify

- `NexusTools/Script/NexusScript.lpi`
- `NexusTools/Script/README.md`
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- affected CLI and Mustache fixtures under
  `NexusTools/Script/tests/fixtures/cli/` and
  `NexusTools/Script/tests/fixtures/manifest/`
- `NexusTools/Script/parity/PARITY.md`
- parity fixtures or expected JSON under `NexusTools/Script/parity/fixtures/`
  only as required by the approved JSON contract
- `work/plans/nexusscript-command-line-interface.md`
- `work/plans/nexusscript-template-manifest-rendering.md`

### Delete

- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`

No NexusSchema production source is modified merely to accommodate the new
serializer. Legacy code remains an unchanged test baseline until the separate
NexusSchema cutover is explicitly authorized.

## Ordered Implementation Stages

1. Approve or correct the canonical generic JSON shape in this plan, including
   document envelope, definition/property representation, scalar typing, and
   named array-entry representation.
2. Add `obNexusScriptJSON.pas` and focused serializer tests using arbitrary
   domain-neutral fixtures.
3. Change the CLI to serialize `ArtifactDocuments` once and reuse that JSON for
   raw, single-template, and manifest output.
4. Update CLI, Mustache, and manifest tests to the generic JSON contract,
   including successful output for a non-Schema document.
5. Rewrite parity tests so the NexusScript side is only compilation plus the
   generic serializer; establish reviewed baseline fixtures or a baseline-only
   legacy projection.
6. Remove `TNexusScriptSchemaConsumer`, its project entries, test, helper, and
   all Schema metadata dependencies from the NexusScript executable path.
7. Correct the README, parity description, and the two superseded work-plan
   sections.
8. Run clean builds, the complete registered NexusScript suite, focused
   dependency searches, and the standard architecture archive checkpoint.

## Verification

Run:

```text
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-all
```

Focused searches must prove:

- `TNexusScriptSchemaConsumer` and `obNexusScriptSchemaConsumer` no longer
  exist;
- the NexusScript CLI has no `obMetaData*` or NexusSchema dependency;
- `obNexusScriptJSON.pas` contains no Schema-domain vocabulary;
- generic serialization has no kind-name dispatch such as `Schema`, `Table`,
  `Template`, or `Field`;
- only the legacy baseline side of parity tests references the legacy parser,
  metadata transformation, or old metadata JSON writer;
- raw, `/template`, and `/manifest` paths share one produced JSON string.

After approved implementation and successful verification, run
`scripts\New-NexusSourceArchive.ps1` and inspect the archive for the new
serializer and absence of the deleted consumer.

## Non-Goals

- No Schema-specific adapter under another name.
- No compatibility layer for the old metadata JSON contract unless separately
  approved as a real current requirement.
- No consumer/plugin/registry/dispatch architecture.
- No output-format switch or alternate binary compiler target.
- No changes to NexusScript syntax, references, composition, arrays, modules,
  includes, doctypes, or validation semantics.
- No inferred behavior from filenames or doctype names.
- No generic serialization of source ranges, diagnostics, provenance graphs,
  or compiler bookkeeping.
- No NexusSchema production cutover or deletion in this work.

## Approval Decisions

The architecture correction itself is settled by the human-owner direction.
Review approval is needed only for the observable generic JSON contract:

1. accept or amend the proposed document/definition/property envelope;
2. confirm that all scalar effective text remains JSON text rather than
   spelling-based number/Boolean inference;
3. accept or amend the representation of named scalar array entries;
4. decide whether legacy final-render parity is required in this correction or
   whether generic JSON parity is sufficient until templates are deliberately
   migrated.

No implementation should begin until those representation choices are
approved, because tests and Mustache fixtures necessarily encode them.

## Sub-Agent Plan

No delegation is requested. Keep implementation local because the serializer,
CLI replacement, and parity-test correction share one architectural seam and
the repository currently has overlapping uncommitted NexusScript work.
