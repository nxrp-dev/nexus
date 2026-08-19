# Work Plan: Mechanical JSON Emission from Compiled NexusScript

## Inputs and Authorization

- Human-owner requirement: NexusScript source is already structurally JSON-friendly.
- Human-owner requirement: compilation resolves references, relationships,
  inheritance, composition, materialization, names, and values.
- Human-owner requirement: JSON generation mechanically emits the existing
  compiled tree.
- Human-owner clarification: source/provenance information may remain attached
  to compiled nodes and may eventually be emitted for unusual Mustache needs;
  defining that JSON shape is deferred from this work.
- Current `TNexusScriptCompiledDocument`, compiled model, compilation session,
  CLI, Mustache rendering, NexusManifest batching, and tests.
- Repository architecture-change protocol and Pascal standards.

This is a work plan only. It authorizes no implementation, build, test, archive,
or unrelated repository change.

## Goal

Implement this direct path:

```text
NexusScript source
    -> NexusScript compiler
    -> TNexusScriptCompiledDocument tree
    -> mechanical JSON emitter
    -> raw JSON, Mustache, or NexusManifest output
```

`TNexusScriptCompiledDocument` is the one authoritative compiled result. This
work does not add another document model, projection, normalization pass,
finalization pass, adapter, consumer, or intermediate representation.

## Verified Existing Boundary

The existing compiled model already provides the structure required by a JSON
emitter:

- `TNexusScriptCompiledDocument.Definitions`;
- `TNexusScriptCompiledDefinition.Kind`, `Name`, `Properties`, and `Children`;
- `TNexusScriptCompiledProperty.Name` and `Value`;
- compiled scalar text;
- compiled array items and their effective names;
- compiled structural definitions;
- source ranges and resolution/provenance fields retained on the same nodes;
- `TNexusScriptCompilationSession.ArtifactDocuments` in deterministic artifact
  order.

Existing compiler tests already exercise scalar composition, references,
structural definitions, definition-valued array entries, local entry names,
array results, composition, projection, modules, and includes on these compiled
objects.

The presence of source, resolution, provenance, or evaluation metadata does not
create a second tree and does not require model cleanup. The emitter ignores
metadata outside the JSON contract.

## Architectural Rule

The emitter accepts the existing ordered compiled artifact documents and
recursively writes their effective structural content.

The emitter must not:

- resolve a reference;
- apply inheritance or composition;
- materialize, clone, merge, or rebind a definition;
- evaluate text composition;
- interpret provenance or source-resolution metadata;
- validate compiler completeness;
- consult a validator or doctype;
- interpret definition kinds or property names;
- derive Schema, Build, SQL, Pascal, or other domain data;
- inspect filenames;
- create a second compiled/effective tree.

If a focused test proves that a successfully compiled, valid NexusScript value
cannot be mechanically read from the existing compiled node, stop with that
specific example. Do not pre-emptively change the compiled model or invent an
intermediate representation.

## Mechanical JSON Contract

### Artifact documents

- Traverse `TNexusScriptCompilationSession.ArtifactDocuments` in its existing
  order.
- The entry artifact is first and included artifacts follow under existing
  session rules.
- Module-only and doctype-only documents remain absent because the session
  already excludes them from the artifact set.
- Append definitions from successive artifact documents to the corresponding
  exact-kind JSON arrays.

### Definitions

At document scope and within every compiled definition:

- group definitions by exact `Kind`;
- use the exact kind text as the JSON member name;
- make that member an ordered JSON array;
- emit each definition as a JSON object;
- emit its compiled effective name as `Name`;
- emit its compiled properties as direct members;
- emit its compiled child definitions recursively through the same exact-kind
  array rule.

Do not pluralize, singularize, alias, rename, or classify kinds. Do not add
generic `Definitions`, `Properties`, `Children`, or artifact-envelope members.

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

`Project` and `Target` have no built-in meaning. Any definition kinds follow
the same rule.

### Properties and scalar values

- Emit a property using its exact compiled name.
- Emit its completed scalar text as a JSON string.
- Preserve empty text as an empty JSON string.
- Do not infer JSON Boolean, number, or null types from scalar spelling;
  NexusScript core scalar values are text.
