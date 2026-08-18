# Work Plan: NexusScript Manifest-Driven Multi-Template Rendering

## Inputs

- Human-owner request in conversation for a work plan only.
- Current NexusScript compiler, compilation session, doctype association,
  validator, CLI, Schema artifact conversion, and tests.
- Existing `obMustacheRenderer` file-based Mustache wrapper under
  `NexusTools/Schema/src`.
- Current NexusScript language contract and established path-only `doctype`
  syntax.
- Repository architecture-change protocol and Pascal standards.

This plan authorizes no implementation. It records the proposed architecture,
contract, migration-safe stages, verification, and decisions requiring review.

## Goal

Preserve the existing operation:

```text
one compiled input artifact + one Mustache template -> one output
```

as the rendering primitive, and add:

```text
one compiled input artifact + one validated NexusScript TemplateSet manifest
    -> several independent Mustache renders
    -> several files beneath one output directory
```

Every manifest entry renders against the exact same JSON artifact produced once
from the compiled input document. The manifest mechanism is generic: it knows
about template source paths, effective output paths, ordering, diagnostics, and
staged output writes, but nothing about Pascal, Schema vocabulary, source-code
units, or any other generated language.

## Current Behavior and Implementation Points

### CLI

`NexusTools/Script/cli/obNexusScriptCommand.pas` currently registers:

- required `/input=<file>`;
- optional `/output=<file>`, with stdout as the default;
- optional `/template=<file>`;
- optional flag-only `/validate`.

`TNexusScriptCommand.Execute` currently:

1. compiles the input through `TNexusScriptCompilationSession`;
2. optionally validates the entry document through its compiled doctype;
3. converts every artifact document through
   `TNexusScriptSchemaConsumer` into one metadata list;
4. applies the metadata transformation once;
5. produces the existing Mustache JSON once;
6. optionally renders one template;
7. writes one file or stdout.

No command-line mode names a Schema, consumer, JSON implementation, or output
language. This remains unchanged.

### Single-template rendering

The private `TNexusScriptCommand.RenderTemplate` method is the current reusable
operation in concept, but not yet in ownership. It writes JSON to a temporary
file, invokes `RenderMustacheFile`, and reads the rendered temporary output.

`NexusTools/Schema/src/obMustacheRenderer.pas` is a file-to-file wrapper around
`TSynMustache.TryRenderJson`. The side-by-side NexusScript folder instructions
prohibit changing NexusTools/Schema. The new work therefore wraps the existing
renderer from NexusScript rather than modifying Schema during this stage.

### Output writing

`TNexusScriptCommand.WriteOutput` creates parent directories and opens the
destination with `fmCreate`. That is adequate for one output but cannot satisfy
multi-output all-or-nothing behavior because a later render or write failure
could leave earlier files behind.

### Tests

`NexusTools/Script/tests/tsNexusScriptTests.pas` already covers:

- generated CLI help and invalid flags;
- JSON to stdout and file;
- one Mustache template to stdout and file;
- missing-template failure;
- optional input-doctype validation;
- exact Schema JSON and Mustache parity.

These tests are the compatibility baseline. Manifest coverage will extend them,
not replace them.

## Proposed Manifest Contract

### Standard validator

Promote the existing self-validator out of fixture storage:

```text
NexusTools/Script/validator/Validator.Validator.nxscript
```

Then add one maintained standard manifest validator beside it:

```text
NexusTools/Script/validator/TemplateSet.Validator.nxscript
```

It is ordinary NexusScript and associates with the standard self-validator:

```nxscript
doctype "Validator.Validator.nxscript";
```

Existing validator fixtures and documentation must be updated to refer to the
promoted file. Runtime-standard validators must not depend on a file whose
location describes it as test data.

The validator vocabulary is deliberately small:

- one root kind: `TemplateSet`;
- one entry kind: `Template`;
- `Template` definitions are direct ordered children of `TemplateSet`;
- zero or more `Template` children are valid;
- every `Template` requires effective-text `Source` and `Output` properties;
- auxiliary properties on `TemplateSet` are allowed so ordinary NexusScript
  references and text composition can calculate entry values;
