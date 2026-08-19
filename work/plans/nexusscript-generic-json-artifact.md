# Work Plan: Generic NexusScript JSON Emitter

## Inputs

- Source request: the human owner requested a generic NexusScript JSON emitter
  whose output can be consumed by Mustache templates in the same manner as the
  NexusSchema JSON context.
- Current NexusScript compiled model, compilation session, CLI artifact path,
  Mustache rendering path, project files, tests, and README.
- NexusSchema's `obMetaDataJSON.pas` as the existing repository example of
  building a Mustache-friendly JSON context with `fpjson`.
- Repository architecture-change protocol, NexusScript folder instructions,
  and Pascal standards.

This is a work plan only. It does not authorize implementation, builds, tests,
program execution, archives, or changes outside this plan file.

## Summary

Add one domain-neutral JSON-emission boundary to NexusScript. It will translate
the already-compiled NexusScript artifact documents into a stable JSON context
that ordinary Mustache templates can traverse. Raw JSON output, `/template`,
and `/manifest` will all use that same emitted context.

The emitter will understand NexusScript's generic compiled structures only:
definitions, definition kinds and names, properties, scalar values, arrays,
and nested definitions. It will not contain Schema vocabulary or perform
compilation, resolution, composition, validation, transformation, or
domain-specific enrichment.

## Verified Findings

- `TNexusScriptCompiledDocument.Definitions` exposes compiled root definitions.
- `TNexusScriptCompiledDefinition` exposes `Kind`, `Name`, `Properties`, and
  `Children` in list order.
- `TNexusScriptCompiledProperty` exposes its exact `Name` and compiled `Value`.
- `TNexusScriptCompiledValue` represents text, arrays, references, text
  composition, and structural definitions, and retains the effective compiled
  text/name/structure needed by an output adapter.
- `TNexusScriptCompilationSession.ArtifactDocuments` supplies the entry and
  included artifact documents in deterministic entry-first order.
- The current CLI is not generic at the output boundary: it passes every
  artifact document through `TNexusScriptSchemaConsumer`,
  `TMetaDataTransform`, and `MetaDataToMustacheJSON` before raw or Mustache
  output.
- NexusSchema's JSON emitter uses `TJSONObject` and `TJSONArray` to expose
  named objects and ordered arrays suitable for `TSynMustache` traversal.
- NexusScript already produces one JSON string before choosing raw output,
  `/template`, or `/manifest`; this is the integration seam to replace.

## Architecture Problem

NexusScript's compiler is domain-neutral, but its artifact output is currently
coupled to the NexusSchema metadata model. A valid NexusScript document cannot
produce a useful JSON/Mustache context unless it can be interpreted as Schema
metadata. That prevents NexusScript from serving unrelated declarative
languages and templates.

The correction belongs at the output boundary. The compiler remains the owner
of language semantics, and a dedicated emitter becomes the owner of the
generic JSON representation.

## Target Contract

### Owner

Add `NexusTools/Script/src/obNexusScriptJSON.pas` as the sole owner of the
generic NexusScript-to-JSON mapping.

Its public operation accepts the session's ordered artifact-document list and
returns JSON text. Recursive JSON construction remains private to the unit.

### Responsibilities

The emitter will:

- traverse compiled artifact documents in their supplied order;
- group definitions by their exact NexusScript `Kind` for direct Mustache
  sections;
- preserve definition, property, child, and array order;
- expose each definition's effective name as `Name`;
- expose compiled properties as direct JSON members;
- recursively expose child definitions using the same exact-kind grouping;
- emit scalar values as JSON strings;
- emit array values as JSON arrays;
- use `fpjson` for ownership, escaping, Unicode, formatting, and serialization;
- reject unrepresentable member-name collisions with a focused error rather
  than silently overwrite or rename data.

The emitter will not:

- parse NexusScript source;
- resolve references or evaluate composition;
- invoke a validator or inspect a doctype;
- infer Boolean, numeric, or null types from NexusScript text;
- inspect filenames or definition names for domain meaning;
- derive Schema, SQL, Pascal, build, or manifest-specific fields;
- expose compiler source ranges, provenance, or internal resolution links;
- introduce a second compiled/effective document model.

