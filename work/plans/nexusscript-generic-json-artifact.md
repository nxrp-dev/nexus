# Work Plan: Domain-Shaped NexusScript JSON Serialization

## Inputs

- Human-owner request for a generic NexusScript JSON emitter whose output can
  be consumed by ordinary Mustache templates in the same manner as the
  established NexusSchema JSON model.
- Human-owner clarification that limitations serving a coherent design are
  desirable; this work must not extend Mustache merely because an extension is
  possible.
- Human-owner clarification that emitted JSON must preserve the completed
  domain-shaped model rather than expose a generic AST or group definitions by
  kind.
- Human-owner decision to preserve definition and named-item identity as
  serialization metadata under the reserved member `_nx`.
- Human-owner decision that the Schema-specific NexusScript producer is not
  parity infrastructure and must be deleted without a compatibility adapter.
- Current NexusScript compiled model, compiler, session, CLI, tests, validator
  fixtures, and interrupted uncommitted manifest/validation work.
- Current NexusSchema `obMetaDataJSON.pas` and production Mustache templates as
  the repository precedent for object, dictionary, array, and scalar shape.
- Repository architecture-change protocol, NexusScript folder instructions,
  and Pascal standards.

This is a work plan only. It does not authorize implementation, builds, tests,
program execution, archive creation, or changes outside this plan file.

## Summary

Replace the Schema-specific NexusScript artifact path with a domain-neutral
serializer for the completed NexusScript model.

The serializer will preserve the structure already expressed by the model:

- named definitions become named JSON object members;
- definition properties become JSON object members;
- direct child definitions become named JSON object members;
- array properties remain ordered JSON arrays;
- structural values remain JSON objects;
- scalar values remain JSON strings;
- definition kind and identity are retained separately under `_nx`.

The serializer does not design a Mustache view, infer domain relationships,
pluralize names, group definitions by kind, or perform compiler work. Mustache
continues to use its standard distinction: objects and dictionaries provide
named lookup, while arrays provide iteration.

## Verified Findings

- `TNexusScriptCompiledDocument.Definitions` contains compiled root
  definitions.
- `TNexusScriptCompiledDefinition` exposes `Kind`, `Name`, ordered
  `Properties`, and ordered `Children`.
- The parser rejects a property and child with the same member name, and root
  definition names are unique within a compiled document.
- `TNexusScriptCompiledProperty` exposes its exact model member name and its
  compiled value.
- `TNexusScriptCompiledValue` represents text, arrays, references, text
  composition, and structural definitions. It also retains entry/effective
  names and compiler resolution/provenance state.
- Compiled arrays retain item order and effective entry names. Composition and
  reference evaluation occur in the compiler before successful compilation
  returns.
- The current effective result is not represented uniformly for every source
  form: completed text, completed arrays, and completed definitions may be
  exposed through different existing fields. The serializer must not learn
  reference or composition semantics to compensate for that storage shape.
- `TNexusScriptCompilationSession.ArtifactDocuments` supplies the entry
  artifact followed by included artifact documents in deterministic order;
  module-only and doctype-only documents are not artifact documents.
- The current CLI passes artifact documents through
  `TNexusScriptSchemaConsumer`, `TMetaDataTransform`, and
  `MetaDataToMustacheJSON`. This is the incorrect domain-specific boundary to
  remove.
- NexusSchema emits singular structures and dictionaries as JSON objects and
  typed lists such as `Modules`, `Tables`, and `Fields` as JSON arrays.
- NexusSchema Mustache templates iterate those arrays and perform known-key
  lookup in objects such as `Attributes`; they do not enumerate dictionary
  members.
- SynMustache follows the same boundary. JSON arrays are iterable sections;
  JSON objects are single contexts. Its existing `-first`, `-last`, and
  `-index` extensions are sufficient for the planned templates.
