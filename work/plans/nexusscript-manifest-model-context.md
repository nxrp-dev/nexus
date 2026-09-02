# Work Plan: NexusScript Manifest-Owned Model Context

## Inputs

- Source request: the human owner's conversation request for a work plan that
  makes output constants independent of both the domain model and Mustache
  source, and lets a NexusScript manifest assemble those constants with the
  incoming model documents and templates.
- Related discussion:
  - `MODULE_POSTFIX`, `MODULE_ID_POSTFIX`, `GENERATOR_PREFIX`, and
    `NEXUS_SCHEMA_PRIMARY_KEY_TYPE` describe output policy rather than the
    inForce domain;
  - the manifestation layer consists of a manifest, independently compiled
    render models, and Mustache templates;
  - the manifest should own the complete render context instead of receiving
    an undeclared `/input` artifact produced before manifest execution;
  - output constants are ordinary compiled NexusScript data, not a new
    compiler-level constant mechanism;
  - all models in one manifest contribute to one generic JSON root, which is
    serialized once and supplied unchanged to every template;
  - successful compilation establishes structural validity for a document
    without a doctype, while `/validate` additionally applies any doctype the
    document actually declares;
  - manifest entries create neither compiler nor JSON namespaces: all emitted
    roots share one global context and must therefore be mutually unique.
- Current implementation:
  - `NexusTools/Script/cli/obNexusScriptCommand.pas`;
  - `NexusTools/Script/validator/NexusManifest.Language.nxscript`;
  - `NexusTools/Script/src/obNexusScriptSession.pas`;
  - `NexusTools/Script/src/obNexusScriptJSON.pas`;
  - `NexusTools/Script/tests/tsNexusScriptTests.pas`;
  - `NexusTools/Script/parity/schema-generation/`.
- Historical planning input:
  - `work/plans/nexusscript-template-manifest-rendering.md` defines the
    currently implemented template-only batching contract. This plan replaces
    that manifest-input boundary where the two conflict; it does not restore
    any discarded Schema producer or metadata conversion.
- Repository constraints:
  - keep the compiler and generic JSON emitter domain-neutral;
  - keep Schema- and Firebird-specific working material under
    `NexusTools/Script/parity/`;
  - do not modify the NexusSchema baseline under `NexusTools/Schema`;
  - do not add Mustache helpers, dictionary enumeration, JSON overlays, or a
    Schema-specific context adapter;
  - implementation requires separate direct approval after plan review.

## Summary

Evolve `NexusManifest` from a list of templates applied to an externally
compiled `/input` into the complete owner of a generation run. A manifest will
declare one or more independent `Model` children and one or more `Template`
children. Each `Model.Source` is compiled through an ordinary
`TNexusScriptCompilationSession`; all resulting artifact documents are passed
to the existing generic JSON emitter; the resulting JSON is produced once and
used unchanged by every template.

Move the four Firebird output settings out of the working inForce model into a
separate ordinary NexusScript constants document. The manifest will list both
the domain model and the constants document as models. Mustache templates will
read constants from the constants document's explicit root namespace.

This change establishes a clean manifestation boundary:

```text
NexusManifest
    -> domain Model source
    -> output-constants Model source
    -> Template sources and Output destinations
    -> compile every model independently
    -> combine completed artifact documents
    -> generic JSON serialization once
    -> render every template against that identical JSON
```

## Verified Findings

- `/input` is currently registered as universally required.
- `TNexusScriptCommand.Execute` currently compiles `/input`, optionally
  validates it, serializes its artifact documents, and only then calls
  `RenderManifest` with an already-finished JSON string.
- `RenderManifest` compiles and validates the manifest in a separate session.
  It can inspect only direct `Template` children and cannot add data to the
  JSON it receives.
- `NexusManifest.Language.nxscript` currently permits only `Template` children.
  Each template requires effective-text `Source` and `Output` properties.
- A source-level NexusScript `include` declared by the manifest affects the
  manifest compilation session, not the independently produced input JSON.
  It therefore cannot implement render-context composition under the current
  execution order.
- `TNexusScriptCompilationSession.ArtifactDocuments` already provides an
  ordered, include-aware artifact document set for one model source.
- Compilation of a canonical source is context-free under a stable filesystem:
  its doctype, module, and include dependencies are declared by that source and
  resolved relative to it, not supplied by the manifest entry that selected
  it.
