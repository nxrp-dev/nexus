# Work Plan: Generic NexusScript JSON Compilation and Parity

## Inputs and Authorization

- Human-owner direction: replace the hard-coded Schema consumer with a generic
  NexusScript JSON compiler.
- Human-owner clarification: parity means fundamentally equivalent JSON data
  and generated results; formatting whitespace and byte identity are not
  requirements.
- Supplied work-plan request requiring inspection of the legacy writer,
  transformations, compiled model, equivalent fixtures, current consumer, and
  parity tests.
- Current NexusScript language contract, compiler, session, CLI, validators,
  NexusManifest batching, and tests.
- Repository architecture-change protocol and Pascal standards.

This is a work plan only. It authorizes no implementation, build, test, archive,
or unrelated repository change.

## Goal

Replace:

```text
compiled NexusScript
    -> TNexusScriptSchemaConsumer
    -> legacy Schema metadata
    -> legacy Schema transformations
    -> legacy JSON writer
```

with:

```text
compiled NexusScript artifact set
    -> generic NexusScript JSON compiler
    -> Mustache-compatible JSON
```

The JSON compiler must derive its result uniformly from generic compiled
information:

- definitions, kinds, and effective names;
- containment and scope;
- properties and effective values;
- ordered arrays and named entries;
- materialized structural definitions;
- composition contributors and effective composed structure;
- resolved references and target provenance;
- artifact-document order.

It must not branch on domain vocabulary such as `Schema`, `Table`, `Template`,
`Field`, `Type`, `Attributes`, or `Data`, and must not dispatch by doctype,
validator, filename, or extension.

## Parity Contract

Expected:

```text
legacy fixture
    -> unchanged TNexusSchemaParser
    -> unchanged TMetaDataTransform
    -> unchanged MetaDataToMustacheJSON
    -> expected JSON
```

Actual:

```text
existing equivalent NexusScript fixture
    -> TNexusScriptCompilationSession
    -> generic NexusScript JSON compiler
    -> actual JSON
```

Parity requires:

- equivalent JSON object members, arrays, scalar types, and scalar values;
- significant array order preserved;
- JSON formatting and object-member order ignored;
- both results rendered through the same unchanged Mustache template;
- rendered artifacts equivalent after normalizing line endings and trailing
  whitespace only.

The comparison permits no Schema adapter on the actual side, source reshaping
around expected JSON, baseline projection, alternate expected fixture,
template rewrite, or post-generation repair.

## Verified Current State

### Compiled graph

The compiled NexusScript model already retains the information needed for a
generic projection:

- `TNexusScriptCompiledDefinition.Kind`, `Name`, `Parent`, ordered
  `Properties`, and ordered `Children`;
- `TNexusScriptCompiledValue.EffectiveText`, `EffectiveName`, ordered `Items`,
  `StructuralDefinition`, `ResolvedDefinition`, `ResolvedProperty`,
  `EffectiveValue`, and `CompositionContributors`;
- flattened effective definitions after composition;
- original target identity and provenance for structural references;
- ordered artifact documents from `TNexusScriptCompilationSession`.

The mistake in the current path is not missing Schema information. It is that
`TNexusScriptSchemaConsumer` manually interprets that information into legacy
classes instead of letting a generic JSON compiler project the effective graph.

### Legacy output conventions

`obMetaDataJSON.pas` establishes a Mustache-oriented JSON view with:

- an artifact envelope and metadata object;
- ordered module and definition collections;
- `Name`/`Value` collection entries;
- per-item attributes;
- fields, indexes, references, and relationship collections;
- contextual convenience members such as parent names;
- collection-position conveniences such as `Comma`.

`TMetaDataTransform` supplies effective template composition, attribute
expansion, reference type resolution, and relationship records before writing.
Those results correspond to information already present in the compiled graph:
effective composition, definition-valued arrays, containment, and resolved
reference provenance.

## Generic Projection Rules

The new compiler is not a JSON dump of Pascal objects. It produces a stable,
Mustache-friendly projection modeled after the existing output contract.

### Artifact and document projection

- Compile the session's ordered `ArtifactDocuments` into one artifact.
- Treat each artifact root definition as one ordered module entry.
- Derive the artifact namespace from the root definition kind using one uniform
  naming rule; for a root kind `Schema`, this yields the established
  `NexusSchema` namespace without a `Schema` conditional.
- Place shared artifact metadata and ordered module entries under the standard
  `MetaData` view expected by Mustache.
- Merge included artifact documents in session order. Append ordered
  collections; merge shared scalar metadata by effective name; reject
  conflicting duplicate values.