- unknown properties and children on `Template` are rejected;
- unknown child definition kinds are rejected;
- `Template` entries are permitted only within a `TemplateSet`;
- no unrelated execution, language, encoding, or pipeline properties exist.

This uses ordinary named child definitions. A wrapper property would add no
meaning because the root has only one kind of child collection.

Conceptual validator shape:

```nxscript
doctype "Validator.Validator.nxscript";

Language TemplateSetManifest {
    UnknownDefinitions: Reject;
    Definitions: [
        Definition TemplateSet {
            Root: true;
            UnknownProperties: Allow;
            UnknownChildren: Reject;
            Children: [
                Child Templates { Kinds: [Template]; }
            ];
        },

        Definition Template {
            Parents: [TemplateSet];
            UnknownProperties: Reject;
            UnknownChildren: Reject;
            Properties: [
                Property Source {
                    Required: true;
                    Value Value { EffectiveCategories: [Text]; }
                },
                Property Output {
                    Required: true;
                    Value Value { EffectiveCategories: [Text]; }
                }
            ];
        }
    ];
}
```

The exact validator must be validated against
`Validator.Validator.nxscript`; the example above is direction, not permission
to bypass that verification.

### Example manifest

The request's illustrative named doctype form is no longer valid. With current
path-only doctype syntax and direct child definitions, the manifest is:

```nxscript
doctype "TemplateSet.Validator.nxscript";

TemplateSet PascalSchema {
    UnitName: SchemaTypes;

    Template Unit {
        Source: "pascal/schema-unit.mustache";
        Output: @PascalSchema.UnitName + ".pas";
    }

    Template Classes {
        Source: "pascal/schema-classes.mustache";
        Output: @PascalSchema.UnitName + "Classes.pas";
    }
}
```

Manifest modules, references, composition, and text composition work only as
already defined by NexusScript. This feature adds no manifest-specific reuse
syntax.

### Manifest interpretation

- The entry compiled manifest document must contain exactly one effective root
  `TemplateSet` for rendering.
- Entries execute in final compiled child-definition order.
- Each entry name is retained for diagnostics.
- `Source` and `Output` are read directly from their compiled `EffectiveText`.
- Dynamic paths use ordinary NexusScript references and text composition. The
  manifest runtime does not reinterpret either property as Mustache.
- Auxiliary `TemplateSet` properties have no manifest-specific meaning. They
  exist for normal NexusScript reference and composition semantics.
- Each template body is independently rendered against that same JSON.
- One entry always maps one source template to one output file.
- An empty `TemplateSet` succeeds and produces an empty output directory.

The generic NexusScript compiler and Validator remain unaware of these runtime
meanings.

## CLI Contract and Compatibility

Add one explicit option:

```text
/manifest=<TemplateSet manifest file>
```

### Existing modes remain unchanged

```text
NexusScript /input=Customer.Schema.nxscript
NexusScript /input=Customer.Schema.nxscript /output=Customer.json
NexusScript /input=Customer.Schema.nxscript /template=Unit.mustache
NexusScript /input=Customer.Schema.nxscript /template=Unit.mustache /output=Customer.pas
```

- No template and no manifest still emits the JSON artifact.
- `/template` still performs one render.
- Single-output `/output` remains optional and still defaults to stdout.
- `/validate` continues to control validation of the input document only.

### Manifest mode

```text
NexusScript /input=Customer.Schema.nxscript \
  /manifest=PascalSchema.TemplateSet.nxscript \
  /output=generated
```

Rules:

- `/manifest` and `/template` are mutually exclusive;
- manifest mode requires `/output`;
- in manifest mode `/output` means an output directory, not a file;
- stdout is not a multi-file destination;
- the manifest is always compiled and validated through its explicit doctype,
  independently of whether `/validate` was supplied for the input;
- `/validate` does not need a second value or a manifest-specific variant;
- no `/mode`, `/format`, `/consumer`, `/json`, language, or generator switch is
  introduced;
- there is no filename-extension inference between template and manifest mode.