- `TNexusScriptJSONEmitter.AddDocument` already combines completed compiled
  documents at the JSON root and rejects duplicate root names. No serializer
  change is needed to combine independent model and constants documents.
- The generic emitter has no Schema, Firebird, manifest, validation, or
  template knowledge. That boundary is correct and must remain unchanged.
- The working inForce model contains exactly four `Setting` children:
  `MODULE_POSTFIX`, `MODULE_ID_POSTFIX`, `GENERATOR_PREFIX`, and
  `NEXUS_SCHEMA_PRIMARY_KEY_TYPE`.
- The existing Firebird templates consume those values through the historical
  `NexusSchema.MetaData.Attributes` path.
- SynMustache already resolves explicit dotted root lookups from nested
  sections, so a namespace such as `Firebird.MODULE_POSTFIX` requires no
  renderer extension.
- The isolated `parity/schema-generation` workspace already contains working
  copies of the migrated inForce/Storm models and the three current Firebird
  Mustache templates. The NexusSchema originals remain unchanged.

## Architecture Problem

The current command has two different owners of one conceptual generation
operation:

- the command line supplies and compiles the data model through `/input`;
- the manifest supplies templates and destinations after the data model has
  already become JSON.

That split prevents a manifest from declaring the complete inputs needed to
reproduce a generation run. It also leaves no correct place for output-policy
data. Keeping the settings in the inForce model binds domain data to Firebird
conventions. Moving them into Mustache source binds configurable data to
formatting instructions. Textually injecting or overlaying JSON would bypass
the compiled NexusScript model and recreate an interpretation layer at the
wrong boundary.

The ownership correction is to make the manifest the assembler of independent
compiled render models. Domain data and output-policy data remain separate
documents and meet only in the generic serialized rendering context.

## Target Contract

### Ownership

- `NexusManifest` owns the complete declaration of a manifest generation run.
- A `Model` child owns one source path whose compiled artifact documents
  contribute to the rendering context.
- A `Template` child owns one Mustache source and one relative output path.
- Each model document owns its own NexusScript module, include, doctype,
  composition, and reference semantics.
- `TNexusScriptJSONEmitter` remains the sole serializer and mechanically joins
  completed artifact roots without knowing why a document was selected.
- Mustache consumes the resulting context; it does not define configuration
  values or mutate the context.

### Manifest language

Extend the manifest language with a direct child definition kind `Model`:

```nxscript
NexusManifest FirebirdBuild {
    Model Domain {
        Source: "../models/inForceMain.Schema.nxscript";
    }

    Model Constants {
        Source: "../constants/Firebird.Constants.nxscript";
    }

    Template DatabaseSchema {
        Source: "../mustache/DatabaseSchema.create.mustache";
        Output: "DatabaseSchema.sql";
    }
}
```

The manifest contract is:

- exactly one root definition of kind `NexusManifest`;
- at least one direct `Model` child;
- at least one direct `Template` child;
- no other child kinds;
- every `Model` requires `Source` with completed effective text;
- every `Template` retains required completed effective-text `Source` and
  `Output` properties;
- auxiliary properties remain permitted on the root and entries so ordinary
  NexusScript references and text composition can build paths;
- child order is retained for diagnostics and template rendering, but model
  order does not define overriding or precedence.

The `Model` child's NexusScript name is a manifest-entry identity used in
diagnostics. It does not rename, wrap, alias, or otherwise alter roots emitted
by its source document. The manifest introduces no compiler namespace and no
JSON namespace. Every root emitted by every selected artifact document enters
one global JSON object, so all root names must be mutually unique across the
entire manifest context.

### Constants model

Add an ordinary NexusScript document under the isolated working area:

```nxscript
Constants Firebird {
    MODULE_POSTFIX: "_TBL";
    MODULE_ID_POSTFIX: "_ID";
    GENERATOR_PREFIX: "GEN_";
    NEXUS_SCHEMA_PRIMARY_KEY_TYPE: "DOM_INDEX";
}
```

The kind `Constants` has no compiler-specific meaning. Its scalar properties
are normal completed NexusScript values and serialize under one explicit root:

```json
{
  "Firebird": {
    "_nx": {
      "Kind": "Constants",
      "Name": "Firebird"
    },
    "MODULE_POSTFIX": "_TBL"
  }
}
```