- A scalar originally produced by a literal, reference, or text composition is
  emitted identically. The emitter does not inspect how it was produced.

### Arrays

- Emit a compiled array as an ordered JSON array.
- Emit an unnamed scalar entry as a JSON string.
- Emit a named scalar entry as `{ "Name": name, "Value": text }`.
- Emit an inline or referenced definition-valued entry as the ordinary
  definition object described above.
- Use the entry's compiled effective local name as the object's `Name`.
- Emit mixed arrays item by item without imposing validator rules.

The emitter does not distinguish literal arrays from arrays completed through
references or composition. It writes the compiled array content it receives.

### Structural property values

When a compiled property value contains a structural definition, emit that
definition object directly as the property's value. The property name already
supplies the surrounding JSON member name, so do not group the value again by
kind and do not wrap it in reference metadata.

For example, a compiled structural property named `Alias` is emitted as:

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

The emitter does not know whether the structure originated inline, through a
reference, or through composition.

### Source and provenance metadata

Do not remove source/provenance information from the compiled model. This work
does not define which metadata, if any, appears in JSON or how it is named.

The initial emitter writes the effective declarative content above. A later,
explicit design can expose selected metadata to Mustache without changing the
compiled-tree boundary.

### JSON member collisions

Add focused tests for actual compiled documents containing a property named
`Name` or a property whose name matches a child-kind collection.

If the current language and compiled tree permit two effective members that
cannot both be represented by the direct JSON contract, stop and return the
minimal example for a contract decision. Do not silently rename members, add
wrapper objects, or turn this into compiler work.

## JSON Emitter

Add:

```text
NexusTools/Script/src/obNexusScriptJSON.pas
```

Expose one narrow operation accepting the ordered existing artifact documents
and returning JSON text. Keep recursive traversal helpers private.

Use `fpjson` for JSON ownership, strings, arrays, objects, escaping, and
formatting. Build the owned JSON value tree completely before serializing it to
text.

The unit may depend on the existing compiled model types and session artifact
record/list type needed by its input. It must not depend on the compiler
implementation, source parser, validator, CLI, NexusSchema, metadata units,
Mustache, or any domain vocabulary.

## CLI Integration

Modify `NexusTools/Script/cli/obNexusScriptCommand.pas` so it:

1. compiles the input once using the existing session;
2. optionally validates only when `/validate` is supplied;
3. passes the existing `ArtifactDocuments` to the JSON emitter once;
4. emits that JSON directly when neither rendering option is supplied;
5. gives that same JSON string to the existing `/template` operation;
6. gives that same JSON string to every existing `/manifest` render.

Preserve existing stdout/file behavior and the established single-template and
NexusManifest rendering operations after the JSON string is produced.

## Remove the Incorrect Schema-Specific Path

Delete:

```text
NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas
```

Remove from the NexusScript executable and generic artifact tests:

- `TNexusScriptSchemaConsumer`;
- `TMetaDataModuleList`;
- `TMetaDataTransform`;
- `MetaDataToMustacheJSON`;
- all NexusSchema-specific interpretation.

Delete `TestSchemaConsumer` and the metadata-producing `LoadNexusScript`
helper. The generic CLI must not compile through a Schema-specific path.

Remove the inForce and Storm assertions from the generic JSON acceptance suite
because they test legacy Schema metadata output, not mechanical compiled-tree
emission. Record that legacy Schema artifact parity is deferred; do not replace
it with a weakened or Schema-shaped generic test.

## Tests

Compile small domain-neutral NexusScript fixtures, pass their existing compiled
artifact documents directly to the emitter, and verify:

- multiple root definitions grouped by exact kind;
- definition and child order;
- exact definition and property names;
- scalar and empty-string values;
- JSON escaping and Unicode;
- nested child definitions grouped recursively by exact kind;
- unnamed and named scalar array entries;
- inline and referenced definition-valued array entries;
- effective local-name overrides;
- structural property values;
- mixed arrays;
- composed/inherited definitions emitted from their compiled content;
- referenced and text-composed scalars emitted as ordinary strings;
- whole-array reference results emitted as ordinary arrays;
- module-resolved content emitted without module interpretation;
- included artifact documents appended in session order;
- actual collision behavior for `Name` and child-kind member names.