### Mustache Context Shape

The root context is namespaced beneath `NexusScript`. Root definitions are
grouped into arrays named by exact definition kind. Definition properties are
direct members, and nested definitions repeat the same kind-array rule.

For example:

```nxscript
Project Example {
    Output: "build/example.exe";

    Target Win64 {
        Platform: win64;
    }
}
```

produces this context:

```json
{
  "NexusScript": {
    "Project": [
      {
        "Name": "Example",
        "Output": "build/example.exe",
        "Target": [
          {
            "Name": "Win64",
            "Platform": "win64"
          }
        ]
      }
    ]
  }
}
```

A template can therefore use ordinary Mustache sections and names:

```mustache
{{#NexusScript.Project}}
{{Name}} -> {{Output}}
{{#Target}}{{Name}}: {{Platform}}{{/Target}}
{{/NexusScript.Project}}
```

The emitter does not contain the words `Project`, `Target`, `Output`, or
`Platform`; those member names come from the compiled document.

### Value Mapping

- A completed scalar is emitted as its effective text.
- Empty text remains an empty JSON string.
- An unnamed scalar array item is emitted as a string.
- A named scalar array item is emitted as an object with `Name` and `Value`.
- A structural definition used as a value or array entry is emitted as a
  definition object using its effective local name.
- A compiled reference, text composition, whole-array reference, or composed
  definition is emitted from its completed value without provenance-specific
  wrappers.
- Mixed arrays retain their compiled item order and map each item according to
  its effective scalar or structural shape.

The contract reserves the synthetic `Name` member and the kind-derived members
used for child collections. Focused tests must establish current legal
collision cases. A collision is an emission error pending a separate language
or JSON-contract decision; the emitter must not invent aliases or wrapper
shapes during implementation.

### State Flow

```text
NexusScript source
    -> existing compiler/session
    -> ordered compiled artifact documents
    -> generic NexusScript JSON emitter
    -> raw JSON, one Mustache template, or manifest template entries
```

Compilation and optional validation still occur once. JSON is emitted once.
Every selected output mode consumes the same resulting JSON string.

## Scope

### Add

- `NexusTools/Script/src/obNexusScriptJSON.pas`
- domain-neutral JSON fixtures under
  `NexusTools/Script/tests/fixtures/json/`

### Modify

- `NexusTools/Script/NexusScript.lpi`
  - include the new emitter and remove production-only project references no
    longer required by the CLI artifact path.
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
  - replace Schema metadata conversion with one generic emitter call while
    preserving validation and output-mode behavior.
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`
  - include the emitter for focused tests.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - remove the Schema-producer and legacy Schema-artifact tests, then add
    direct emitter and CLI/Mustache integration coverage.
- `NexusTools/Script/README.md`
  - document the generic JSON contract and a minimal Mustache example.
- `NexusTools/Script/parity/PARITY.md`
  - remove claims that the Schema-specific producer is a NexusScript parity
    boundary or that its derived metadata JSON remains supported.

### Delete

- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`

Remove `TNexusScriptSchemaConsumer` and all associated source, project, CLI,
test, documentation, and dependency references. Do not retain, rename, move,
or replace it with a compatibility adapter.

## Out Of Scope

- NexusScript grammar, parsing, lookup, composition, projection, modules,
  includes, or compiler-model redesign;
- validator behavior or validator documents;
- NexusSchema production code, metadata transformations, or templates;
- Mustache engine changes;
- changes to `/template` or `/manifest` semantics beyond supplying the generic
  JSON context;
- provenance/debug JSON, alternative output modes, custom serializers, or
  domain-specific context enrichment;
- compatibility reconstruction of the old Schema-shaped JSON through the new
  generic emitter;
- unrelated README, fixture, validation, or plan cleanup.

## Staged Implementation Plan

### Stage 1: Lock the generic JSON contract with fixtures

- Add small domain-neutral inputs and exact expected JSON.
- Cover multiple root kinds, repeated kinds, nested definitions, properties,
  scalar arrays, named entries, structural values, and included documents.