The initial implementation adds no constant inheritance, environment overlay,
command-line substitution, or last-writer-wins behavior. A future variant may
use ordinary NexusScript modules and composition inside its own constants
source and still emit one final `Firebird` root.

### Manifest-mode CLI

Manifest mode becomes self-contained:

```text
NexusScript /manifest=Firebird.NexusManifest.nxscript /output=generated
```

Rules:

- `/input` is required for raw JSON and single `/template` modes;
- `/input` is not required in `/manifest` mode;
- supplying both `/input` and `/manifest` is rejected so a manifest cannot
  have undeclared context;
- `/template` and `/manifest` remain mutually exclusive;
- `/manifest` continues to require `/output` as its output base directory;
- the manifest is always compiled and validated through its explicit doctype;
- successful compilation is sufficient structural validation for an ordinary
  input or manifest model that declares no doctype;
- in raw and single-template modes, `/validate` applies the ordinary `/input`'s
  declared doctype when one exists and does not reject a successfully compiled
  input merely because it has no doctype;
- in manifest mode, `/validate` applies the same rule to every declared
  `Model`: validate through its doctype when one exists; otherwise successful
  compilation is sufficient. Any model validation failure uses the
  `NexusManifestName.ModelName` identity;
- without `/validate`, model documents compile normally and their doctype
  documents remain compilation dependencies without automatic subject
  validation, matching ordinary input behavior.

Registration must therefore make `/input` syntactically optional and enforce
the mode-dependent requirement explicitly in `Execute`.

### Model compilation and context assembly

For manifest mode:

1. Compile and validate the manifest before compiling any model or writing any
   output.
2. Locate its single `NexusManifest` root and separate direct `Model` and
   `Template` children by compiled `Kind` while preserving child order.
3. Resolve every `Model.Source.EffectiveText` relative to the manifest file.
4. Enforce one canonical-source invariant: a canonical artifact source file
   contributes at most one artifact document to the final context. Declaring
   the same canonical `Model.Source` directly more than once is additionally a
   manifest configuration error reported against the later entry.
5. Compile every model in its own `TNexusScriptCompilationSession` so model
   namespaces and dependency semantics remain independent.
6. Retain every session until serialization is complete because sessions own
   their compiled documents.
7. If `/validate` is present, validate each entry compiler document through
   its declared doctype when present; accept successful compilation as
   sufficient when the entry document has no doctype.
8. Traverse each session's ordered `ArtifactDocuments` and enforce the same
   canonical-source invariant. When the same canonical artifact source is
   reached transitively from more than one declared model, contribute it once.
   Do not deduplicate different files that happen to declare the same root
   name; those remain a root collision.
9. Add each selected compiled document to one
   `TNexusScriptJSONEmitter`. Existing duplicate-root rejection remains the
   only root collision rule.
10. Serialize once after every model has compiled and validated successfully.
11. Render every `Template` child against that exact JSON string using current
    sequential write and failure behavior.

No model can reference definitions in another manifest `Model` merely because
both appear in the manifest. Cross-document language references still require
ordinary NexusScript `module` declarations inside the model source. A manifest
assembles render context; it does not create a compiler namespace, alias, root
wrapper, or per-model JSON scope.

### Paths and failures

- `Model.Source` and `Template.Source` resolve relative to the manifest file.
- `Template.Output` retains the current safe-relative-path rules beneath the
  `/output` base.
- All manifests and models compile before any template output is written.
- Model compilation, optional validation, duplicate source, or root collision
  failures therefore produce no partial outputs.
- Template rendering and writing retain current ordered, stop-on-first-failure
  behavior; outputs successfully written by earlier templates are not rolled
  back.
- Every model failure is wrapped with
  `NexusManifestName.ModelEntryName`; every template failure retains
  `NexusManifestName.TemplateEntryName`.

### Source `include` versus manifest `Model`

The two relationships remain deliberately distinct:

- source `include` means a document is intrinsically part of that model's
  artifact set;
- manifest `Model` means an independent model participates in one particular
  rendering operation.

The Firebird constants document must not be included by the inForce or Storm
domain model. It joins them only through the manifest.

## Scope

### Add

- `NexusTools/Script/parity/schema-generation/constants/Firebird.Constants.nxscript`
  - working output-policy model containing the four extracted settings.