- Require compatible artifact root kinds within one artifact set. Report a
  clear conflict instead of silently mixing unrelated document languages.

### Collection discovery

- Definitions are classified by generic structural shape, not by literal kind
  names.
- Repeated sibling definitions of a kind form an ordered collection whose
  member name is derived mechanically from the kind.
- A definition that owns one homogeneous definition collection acts as a
  collection provider: its contained effective entries are projected into the
  provider-kind collection without emitting an extra source-only wrapper.
- A definition containing named scalar leaves projects as a named-value set.
- A root-level scalar definition containing an effective `Value` projects into
  shared artifact attributes by its effective definition name.
- A named resource definition with an explicit effective name and one scalar
  payload projects as a `Name`/`Value` entry in its mechanically derived
  collection.
- Collection-name inflection must be centralized, deterministic, and tested.
  It must not contain a list of Schema kinds. The implementation must cover
  regular singular kinds, already-plural kinds, and invariant collection names
  through general lexical rules.

### Definition projection

For every projected structural definition:

- emit `Name` from the definition or array entry's effective local name;
- emit effective scalar properties;
- recursively emit effective child definitions and definition-valued arrays;
- use the materialized definition held by the compiled value rather than
  dereferencing source syntax again;
- retain collection order;
- emit empty standard collections where the established Mustache view requires
  iterable absence rather than a missing context;
- expose ordinary extra scalar properties through `Attributes` without knowing
  their domain meaning.

An explicit local array-entry name changes the projected `Name` only. The
materialized definition content and original reference provenance remain the
source of all other projected values.

### Contextual convenience members

The compiler may derive view conveniences from generic context:

- every structural item knows its containing definition;
- a contextual name is derived mechanically as `<containing kind>Name`;
- therefore an item under a definition of kind `Table` exposes `TableName`
  without testing for `Table`;
- the same rule applies to any other containing kind;
- collection entries receive a positional `Comma` value: comma for every item
  except the last, empty text for the last;
- this rule applies to all ordered output collections, not only fields.

### Scalar and property projection

- Preserve effective scalar source categories needed by JSON; do not guess
  numbers or Booleans from arbitrary text.
- Compiler-generated flags are emitted as JSON Booleans.
- Declared text remains JSON text.
- A scalar payload in a named scalar entry is exposed as `Value`.
- When the established view requires an item-qualified member, derive it
  mechanically from item kind plus property name. For example, kind `Field`
  plus property `Type` yields `FieldType`; the code performs the same operation
  for every kind/property combination and contains no `Field` or `Type` branch.
- Emit only the members defined by the generic projection contract. Do not add
  an alternate raw-model representation beside the established view merely
  because Mustache would ignore it.

### Composition projection

- Serialize the effective composed definition, not the unflattened source
  declaration.
- Use `CompositionContributors` to expose ordered source references where the
  established view requires them.
- Do not copy template members during JSON compilation; composition has already
  produced the effective structural result.
- Verify that inherited fields and attributes appear once, in effective
  precedence order.

### Reference projection

For every resolved definition reference encountered in an effective property
or array entry:

- emit a generic Boolean reference flag;
- emit the resolved target's effective name;
- retain an explicitly selected target member when the reference provenance
  identifies one;
- resolve the effective scalar type from the target structure when the
  referring property itself has no effective text;
- add an ordered relationship record to the containing definition's
  relationship collection;
- derive relationship identity and constraint text mechanically from the
  containing definition, resolved target, and referring member names;
- expose source/target contextual names required by the Mustache view;
- never decide behavior by testing the source or target kind name.

The initial relationship naming convention is the established NexusSchema
convention because that is the behavioral specification. It is applied to all
structural reference relationships by the same algorithm. If a non-Schema
fixture exposes a nonsensical or conflicting result, stop and return the
generic convention for owner review rather than adding a kind-specific branch.

### Attribute projection

- Recognize a referenced named-value set by its compiled shape: a materialized
  definition containing named scalar leaves.
- Expand such a set into the referring item's `Attributes` object.
- Apply referenced sets in compiled order and use ordinary effective-name
  replacement for duplicate keys.
- Preserve the ordered reference list separately where the output contract
  exposes it.
- Do not identify attribute sets by their definition kind or property name.
- A reference to a structural definition that is not a named-value set remains
  a structural/reference relationship and is not flattened as attributes.

## Evidence Mapping