Explicit `/manifest` selection is preferred because `/template` currently
accepts arbitrary Mustache filenames and NexusScript filename conventions are
decorative rather than semantic.

## Runtime Model

Add one small manifest-specific unit rather than a generic task/pipeline model:

```text
NexusTools/Script/cli/obNexusScriptTemplateManifest.pas
```

It owns:

- compilation and unconditional doctype validation of the manifest;
- locating the single `TemplateSet` root;
- reading its ordered direct `Template` children;
- resolving all source templates relative to the entry manifest file;
- reading and validating effective output paths;
- collecting per-entry rendered content before any final write;
- collision checks;
- staging the complete output tree and renaming it into place;
- entry-aware diagnostics.

Its internal item/list types should contain only data actually needed for one
render operation, such as:

- entry name and source range;
- declared and resolved template source path;
- effective relative output path;
- final canonical destination;
- rendered content.

Do not publish a generic graph, stage, processor, generator, or task API.

Add one rendering unit:

```text
NexusTools/Script/cli/obNexusScriptTemplateRenderer.pas
```

It extracts the existing single-template operation from
`TNexusScriptCommand`. It provides the primitive used by both CLI paths:

```text
Render one Mustache template against one JSON artifact and return text.
```

The initial implementation may preserve the current temporary-file bridge to
`RenderMustacheFile`. A direct `TSynMustache` text wrapper is acceptable only if
focused compatibility tests prove identical output and error behavior. Do not
modify `NexusTools/Schema` in this side-by-side stage.

## Rendering Flow

`TNexusScriptCommand.Execute` will retain one artifact-production path and then
branch only at the final output stage:

1. Compile the input document once.
2. Optionally validate the input document exactly as today.
3. Aggregate its artifact set, transform metadata, and produce JSON once.
4. If neither template option is supplied, write JSON exactly as today.
5. If `/template` is supplied, call the extracted one-template primitive and
   write one output exactly as today.
6. If `/manifest` is supplied:
   1. compile the manifest in a separate compilation session;
   2. require its doctype document;
   3. validate it with `TNexusScriptValidator`;
   4. normalize its one `TemplateSet` and ordered entries;
   5. require the requested output path not to exist;
   6. read and validate every compiled effective output path;
   7. resolve and preflight every template source;
   8. detect all destination collisions;
   9. render every template to memory or staging storage;
   10. only after all rendering succeeds, publish the complete output tree;
   11. return no artifact on stdout.

Manifest artifact documents are not passed through the Schema conversion. The
manifest session exists only to compile and validate the manifest itself.

## Path Resolution and Safety

### Template source paths

- Resolve every `Source` relative to the entry manifest file, regardless of
  whether the effective value originated locally or through composition.
- The manifest therefore has one obvious asset base. Module/property provenance
  does not alter filesystem interpretation.
- Canonicalize before loading.
- Missing or unreadable sources fail during preflight and identify the entry,
  declared source, and resolved source.
- A source template may be outside the manifest directory through explicit
  relative traversal; the containment restriction applies to generated
  outputs, not template inputs.

### Effective output paths

For each compiled `Output.EffectiveText` value:

1. reject empty or whitespace-only results;
2. reject rooted paths, drive-qualified paths, UNC paths, device paths, and
   leading directory separators;
3. normalize separators and dot segments;
4. reject any result that denotes a directory rather than a file;
5. combine it with the supplied output root;
6. canonicalize the combined destination;
7. require the destination to remain strictly beneath the canonical output
   root using a directory-boundary-aware comparison;
8. retain the effective value and source range for diagnostics.

The runtime must not validate containment using a string prefix alone.

### Collisions

Before rendering template bodies or creating final output files, reject:

- two entries producing the same canonical destination;
- destinations equivalent under the destination filesystem's path comparison;
- a file destination that is an ancestor of another destination, such as
  `Generated` and `Generated/Unit.pas`;
- any other preflight condition that makes the planned tree impossible.

Diagnostics name both conflicting manifest entries and both effective paths.

## Staged Output Behavior