- `NexusTools/Script/parity/schema-generation/manifests/`
  - self-contained working manifests for the inForce and Storm Firebird
    generation contexts, limited to templates whose required domain context is
    currently represented.
- focused manifest-model and constants fixtures under
  `NexusTools/Script/tests/fixtures/manifest/`.

### Modify

- `NexusTools/Script/validator/NexusManifest.Language.nxscript`
  - add the `Model` definition and require at least one `Model` and one
    `Template` child.
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
  - make command requirements mode-dependent;
  - replace the JSON-consuming `RenderManifest` boundary with a self-contained
    manifest execution path;
  - compile model entries, assemble artifact documents, serialize once, and
    render templates;
  - retain current path safety and entry-aware failures.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - replace template-only manifest assumptions and add the focused coverage
    below.
- existing manifest fixtures whose invocations currently rely on `/input`.
- `NexusTools/Script/README.md`
  - document self-contained manifest mode, model independence, constants
    context, validation behavior, and CLI compatibility rules.
- `NexusTools/Script/parity/schema-generation/README.md`
  - document the new `constants/` and `manifests/` ownership.
- `NexusTools/Script/parity/schema-generation/models/inForceMain.Schema.nxscript`
  - remove the four output-policy `Setting` children from the working copy
    only.
- working Mustache copies under
  `NexusTools/Script/parity/schema-generation/mustache/`
  - replace historical constant lookups with the explicit `Firebird` constants
    namespace where those constants are consumed.

### Expected unchanged

- `NexusTools/Script/src/obNexusScriptCompiler.pas`;
- `NexusTools/Script/src/obNexusScriptModel.pas`;
- `NexusTools/Script/src/obNexusScriptSession.pas`;
- `NexusTools/Script/src/obNexusScriptJSON.pas`;
- `NexusTools/Script/validator/obNexusScriptValidator.pas`;
- `NexusTools/Schema/**`;
- `lib/dmustache/**`.

If implementation demonstrates that one of these must change, stop and report
the exact missing facility before expanding the approved scope.

## Out Of Scope

- Restoring `TNexusScriptSchemaConsumer`, `TMetaDataTransform`, or any metadata
  conversion path.
- Teaching the generic emitter about constants, manifests, Firebird, Schema,
  templates, precedence, or merging.
- Adding a language-level `const` declaration or special constant evaluation.
- Letting constants participate in domain-model reference resolution merely
  because the manifest lists both documents.
- JSON object overlays, recursive merges, root replacement, or precedence.
- Per-template model selection or per-template constant overrides. Use a
  separate manifest when a genuinely different context is required.
- Mustache partials, lambdas, helpers, dictionary enumeration, or renderer
  changes.
- Environment variables, secrets, command-line constant substitution, or
  runtime configuration services.
- Full NexusSchema SQL/output parity. This plan establishes the correct
  manifestation boundary and moves the known output constants; remaining
  domain-shape and transformation replacement work must be evaluated against
  the real templates separately.
- Modifying the original migrated parity fixtures under
  `parity/fixtures/nexusscript/` or any NexusSchema baseline source/template.
- Compatibility behavior that keeps the old `/input` plus `/manifest`
  invocation alive. No verified external integration currently requires it.

## Staged Implementation Plan

### Stage 0: Protect the interrupted worktree

- Record the current status and inspect diffs in every overlapping CLI,
  validator, test, README, fixture, and schema-generation file.
- Treat the generic JSON emitter, manifest batching work, validator naming
  changes, and isolated schema-generation copies as one interrupted body of
  user work that must be preserved.
- Do not reset, replace, or broadly reformat any unrelated modified plan or
  validator file.

### Stage 1: Extend and prove the manifest language

- Add `Model` to `NexusManifest.Language.nxscript` with required effective-text
  `Source`.
- Require at least one `Model` and one `Template` beneath the root.
- Preserve auxiliary-property support and reject unknown child kinds.
- Add validator fixtures for valid mixed child order, missing model, missing
  template, missing model source, wrong model placement, and unknown child
  kinds.
- Confirm the updated manifest language validates against the foundational
  `Language` definition before changing execution.

### Stage 2: Correct CLI ownership and execution order

- Make `/input` registration optional and enforce exact mode requirements in
  `Execute`.