| Established output | Generic compiled source | Generic derivation |
|---|---|---|
| Artifact namespace | Root definition kind | Uniform `Nexus` plus effective root-kind naming rule. |
| `MetaData.Modules[]` | Ordered artifact root definitions | One module entry per root, in artifact-document order. |
| Module `Name` | Root definition name | Effective name. |
| Shared `Attributes` | Root scalar value definitions | Shape-based scalar-definition promotion by effective name. |
| Default primary-key type | The current equivalent fixture declares the effective setting | Emit the compiled shared scalar. Add an absent-setting test separately; if matching the legacy default requires recognizing its name, stop rather than hard-code it. |
| `Data[]` | Named resource-shaped definitions | Mechanically derived collection plus `Name`/single-payload `Value`. |
| `Types[]` | Homogeneous collection-provider definition containing named scalar structural entries | Provider kind determines collection name; entries become `Name`/`Value`. |
| `Templates[]`, `Tables[]`, and other definition collections | Repeated effective structural definitions | Mechanically derived collection name from kind; no enumerated kind table. |
| Attribute sets | Definitions containing named scalar leaves | Named-value-set projection. |
| Item `Attributes` | Extra scalar properties and referenced named-value sets | Merge direct effective attributes and shape-recognized referenced sets. |
| `Fields[]` | Effective definition-valued `Fields` array | Recursive structural-array projection in compiled order. |
| Field `Name` | Array entry `EffectiveName` | Standard structural item name. |
| `TableName` | Containing definition kind and name | Generic `<parent kind>Name` contextual alias. |
| `FieldType` | Item kind plus effective `Type` property or resolved reference target | Generic `<item kind><property name>` alias; reference fallback uses target provenance. |
| `IsReference` | `ResolvedDefinition`/structural reference provenance | Compiler-generated JSON Boolean. |
| `ReferenceEntity` | Resolved target effective name | Standard target-name convenience. |
| `ReferencedFieldName` | Resolved member provenance when present | Standard target-member convenience. |
| `Comma` | Array position and count | Uniform collection-position convenience. |
| Template references | Ordered composition contributors | Contributor effective names. |
| Attribute references | Definition-valued references to named-value-set shapes | Preserve references and expand their effective values. |
| Child references | Other explicitly retained structural-reference arrays | Preserve effective reference names without attribute flattening. |
| Foreign-key/relationship entries | Structural references contained by effective definitions | Uniform relationship record derived from parent, member, and target context. |
| `ConstraintName` | Parent name, target/member provenance | Established deterministic relationship-name formula, applied generically. |
| Effective inherited fields | Flattened compiled definition | Serialize effective structure directly; no JSON-time template copying. |
| Included modules | Ordered `ArtifactDocuments` | Append/merge through generic artifact aggregation. |
| Empty iterable collections | Known generic projection slots discovered for an item/category | Emit empty arrays/objects consistently so Mustache falsey iteration remains stable. |

## Implementation Shape

Add one unit:

```text
NexusTools/Script/src/obNexusScriptJSON.pas
```

Expose one narrow entry point accepting the ordered artifact documents and
returning JSON text. Keep traversal helpers private. Use `fpjson` for ownership,
typing, escaping, and output.

Do not add a consumer interface, registry, callback, visitor framework,
doctype dispatcher, or output-format abstraction.

Separate private passes are justified inside the unit:

1. index effective definitions and resolved relationships across the artifact
   set;
2. project artifact metadata and ordered definitions;
3. add generic contextual, collection, and relationship conveniences;
4. serialize the resulting owned `fpjson` tree.

The passes remain implementation details of one JSON compiler.

## CLI Integration

Modify `NexusTools/Script/cli/obNexusScriptCommand.pas` so it:

1. compiles the input once;
2. optionally validates through the explicit doctype;
3. calls the generic JSON compiler once for `ArtifactDocuments`;
4. emits that JSON directly without a rendering option;
5. passes that same JSON string to `/template`;
6. passes that same JSON string to every `/manifest` entry.

Preserve all current stdout/file behavior and NexusManifest sequencing, path,
overwrite, and failure behavior.

Remove CLI dependencies on:

- `obNexusScriptSchemaConsumer`;
- `obMetaDataModuleList`;
- `obMetaDataTransformations`;
- `obMetaDataJSON`.

## Remove the False Parity Path

Delete `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`. Remove it
from both Lazarus projects, all uses clauses, tests, and helpers. Delete
`TestSchemaConsumer` and replace `LoadNexusScript` with a helper that returns
the direct generic JSON result.

Do not retain the class for tests. Do not replace it with another
compiled-document-to-Schema mapping.

## Tests

### Domain-neutral projection tests

Use arbitrary kinds and names to prove:

- artifact namespace and module projection;
- mechanical collection discovery and inflection;
- named scalar, resource, named-value-set, and structural collection shapes;
- effective local names and definition-valued array entries;
- parent-kind contextual aliases;
- item-kind/property aliases;
- position metadata on ordered collections;
- composed effective structure without duplicate copying;
- reference flags, target information, and relationship records;
- referenced named-value-set expansion;
- JSON string versus compiler-generated Boolean typing;
- deterministic include aggregation;
- duplicate/conflict diagnostics;
- correct escaping.

At least one complete fixture must use no Schema vocabulary. Focused searches
must prove the JSON unit contains no comparisons against domain kind/property
names.

### Honest Schema parity tests

For inForce and Storm:

- expected JSON comes only from the unchanged legacy parser, transform, and
  writer;
- actual JSON comes only from the existing equivalent NexusScript fixture,
  compilation session, and generic JSON compiler;
- compare parsed JSON recursively by member name, scalar type/value, and array
  order;
- require the same meaningful member set; do not excuse additional members
  merely because the current Mustache template ignores them;
- run both JSON strings through the same unchanged
  `DatabaseSchema.create.mustache`;
- compare rendered output after line-ending and trailing-whitespace
  normalization;
- report the exact JSON path or rendered line of the first substantive
  difference.

Do not change either parity source merely to make comparison pass.

### CLI and manifest regression

- A non-Schema NexusScript input emits useful JSON.
- Default stdout and `/output` contain the generic JSON.
- `/template` receives exactly the raw JSON string.
- Every manifest entry receives that same string.
- Existing validation, diagnostics, output, manifest ordering, overwriting,
  traversal rejection, and stop-on-error behavior remain unchanged.

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

Do not modify the equivalent legacy/NexusScript parity sources, NexusSchema
production code, metadata transformations, JSON writer, or existing Mustache
template.

## Ordered Implementation Stages

1. Add structural JSON comparison and rendered-output normalization helpers so
   parity failures report semantic paths rather than byte offsets.
2. Add `obNexusScriptJSON.pas` with artifact/module projection, definition and
   collection discovery, and domain-neutral fixtures.
3. Add contextual names, position metadata, named-value-set expansion,
   composition projection, and reference/relationship projection through
   uniform graph rules.
4. Run inForce parity after each projection category. Correct the generic rule,
   never the source fixture or expected side.
5. Add artifact-document aggregation and make Storm parity pass.
6. Verify both paths through the same unchanged Mustache template.
7. Replace the CLI artifact construction with one generic JSON call and reuse
   the result for raw, `/template`, and `/manifest` output.
8. Delete the Schema consumer and every NexusScript-side metadata dependency.
9. Update generic CLI/manifest tests and documentation.
10. Clean-build, run the full suite, perform focused searches, and create the
    standard full-source archive.

Compile after stages 2, 5, 7, and 8.

## Stop Conditions

Stop and return the exact compiled structure and expected JSON path if:

- a required value cannot be derived from effective structure, containment,
  order, composition, or reference provenance;
- a proposed rule works only by comparing a kind/property name to Schema
  vocabulary;
- two generic structural shapes require contradictory projections;
- parity requires changing a source fixture or existing Mustache template;
- a convenience convention produces nonsensical or conflicting behavior in
  the domain-neutral fixture.

Do not conceal such a conflict with an exception table.

## Verification

Run clean builds of `NexusScript.lpi` and `NexusScriptTestModule.lpi`, followed
by the complete registered NexusScript suite.

Focused searches must prove:

- `TNexusScriptSchemaConsumer` no longer exists;
- the CLI and JSON compiler have no `obMetaData*` or NexusSchema dependency;
- the JSON compiler has no comparisons or dispatch for Schema-domain names;
- only the expected legacy half of parity tests uses `TNexusSchemaParser`,
  `TMetaDataTransform`, and `MetaDataToMustacheJSON`;
- raw, `/template`, and `/manifest` share one generated JSON string.

After approved implementation, run `scripts/New-NexusSourceArchive.ps1` and
verify the new JSON compiler is present and the consumer is absent.

## Non-Goals

- No Schema adapter under another name.
- No source reshaping around JSON output.
- No changed legacy template or expected path.
- No consumer/plugin/registry architecture.
- No doctype or filename dispatch.
- No output-format switch or binary target.
- No unrelated syntax, validation, CLI, or NexusManifest change.
- No NexusSchema production cutover or removal.

## Sub-Agent Plan

No delegation is requested. The JSON projection, parity comparison, and CLI
replacement share one integration seam, and the worktree contains overlapping
uncommitted NexusScript changes.