Rendering failures must occur before any final output mutation. Therefore all
effective output-path validation, source loading, collision checks, and
template-body rendering complete first.

Manifest mode requires the requested output directory not to exist. Supporting
merge or replacement of an existing populated directory is deferred.

For final writes:

1. create a unique staging directory on the same filesystem as the output
   root;
2. write the complete planned relative tree beneath staging;
3. after every staged write succeeds, rename the completed staging directory to
   the requested output directory;
4. if rendering, staging, or rename fails, remove staging and leave the
   requested output path absent;
5. if cleanup itself fails, report the retained staging path explicitly.

Because staging and destination are siblings on the same filesystem, final
publication is one directory rename rather than a sequence of output-file
writes. An empty manifest stages and publishes an empty directory normally.

## Diagnostics

Errors must identify the narrowest relevant source:

- manifest compilation errors use normal NexusScript diagnostics;
- manifest-definition errors use Validator diagnostics and source ranges;
- root-count errors identify the manifest;
- entry errors name `TemplateSetName.TemplateEntryName`;
- source failures show declared and canonical template paths;
- output-path failures show the compiled effective value and source range;
- collisions identify both entries;
- Mustache failures identify the template body that failed;
- staging or final-rename failures identify the affected paths.

Do not catch and replace useful compiler/validator diagnostics with a generic
“manifest failed” message.

## Determinism

- Normalize entries in final compiled child-definition order.
- Read and validate compiled effective output paths in that order.
- Preflight and render template bodies in that order.
- Write staged files in that order.
- Report the first ordinary entry failure encountered in that order.
- Collision diagnostics use the later entry as primary and the earlier entry
  as related context.
- Do not enumerate compiler caches, directories, or hash maps to derive render
  order.

Parallel rendering is deferred. Deterministic sequential execution is the
initial contract.

## Exact Files to Add or Modify

### Add

- `NexusTools/Script/cli/obNexusScriptTemplateRenderer.pas`
  - reusable one-template Mustache rendering primitive.
- `NexusTools/Script/cli/obNexusScriptTemplateManifest.pas`
  - manifest compilation, validation, normalization, path checks, render plan,
    staging, final directory rename, and diagnostics.
- `NexusTools/Script/validator/Validator.Validator.nxscript`
  - promoted standard location of the existing self-validator.
- `NexusTools/Script/validator/TemplateSet.Validator.nxscript`
  - standard declarative manifest validator.
- `NexusTools/Script/tests/fixtures/manifest/Valid.TemplateSet.nxscript`
- `NexusTools/Script/tests/fixtures/manifest/Invalid*.nxscript`
- `NexusTools/Script/tests/fixtures/manifest/templates/*.mustache`
  - focused manifest, path-expression, collision, and rendering fixtures.

### Modify

- `NexusTools/Script/cli/obNexusScriptCommand.pas`
  - register `/manifest`, enforce option combinations, extract current render
    operation, and dispatch manifest rendering after producing JSON once.
- `NexusTools/Script/NexusScript.lpi`
  - register the two new units.
- `NexusTools/Script/tests/NexusScriptTestModule.lpi`
  - register new units if required by the test project.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - preserve current CLI assertions and add the focused tests below.
- `NexusTools/Script/validator/fixtures/Schema.nxscript`
  - update its doctype path to the promoted standard self-validator.
- `NexusTools/Script/validator/VALIDATION.md`
  - document the promoted standard validator location.
- `NexusTools/Script/README.md`
  - document single-template compatibility and manifest invocation.
- the authoritative NexusScript contract
  - add only the standard TemplateSet consumer/CLI contract if that document
    is intended to cover standard consumers; do not change core language
    syntax or semantics.

### Remove after promotion

- `NexusTools/Script/validator/fixtures/Validator.nxscript`
  - remove the fixture-path copy after all references use the standard
    `validator/Validator.Validator.nxscript` file; do not retain duplicate
    authoritative copies.

### Expected unchanged files