- Keep raw JSON and single-template execution on the current input pipeline.
- Move manifest compilation/validation ahead of model compilation and JSON
  creation in manifest mode.
- Add small private manifest helpers or one narrowly owned manifest executor
  object only if that keeps session ownership and failure cleanup clearer than
  expanding `TNexusScriptCommand`. Do not create a general pipeline framework.
- Compile every declared model independently and retain its session.
- Implement the canonical-source invariant, including direct duplicate model
  rejection and transitive artifact-document deduplication.
- Apply the target `/validate` semantics consistently to raw input,
  single-template input, and every manifest model.
- Assemble one emitter, serialize once, and reuse the exact JSON string for all
  templates.
- Compile after the mode split and after session-ownership changes.

### Stage 3: Add the independent constants model

- Create `Firebird.Constants.nxscript` as an ordinary definition with four
  scalar properties and no special compiler behavior.
- Remove the four `Setting` children only from the isolated working inForce
  model.
- Add focused fixtures confirming the domain model and constants model compile in
  separate sessions, cannot reference one another implicitly, and appear as
  sibling root members in the emitted context.
- Confirm duplicate constant/domain root names fail instead of overriding.

### Stage 4: Convert the isolated manifestation workspace

- Add self-contained manifest files under `schema-generation/manifests/` that
  list the appropriate domain model and `Firebird.Constants.nxscript`.
- Preserve Storm's current module/include relationship with the working
  inForce model.
- Change only constant lookups in the working Mustache copies to the explicit
  `Firebird` root namespace.
- Do not claim that the copied production templates are otherwise compatible
  with the new domain JSON shape in this stage.
- Update the workspace and CLI documentation with the ownership distinction
  between domain models, output constants, templates, and manifests.

### Stage 5: Remove the obsolete manifest boundary

- Remove the `RenderManifest(const AJSON, ...)` API shape so no manifest path
  can receive prebuilt undeclared input JSON.
- Remove tests and documentation requiring `/input` with `/manifest`.
- Add focused searches confirming no manifest execution branch serializes input
  before compiling the manifest or uses an external artifact string as its
  context owner.

### Stage 6: Complete verification and archive

- Build the executable and test module.
- Run the complete NexusScript test suite.
- Run focused raw, single-template, manifest, constants, include, module,
  validation, collision, failure-order, and path-safety tests.
- Run the focused dependency and forbidden-mechanics searches below.
- Create a fresh Nexus source archive and verify it contains the updated plan,
  constants model, manifests, working templates, CLI, validator, and tests and
  excludes the deleted Schema producer.

## Sub-Agent Delegation

This plan does not authorize or recommend sub-agent use. Implementation remains
local unless the human owner explicitly requests sub-agent use in the current
conversation. Plan approval and implementation approval do not authorize delegation.

## Verification Plan

### Builds and suite

```text
lazbuild NexusTools\Script\NexusScript.lpi
lazbuild NexusTools\Script\tests\NexusScriptTestModule.lpi
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-suite NexusScript.Compiler
```

### Manifest language and CLI modes

- The manifest validator validates itself through its existing doctype.
- A manifest requires at least one valid `Model` and one valid `Template`.
- `Model.Source` and both template path properties must have effective text.
- Raw `/input` JSON behavior remains unchanged.
- `/input` plus `/template` behavior remains unchanged.
- `/manifest` plus `/output` succeeds without `/input`.
- `/manifest` plus `/input` fails clearly.
- `/manifest` plus `/template` fails clearly.
- raw or `/template` mode without `/input` fails clearly.
- `/manifest` without `/output` fails clearly.
- help accurately describes mode-dependent requirements.
- With `/validate`, a successfully compiled raw or single-template input that
  has no doctype succeeds.
- With `/validate`, a raw or single-template input that declares a doctype is
  validated against it and fails when it violates that contract.

### Model assembly

- Two independently compiled model documents contribute sibling root members
  to one JSON object.
- A domain model and constants model remain separate compiler namespaces.
- Modules and includes declared inside a model retain current semantics.
- The same transitively included canonical artifact document is emitted once.
- Duplicate direct model source entries fail with the second model identity.
- With `/validate`, a successfully compiled manifest model without a doctype
  contributes normally, while a model with a doctype must pass it.
- Different source files declaring the same root fail through existing emitter
  collision handling; neither value overrides the other.