- Add a minimal Mustache template that consumes the documented
  `NexusScript.<Kind>` structure.
- Add explicit collision fixtures so unsupported shapes fail visibly.

### Stage 2: Implement the emitter

- Add the narrow public emission operation.
- Build owned `fpjson` objects and arrays recursively from compiled values.
- Preserve supplied list order and exact source-defined member spelling.
- Raise focused errors for incomplete effective values or JSON member
  collisions rather than silently changing the contract.
- Compile NexusScript and its test module after the structural addition.

### Stage 3: Replace the CLI artifact boundary

- Remove Schema metadata conversion from the generic CLI execution path.
- Emit JSON once after compilation and optional validation.
- Preserve existing stdout/file writing, `/template`, and `/manifest` control
  flow so all three modes consume the identical emitted JSON string.
- Delete `obNexusScriptSchemaConsumer.pas`.
- Remove `TNexusScriptSchemaConsumer`, `TMetaDataModuleList`,
  `TMetaDataTransform`, `MetaDataToMustacheJSON`, and their NexusSchema unit
  dependencies from the NexusScript executable path.
- Remove `TestSchemaConsumer`, the inForce/Storm Schema-artifact assertions,
  and any test helper whose only purpose is producing the old derived Schema
  metadata JSON.
- Remove the deleted unit from both project files and correct `PARITY.md` so it
  no longer describes that producer as parity support.

### Stage 4: Complete tests and documentation

- Add exact JSON assertions for escaping, Unicode, empty strings, order,
  effective reference/composition results, arrays, structures, modules, and
  includes.
- Verify a generic Mustache template renders the expected artifact.
- Verify raw output, `/template`, and each `/manifest` render see the same
  context.
- Update the README with the stable context shape, value mapping, collision
  behavior, and example template.
- Remove only production dependencies proven unused after the CLI switch.

## Sub-Agent Delegation

No implementation delegation is proposed. The emitter contract, CLI switch,
Schema-producer deletion, project references, and tests form one small
integration seam, and the current worktree contains overlapping uncommitted
NexusScript CLI, test, README, validator, and fixture changes. Main Codex should
perform the approved work locally, preserving those changes and reviewing
every overlap before editing.

## Verification Plan

After implementation is explicitly approved:

- build `NexusTools/Script/NexusScript.lpi` with `lazbuild`;
- build `NexusTools/Script/tests/NexusScriptTestModule.lpi` with `lazbuild`;
- run the complete registered NexusScript suite through the established
  NexusTest host;
- run focused emitter, raw CLI, `/template`, and `/manifest` cases;
- parse emitted output as JSON before asserting its structure;
- compare order-sensitive arrays and Mustache output exactly;
- search the new emitter and generic CLI path for Schema metadata units,
  Schema vocabulary, validator calls, filename dispatch, and duplicated
  compiler logic;
- confirm `obNexusScriptSchemaConsumer.pas`, `TNexusScriptSchemaConsumer`, and
  every reference to them are absent from the repository;
- confirm the removed Schema-artifact tests and documentation claims are
  absent;
- confirm no replacement compiled/effective model was introduced;
- create the required fresh source archive with
  `scripts/New-NexusSourceArchive.ps1` and verify the new emitter and tests are
  present.

## Risks And Questions

- Mustache usability depends on the documented kind-grouped shape remaining
  stable; exact-output fixtures should be treated as the public contract.
- A source property named `Name`, or a property whose name matches a nested
  definition kind, collides with the direct Mustache-friendly representation.
  Implementation must report the concrete case rather than choose an
  unapproved aliasing rule.
- Existing derived Schema metadata output will not be reproduced by the
  domain-neutral emitter. Its producer and its output-specific tests are
  intentionally deleted; no compatibility path is retained.
- The worktree already contains overlapping NexusScript changes. Approved
  implementation must begin by reviewing those diffs and must not overwrite or
  stage unrelated work.

## Approval Gate

No implementation begins until the human owner explicitly authorizes this
plan. Approval is required before adding the emitter or fixtures, modifying
the CLI/project/tests/README, building, testing, running the archive script, or
performing implementation delegation.