- `NexusTools/Script/src/obNexusScriptCompiler.pas`
- `NexusTools/Script/src/obNexusScriptModel.pas`
- `NexusTools/Script/src/obNexusScriptSession.pas`
- `NexusTools/Script/validator/obNexusScriptValidator.pas`
- `NexusTools/Schema/src/obMustacheRenderer.pas`
- `lib/dmustache/*`

If implementation proves one of these must change, stop and identify the exact
contract or capability gap before expanding scope.

## Test Plan

### Validator and manifest model

- `Validator.Validator.nxscript` validates itself from its standard location.
- Existing Schema/Customer validation passes through the promoted validator.
- `TemplateSet.Validator.nxscript` validates against the self-validator.
- A minimal one-entry manifest passes.
- Multiple direct child entries preserve order.
- Missing `Source` or `Output` fails.
- An empty `TemplateSet` passes.
- Auxiliary properties on `TemplateSet` pass and can participate in ordinary
  reference and text-composition resolution.
- Unknown child kinds and unknown properties on `Template` fail.
- Wrong-kind child entries fail.
- Illegal nested/root placement fails.
- More than one effective `TemplateSet` root is rejected by the manifest
  adapter.
- A manifest without an explicit doctype fails even if structurally similar.

### CLI compatibility

- All existing JSON and single-template tests pass unchanged.
- Help includes `/manifest` without adding removed mode flags.
- `/template` plus `/manifest` fails clearly.
- `/manifest` without `/output` fails clearly.
- Manifest mode writes nothing to stdout.
- `/validate` continues to affect only the input document.
- Manifest validation is mandatory without an additional flag.

### Rendering

- Every entry receives byte-identical JSON context.
- One-entry manifest output matches direct `/template` rendering exactly.
- Multiple templates produce expected independent contents.
- Output filenames resolve through ordinary NexusScript scalar references and
  text composition.
- `Source` and `Output` use their compiled `EffectiveText` values directly.
- Nested effective relative output paths create the expected directory tree.
- Entry order and write order are stable.
- Missing source, unreadable source, and invalid template-body Mustache identify
  the entry and leave no final files.
- An unresolved reference or invalid text composition fails during normal
  manifest compilation, before manifest runtime processing or final writes.
- Every source path uses the entry manifest directory even when its effective
  value came through composition.

### Path safety and collisions

- absolute drive path rejected;
- UNC/device path rejected on Windows;
- leading slash/backslash rejected;
- `..` traversal outside root rejected;
- normalization that remains beneath root accepted;
- empty effective path rejected;
- duplicate literal output rejected;
- duplicate outputs created by different NexusScript reference/composition
  expressions rejected;
- case-equivalent collision follows destination-filesystem semantics;
- file/descendant structural collision rejected;
- an already existing output directory is rejected before rendering.

### Staged output behavior

- render failure before commit leaves an absent output root absent.
- staging write failure leaves the requested output root absent.
- successful directory rename publishes the complete tree.
- an empty manifest publishes an empty directory.
- an existing output path fails without changing it.
- staging directories are removed after success or ordinary failure.

Use isolated temporary roots. Do not exercise failures in the real repository
or generated distribution directories.

## Ordered Implementation Stages

### Stage 1: Record the manifest and CLI contract

- Record direct ordered `Template` children and valid empty sets.
- Record `/manifest` and required directory-valued `/output`.
- Record the initially absent output-directory rule and
  destination-filesystem collision semantics.
- Add the concise contract/example to the approved documentation location.

Acceptance: no syntax or observable CLI question listed under Decisions remains
implicit.

### Stage 2: Add and self-validate the standard validator

- Promote `Validator.nxscript` from fixture storage to
  `validator/Validator.Validator.nxscript` and update references.
- Implement `TemplateSet.Validator.nxscript` using current validator vocabulary.
- Add positive and negative compilation/validation fixtures.
- Prove self-validation and subject validation through normal sessions.

Acceptance: the manifest structure is declarative and no hard-coded parser
duplicates it.

### Stage 3: Extract the single-render primitive

- Move the private one-template rendering behavior into the focused renderer
  unit.
- Route existing `/template` behavior through the extracted primitive without
  changing its CLI or bytes.