- Model declaration order does not alter values or provide precedence.
- Model compilation and `/validate` failures identify the manifest and model
  entry and write no output files.

### Constants and Mustache

- `Firebird.Constants.nxscript` emits one `Firebird` object with `_nx`
  metadata and the four scalar string properties.
- The isolated domain model no longer emits the four setting definitions.
- A template can resolve `Firebird.MODULE_POSTFIX` from root while iterating a
  nested domain array.
- Every template entry receives the exact same serialized JSON string.
- Two manifests selecting different constants documents can render different
  values without changing the domain model or Mustache source; implement this
  as a focused fixture using complete alternative documents, not overlays.
- Templates contain no literal declarations of the four constants.

### Existing batching and paths

- Templates render and write in compiled child order even when `Model` and
  `Template` children are interleaved in source.
- Existing source-relative template paths and safe output-base checks pass.
- A later template failure leaves an earlier output intact.
- All model compilation and context assembly completes before the first output
  file is written.

### Focused searches

Use focused searches as sanity checks confirming that:

- `obNexusScriptJSON.pas` contains no manifest, constants, Schema, Firebird,
  path, template, or merge dispatch;
- `obNexusScriptCompiler.pas` and `obNexusScriptModel.pas` contain no manifest
  or constants special case;
- manifest execution no longer takes prebuilt JSON from `/input`;
- the working inForce model contains none of the four output settings;
- the four constant values occur in the constants model rather than working
  Mustache source;
- `NexusTools/Schema/**` and `lib/dmustache/**` have no changes;
- `TNexusScriptSchemaConsumer`, `TMetaDataTransform`, and
  `MetaDataToMustacheJSON` remain absent from the NexusScript executable path;
- no override, recursive merge, environment substitution, per-template model
  selection, or compatibility shim was introduced.

### Archive

Run:

```text
scripts\New-NexusSourceArchive.ps1
```

Verify representative entries with normalized ZIP separators, including:

- `NexusTools/Script/parity/schema-generation/constants/Firebird.Constants.nxscript`;
- the self-contained manifests;
- the updated working Mustache files and domain model;
- `NexusManifest.Language.nxscript`;
- CLI and test changes;
- this work plan.

Also verify the archive does not contain
`obNexusScriptSchemaConsumer.pas`.

## Risks And Questions

- The largest implementation risk is lifetime ownership across several
  `TNexusScriptCompilationSession` instances. Every session must remain alive
  until its compiled documents have been serialized, then be freed on all
  success and failure paths.
- Separate model sessions can reach the same artifact document transitively.
  The single canonical-source invariant must cover both direct declarations
  and transitive reachability without turning same-name roots from different
  files into silent aliases. This is valid because compilation of a canonical
  source has no manifest-entry-specific binding context under the current
  compiler contract.
- Making `/input` conditionally required changes command-line validation. The
  implementation must preserve exact error behavior for raw and single-template
  modes while deliberately rejecting the old mixed manifest invocation.
- The copied production templates still depend on other historical JSON fields
  and transformations. Moving constant paths is not evidence of complete SQL
  parity, and documentation/tests must not claim otherwise.
- `NEXUS_SCHEMA_PRIMARY_KEY_TYPE` was both emitted to templates and consumed by
  the old metadata transformation when resolving reference fields. Moving it
  correctly establishes output-policy ownership, but the eventual replacement
  for referenced-field type materialization belongs to the later SQL parity
  design, not to this manifest or constants implementation.
- Model-level validation in manifest mode is deliberately controlled by the
  existing `/validate` flag. Under that flag, a declared doctype is applied and
  the absence of a doctype is not itself an error because successful
  compilation already establishes structural validity. The same rule must
  apply to ordinary `/input` so validation semantics do not depend on CLI mode.
  If later builds require unconditional doctype validation, that should be an
  explicit contract revision rather than silently changing this plan during
  implementation.

No unresolved design question blocks implementation. The plan deliberately
chooses a self-contained manifest, manifest-wide shared context, strict
collision failure, independent model sessions, and no compatibility mode.

## Approval Gate

Creating, committing, and pushing this work-plan artifact does not authorize
implementation. No source, validator, CLI, fixture, build, test, archive, or
manifest behavior change begins until the human owner explicitly approves this
plan for implementation.