- `NexusTools/Script/src/obNexusScriptJSON.pas` does not currently exist.
- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas` and its CLI,
  project, test, and documentation references still exist.

## Architecture Problem

NexusScript compilation is domain-neutral, but artifact production currently
converts the compiled result into the legacy NexusSchema metadata model. That
conversion discards the generic domain shape and replaces it with Schema
knowledge and derived Schema fields.

The discarded work plan made the opposite mistake in a new form: it proposed
grouping definitions by kind and injecting a universal domain-level `Name`.
That would create a second, emitter-designed model instead of serializing the
completed NexusScript model.

The correct boundary is:

```text
NexusScript source
    -> compiler-owned completed domain model
    -> mechanical JSON serialization with reserved _nx metadata
    -> raw JSON or ordinary Mustache rendering
```

The compiler owns meaning and completion. The serializer owns JSON encoding.
Mustache owns manifestation. None may absorb the responsibilities of another.

## Target Contract

### Ownership

#### Compiler and compiled model

The compiler must finish reference resolution, composition, projection,
effective naming, and value completion before artifact serialization begins.

The compiled model must provide a single artifact-facing answer for each
completed value:

- scalar text;
- ordered array;
- structural definition.

The artifact-facing boundary belongs to the compiled model/compiler. If the
existing fields cannot expose that answer without testing source forms or
following resolution mechanics, reshape the existing compiled-value boundary
in `obNexusScriptModel.pas` and `obNexusScriptCompiler.pas`. Do not create a
second effective tree, projection model, consumer model, or normalization
pipeline.

Compiler source text, `ResolvedDefinition`, `ResolvedProperty`,
`ResolvedValue`, composition contributors, and source ranges are not inputs to
JSON mapping decisions.

#### JSON serializer

Add:

```text
NexusTools/Script/src/obNexusScriptJSON.pas
```

It owns only:

- traversal of ordered completed documents, definitions, properties,
  children, and array items;
- creation and ownership of `fpjson` objects and arrays;
- `_nx` metadata encoding;
- JSON string escaping, Unicode handling, formatting, and serialization;
- focused errors when the completed model violates the reserved JSON
  contract.

The serializer accepts compiled model objects, not parser, compiler, session,
validator, NexusSchema, metadata, or Mustache types. The CLI enumerates the
session's `ArtifactDocuments` and supplies their compiled documents in order.

#### CLI and Mustache

The CLI compiles once, optionally validates once, serializes once, and then
uses the same JSON string for:

- raw stdout/file JSON;
- `/template` rendering;
- every `/manifest` template entry.

No Mustache syntax, helper, dictionary-iteration extension, or renderer change
is part of this work.

### Document and dictionary mapping

The emitted JSON root is an object.

- Each compiled root definition becomes a member named by its completed
  definition name.
- Each direct child definition becomes a member of its parent object named by
  the child's completed definition name.
- The member value is the serialized definition object.
- Definition kind is not used as a JSON member name and definitions are not
  grouped by kind.
- Root definitions from successive artifact documents are added to the same
  root object in artifact-document order.
- Duplicate root member names across artifact documents are an emission error;
  the serializer does not merge or rename them.
- JSON object member order is not a semantic contract. A model that requires
  ordered iteration must express an array.

This gives direct definitions their natural dictionary representation. A
template may access a known member by name, but ordinary Mustache does not
enumerate dictionary keys. That limitation is intentional.

### Definition objects and `_nx`

Every serialized definition object begins with the reserved `_nx` member:

```json
{
  "_nx": {
    "Kind": "Field",
    "Name": "ID"
  },
  "Type": "Integer"
}
```

- `_nx.Kind` is the definition's completed kind.
- `_nx.Name` is the definition's completed/effective identity at its current
  location.
- `_nx` is metadata, not a domain property.
- A domain object may independently contain `Name`, `Kind`, or any other
  ordinary member without ambiguity.
- A property or direct child named `_nx` is an emission error because `_nx` is
  reserved by this serialization contract.
- Initial `_nx` metadata is limited to `Kind` and `Name`. Source ranges,
  original names, reference targets, provenance, and compiler diagnostics are
  outside this work.

Example with independent metadata and domain identity:

```json
{
  "_nx": {
    "Kind": "Table",
    "Name": "CustomerDefinition"
  },
  "Name": "CUSTOMER"
}
```

`{{Name}}` is domain data. `{{_nx.Name}}` is NexusScript definition identity.

### Property and value mapping

- A property uses its exact completed property name as the JSON member name.
- Completed scalar text becomes a JSON string.
- Empty text remains an empty JSON string.
- Scalar spelling is not reinterpreted as JSON Boolean, number, or null.
- A completed array becomes a JSON array in compiled item order.
- A completed structural property becomes a JSON object using the definition
  and `_nx` rules above.
- A reference, composition, projection, or included value is indistinguishable
  from the equivalent literal completed value. The serializer does not inspect
  how the compiler produced it.

### Array item mapping

#### Unnamed scalar

An unnamed scalar remains a scalar:

```json
"Options": ["-O2", "-Mdelphi"]
```

#### Named scalar

A named scalar requires an object so its identity is not lost:

```json
{
  "_nx": {
    "Name": "PrimaryPlatform"
  },
  "Value": "win64"
}
```

- `_nx.Name` is the completed array-entry name.
- `Value` contains the completed scalar text.
- `_nx.Kind` is omitted because a scalar array entry is not a definition.
- A named nested-array entry uses the same wrapper with its array under
  `Value`.

#### Structural item

A definition-valued array item is the ordinary serialized definition object:

```json
{
  "_nx": {
    "Kind": "Field",
    "Name": "ID"
  },
  "Type": "Integer"
}
```

Mixed arrays are emitted item by item without validator or domain knowledge.

### Complete example

The following illustrates the target mechanics; the serializer contains none
of this domain vocabulary:

```nxscript
NexusSchema NexusSchema {
    MetaData MetaData {
        Modules: [
            Module SalesDefinition {
                Name: Sales;
                Tables: [
                    Table CustomerDefinition {
                        Name: CUSTOMER;
                        Fields: [
                            Field IdDefinition {
                                Name: ID;
                                FieldType: INTEGER;
                            },
                            Field DisplayNameDefinition {
                                Name: DISPLAY_NAME;
                                FieldType: "VARCHAR(100)";
                            }
                        ];
                    }
                ];
            }
        ];
    }
}
```

Emitted JSON:

```json
{
  "NexusSchema": {
    "_nx": {
      "Kind": "NexusSchema",
      "Name": "NexusSchema"
    },
    "MetaData": {
      "_nx": {
        "Kind": "MetaData",
        "Name": "MetaData"
      },
      "Modules": [
        {
          "_nx": {
            "Kind": "Module",
            "Name": "SalesDefinition"
          },
          "Name": "Sales",
          "Tables": [
            {
              "_nx": {
                "Kind": "Table",
                "Name": "CustomerDefinition"
              },
              "Name": "CUSTOMER",
              "Fields": [
                {
                  "_nx": {
                    "Kind": "Field",
                    "Name": "IdDefinition"
                  },
                  "Name": "ID",
                  "FieldType": "INTEGER"
                },
                {
                  "_nx": {
                    "Kind": "Field",
                    "Name": "DisplayNameDefinition"
                  },
                  "Name": "DISPLAY_NAME",
                  "FieldType": "VARCHAR(100)"
                }
              ]
            }
          ]
        }
      ]
    }
  }
}
```

Ordinary Mustache:

```mustache
{{#NexusSchema.MetaData.Modules}}
-- module {{Name}}
{{#Tables}}
create table {{Name}} (
{{#Fields}}
  {{Name}} {{FieldType}}{{^-last}},{{/-last}}
{{/Fields}}
);
{{/Tables}}
{{/NexusSchema.MetaData.Modules}}
```

The template ignores `_nx`. A diagnostic or generic template may explicitly
use `{{_nx.Kind}}` or `{{_nx.Name}}` without changing the domain model.

## Scope

### Add

- `NexusTools/Script/src/obNexusScriptJSON.pas`
- focused domain-neutral serialization fixtures under
  `NexusTools/Script/tests/fixtures/json/`
- focused Mustache fixtures under the same test area

### Modify

- `NexusTools/Script/src/obNexusScriptModel.pas`
  - only if required to expose one compiler-owned, artifact-facing completed
    value category without serializer knowledge of resolution mechanics.
- `NexusTools/Script/src/obNexusScriptCompiler.pas`
  - only if required to guarantee the artifact-facing completed-value
    contract after successful compilation; do not move serialization here.
- `NexusTools/Script/NexusScript.lpi`
  - include the JSON serializer and remove the deleted Schema producer.
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
  - replace Schema conversion with ordered compiled-document serialization.
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`
  - include the serializer and remove the deleted Schema producer.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - remove Schema-producer/output tests and add compiled-model, JSON, raw CLI,
    `/template`, and `/manifest` coverage.
- `NexusTools/Script/README.md`
  - document the domain-shaped JSON rules, `_nx`, dictionaries versus arrays,
    and Mustache examples.
- `NexusTools/Script/parity/PARITY.md`
  - remove claims that the Schema-specific producer or its derived output is a
    NexusScript parity boundary.

### Delete

- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`

Remove `TNexusScriptSchemaConsumer` and every associated CLI, project, test,
documentation, metadata, and transformation reference. Do not retain, rename,
move, or replace it with a compatibility adapter.

## Out Of Scope

- NexusScript syntax, lookup, composition, projection, module, include, or
  validator semantics;
- a second artifact tree, consumer model, view model, normalization pipeline,
  plugin system, or serializer registry;
- NexusSchema production code, metadata types, transformations, or templates;
- reconstruction of legacy NexusSchema-derived JSON;
- Mustache engine, syntax, helpers, filters, or dictionary iteration;
- automatic pluralization, kind grouping, domain naming, default insertion,
  sorting, filtering, or derived convenience fields;
- inference of JSON Boolean, numeric, or null types;
- source/provenance/debug metadata beyond `_nx.Kind` and `_nx.Name`;
- compatibility modes or alternate JSON shapes;
- unrelated validator, manifest, CLI, fixture, README, or plan cleanup.

## Staged Implementation Plan

### Stage 0: Protect and reconcile the interrupted worktree

- Inventory the existing uncommitted NexusScript CLI, tests, README,
  validators, fixtures, and plan changes before editing.
- Identify exact overlap with the manifest and validation work already in the
  worktree.
- Preserve all unrelated changes and stage only files belonging to an approved
  implementation checkpoint.
- Stop for human direction if ownership of an overlapping hunk cannot be
  determined safely.

### Stage 1: Establish the completed-model serialization boundary

- Add focused compiler/model tests for literal, referenced, composed,
  projected, scalar, array, and structural values.
- Prove that successful compilation exposes one artifact-facing category and
  completed content for every value without serializer interpretation of
  source form or resolution state.
- If necessary, reshape the existing compiled-value boundary and compiler
  completion step narrowly. Keep one compiled tree and preserve existing
  compiler provenance fields outside serialization decisions.
- Verify completed root, child, structural, and array-entry names used by
  `_nx`.
- Compile after any model/compiler structural change.

### Stage 2: Implement mechanical JSON serialization

- Add `obNexusScriptJSON.pas` using `fpjson` ownership throughout.
- Serialize root and child definitions as name-keyed dictionary members.
- Serialize properties, scalars, arrays, structural definitions, and named
  scalar wrappers according to the target contract.
- Add `_nx.Kind` and `_nx.Name` exactly where specified.
- Reject reserved `_nx` collisions and duplicate root dictionary names with
  focused diagnostics.
- Add exact structural tests for escaping, Unicode, empty values, array order,
  object lookup, and metadata/domain-name coexistence.

### Stage 3: Replace the Schema-specific CLI path

- Make the CLI pass ordered compiled artifact documents to the serializer
  exactly once.
- Preserve optional validation before serialization.
- Reuse the same JSON string for raw output, `/template`, and `/manifest`.
- Delete `obNexusScriptSchemaConsumer.pas`.
- Remove `TNexusScriptSchemaConsumer`, `TMetaDataModuleList`,
  `TMetaDataTransform`, `MetaDataToMustacheJSON`, and their metadata unit
  dependencies from the NexusScript executable path.
- Remove `TestSchemaConsumer`, the inForce/Storm derived Schema-output
  assertions, and helpers used only to construct or compare the discarded
  Schema metadata output.
- Remove the producer from both project files and correct `PARITY.md`.

### Stage 4: Verify Mustache and document the contract

- Render the complete NexusSchema-shaped fixture with ordinary SynMustache
  sections, dotted lookup, and `-last`; add no helpers or renderer changes.
- Render an unrelated domain fixture proving the serializer contains no Schema
  vocabulary.
- Verify dictionaries by known-key lookup and arrays by iteration.
- Verify templates may ignore `_nx` or use `_nx.Kind` and `_nx.Name`.
- Verify raw, `/template`, and every `/manifest` entry receive the identical
  JSON structure.
- Update the README with the final object/dictionary/array/scalar rules and the
  reviewed examples.

## Sub-Agent Delegation

This plan does not authorize or recommend sub-agent use. Implementation remains
local unless the human owner explicitly requests sub-agent use in the current
conversation. Plan approval and implementation approval do not authorize delegation.

## Verification Plan

After explicit implementation approval:

```text
lazbuild NexusTools\Script\NexusScript.lpi
lazbuild NexusTools\Script\tests\NexusScriptTestModule.lpi
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-suite NexusScript.Compiler
```

Focused tests must cover:

- root and direct-child dictionary members keyed by definition name;
- `_nx.Kind` and effective `_nx.Name` on every serialized definition;
- coexistence of `_nx.Name` with a domain property named `Name`;
- reserved `_nx` property/child rejection;
- exact property names and string values;
- empty strings, empty objects, and empty arrays;
- unnamed scalar arrays;
- named scalar and named nested-array wrappers;
- structural properties and structural array entries;
- mixed arrays;
- array item order;
- known-key dictionary access in Mustache;
- absence of dictionary enumeration mechanics;
- references, composition, projection, modules, and includes producing the
  same JSON as equivalent completed literal structures;
- multiple artifact documents and duplicate root-name failure;
- JSON escaping and Unicode;
- raw JSON, `/template`, and `/manifest` reuse of one serialized artifact;
- a NexusSchema-shaped template and an unrelated domain template.

Focused searches must prove:

- `obNexusScriptSchemaConsumer.pas` is absent;
- `TNexusScriptSchemaConsumer` and all references are absent;
- the generic CLI path has no `obMetaData*`, `TMetaData*`,
  `MetaDataToMustacheJSON`, or Schema vocabulary;
- the serializer does not inspect source text, resolution targets,
  composition contributors, validators, doctypes, filenames, or definition
  kinds for dispatch;
- no kind grouping, pluralization, synthetic domain-level `Name`, alternate
  artifact tree, or Mustache dictionary extension was introduced;
- all serializer metadata is contained beneath `_nx`.

After successful implementation verification, run:

```text
scripts\New-NexusSourceArchive.ps1
```

Verify the archive contains the serializer, fixtures, tests, and documentation
and does not contain `obNexusScriptSchemaConsumer.pas`.

## Risks And Questions

- The current compiled-value storage exposes completed results through several
  fields. The serializer must not encode that compiler storage scheme. Any
  required correction belongs to the existing compiled-model/compiler
  boundary and must remain narrow.
- Root definitions and direct children are proposed as dictionary members
  keyed by effective definition name. This intentionally makes them suitable
  for known-key lookup, not Mustache enumeration. Models requiring iteration
  must use array-valued relationships.
- `_nx` is a new reserved serialization member. The implementation must reject
  collisions consistently and document the reservation.
- `_nx.Name` preserves effective identity only. Original/source identity and
  provenance remain available to compiler tooling but are not serialized in
  this pass.
- Named scalar array entries necessarily use an object wrapper while unnamed
  scalar entries remain JSON strings. Exact fixtures must make this deliberate
  type distinction stable.
- JSON objects do not carry a semantic ordering guarantee. Only arrays may be
  used when output order matters.
- Legacy NexusSchema output contains derived values such as `Comma`, inherited
  table context, constraint names, and transformed references. The generic
  serializer will not recreate them; model data or ordinary template
  facilities must provide required manifestation inputs.
- The interrupted worktree overlaps the planned CLI, test, and README edits.
  No implementation should begin without the Stage 0 ownership review.

## Approval Gate

No implementation begins until the human owner explicitly approves this work
plan. Approval is required before changing the compiled model/compiler,
adding the serializer or fixtures, modifying the CLI/projects/tests/README,
deleting the Schema producer, building, testing, running the archive script,
or performing implementation delegation.