Acceptance: all existing single-template and parity tests remain exact.

### Stage 4: Compile and normalize manifests

- Compile a manifest in its own `TNexusScriptCompilationSession`.
- require and validate its doctype;
- locate exactly one `TemplateSet` root;
- normalize ordered direct child entries;
- read `Source` and `Output` directly from compiled `EffectiveText`;
- add entry-aware diagnostics.

Acceptance: manifest interpretation reads only compiled NexusScript and invokes
no Schema conversion or second parser.

### Stage 5: Implement preflight and rendering

- Resolve every source template relative to the entry manifest file.
- Validate each compiled effective output path without applying Mustache or any
  other second interpolation pass.
- enforce lexical and canonical output containment;
- detect duplicate and structural destination collisions;
- render every template through the one-render primitive before final writes.

Acceptance: every deterministic manifest/template/path failure occurs without
creating final output files.

### Stage 6: Implement staged directory publication

- Reject an existing output path before rendering.
- Write the complete tree beneath a same-filesystem sibling staging directory.
- Rename the completed staging directory to the requested output directory.
- Remove staging after ordinary failures and report a retained staging path if
  cleanup cannot complete.

Acceptance: success publishes the complete tree in one rename; failure leaves
the requested output path absent.

### Stage 7: Integrate the CLI

- Register `/manifest`.
- Enforce mutual exclusion and directory-output requirements.
- Produce JSON once and dispatch either raw output, one template, or a manifest.
- Keep diagnostics on stderr and stdout empty for manifest mode.
- Update help and README examples.

Acceptance: backward-compatible invocations remain byte-identical and manifest
mode generates the expected complete tree.

### Stage 8: Full verification and archive

- Clean-build NexusScript and its test module.
- Run the complete registered NexusScript suite.
- Run focused self-validator, manifest, CLI, path-safety, staged-output, and
  Schema parity tests.
- Search generic compiler/session/validator units for TemplateSet, Mustache,
  output-directory, Pascal, and manifest vocabulary leakage.
- Create the standard full Nexus source archive in the repository root and
  verify representative new files inside it.

## Deferred Capabilities and Non-Goals

- multiple rendering stages or pipelines;
- feeding one generated output into another template;
- per-entry data sources or alternate JSON contexts;
- per-entry validators or semantic consumers;
- conditional entries, target expressions, loops, or task graphs;
- parallel rendering or writing;
- merging into or replacing an existing output directory;
- directory-copy/static-file entries;
- executable hooks, callbacks, or post-processing commands;
- template discovery by filename extension;
- implicit manifest validator lookup by filename convention;
- absolute output destinations or opt-outs from containment;
- embedding multi-file behavior in Mustache;
- Mustache interpolation of manifest `Source` or `Output` values;
- Pascal-specific names, defaults, units, classes, or code-generation logic;
- changing NexusScript core syntax, dependency semantics, or ValueExpression;
- changing the Schema artifact representation as part of this feature;
- modifying NexusTools/Schema during side-by-side construction.

## Decisions Requiring Approval

The review direction resolves the original plan's manifest shape, empty-set,
path-base, collision, output-directory, and validator-location questions. One
observable choice remains for approval with the revised plan:

1. **CLI option:** approve `/manifest=<file>` as the explicit selector rather
   than overloading `/template` or inferring from filenames.

The revised plan otherwise specifies:

- direct ordered `Template` children;
- valid empty sets;
- all template sources relative to the entry manifest;
- destination-filesystem collision semantics;
- `/output` as a required directory only in manifest mode;
- rejection of any existing output path;
- promotion of the self-validator to a standard non-fixture location.

## Delegation

No sub-agent delegation is proposed. The initial work crosses one tight seam:
CLI compatibility, manifest normalization, path safety, and staged directory
publication must agree exactly. If implementation is later approved, isolated
fixture creation may be delegated only after the contract decisions above are
settled.

## Approval Gate

This plan stops before implementation. Direct human-owner authorization is
required before adding the validator or units, modifying the CLI, building,
running tests, creating fixtures, or producing an implementation archive.