Assertions must be against JSON output. Do not construct a substitute compiled
model and do not add conversion/finalization tests.

Use a small generic Mustache template against the emitted JSON and verify raw
JSON, `/template`, and every `/manifest` entry receive the same JSON artifact.
Preserve existing CLI validation and NexusManifest behavioral coverage.

Schema-specific output is outside this work.

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
- affected domain-neutral CLI and manifest fixtures
- `NexusTools/Script/parity/PARITY.md`
- superseded JSON-output sections of
  `work/plans/nexusscript-command-line-interface.md`
- superseded JSON-input sections of
  `work/plans/nexusscript-template-manifest-rendering.md`

### Delete

- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`

Do not modify `obNexusScriptModel.pas`, `obNexusScriptCompiler.pas`,
`obNexusScriptSession.pas`, NexusScript syntax, validators, NexusSchema
production code, legacy Schema sources, or production Mustache templates as
part of this work.

## Ordered Implementation Stages

1. Add domain-neutral fixtures and expected JSON for the direct mapping.
2. Implement `obNexusScriptJSON.pas` against the existing compiled model.
3. Cover scalars, arrays, structural values, nested definitions, artifact
   ordering, and escaping with focused output tests.
4. Confirm references, composition, projection, modules, and includes require
   no emitter-specific behavior by checking only their compiled JSON output.
5. Replace the CLI's Schema metadata conversion with one JSON-emitter call.
6. Verify raw, `/template`, and `/manifest` reuse the same JSON string.
7. Delete the Schema consumer and remove its NexusSchema metadata dependencies.
8. Remove/defer invalid Schema parity assertions and correct documentation and
   superseded plan sections.
9. Clean-build, run the full NexusScript suite, perform focused dependency
   searches, and create the standard full-source archive.

Compile after stages 2, 5, and 7.

## Verification

Run clean builds of `NexusScript.lpi` and `NexusScriptTestModule.lpi`, followed
by the complete registered NexusScript suite.

Focused searches must prove:

- `TNexusScriptSchemaConsumer` no longer exists;
- the CLI and JSON emitter have no `obMetaData*` or NexusSchema dependency;
- the JSON emitter contains no Schema-domain vocabulary or kind/property
  dispatch;
- no `TNexusScriptEffective*` or other replacement model was introduced;
- no projection, finalization, normalization, or consumer layer sits between
  `TNexusScriptCompiledDocument` and JSON emission;
- raw, `/template`, and `/manifest` reuse one emitted JSON string;
- tests exercise the existing compiled tree directly.

After approved implementation, run `scripts/New-NexusSourceArchive.ps1` and
verify the JSON emitter is present and the Schema consumer is absent.

## Stop Conditions

Stop and return a concrete, minimal compiled example if:

- a valid compiled node cannot be mechanically emitted from its existing
  effective content;
- a legal compiled object produces an unavoidable JSON member collision;
- correct emission would require validator, doctype, filename, or domain
  knowledge;
- a proposed fix would require changing the compiled model or compiler;
- source/provenance JSON becomes necessary to complete this initial emitter.

Do not solve a stop condition by adding an intermediate tree or moving compiler
behavior into the emitter.

## Non-Goals

- No compiled-model or compiler correction without a demonstrated defect and
  separate approval.
- No Schema interpretation or legacy Schema JSON reconstruction.
- No reference, inheritance, composition, projection, or materialization work
  in the emitter.
- No validator involvement.
- No source/provenance JSON design in this pass.
- No consumer, adapter, plugin, registry, or alternate-model architecture.
- No alternate JSON modes or derived domain fields.
- No unrelated language, validation, CLI, or NexusManifest changes.

## Sub-Agent Plan

No delegation is requested. The emitter, CLI replacement, tests, and removal of
the incorrect Schema path form one narrow integration seam, and the worktree
contains overlapping uncommitted NexusScript changes.
