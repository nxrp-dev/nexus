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
about template source paths, output path templates, ordering, diagnostics, and
transactional writes, but nothing about Pascal, Schema vocabulary, source-code
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

Add one maintained standard validator:

```text
NexusTools/Script/validator/TemplateSet.Validator.nxscript
```

It is ordinary NexusScript and associates with the existing self-validator:

```nxscript
doctype "fixtures/Validator.nxscript";
```

The relative path reflects the current repository location of the
self-validator. Moving standard validators out of `fixtures` is a separate
repository-layout decision and is not required for this feature.

The validator vocabulary is deliberately small:

- one root kind: `TemplateSet`;
- one entry kind: `Template`;
- `TemplateSet.Templates` is required;
- `Templates` is an ordered, named array of inline `Template` definitions;
- at least one template entry is required initially;
- every `Template` requires effective-text `Source` and `Output` properties;
- unknown definitions, properties, and children are rejected;
- `Template` entries are permitted only within a `TemplateSet`;
- no unrelated execution, language, encoding, or pipeline properties exist.

This uses the established NexusScript collection model rather than inventing a
dictionary or relying on direct-child definitions for an explicitly named
collection.

Conceptual validator shape:

```nxscript
doctype "fixtures/Validator.nxscript";

Language TemplateSetManifest {
    UnknownDefinitions: Reject;
    Definitions: [
        Definition TemplateSet {
            Root: true;
            UnknownProperties: Reject;
            UnknownChildren: Reject;
            Properties: [
                Property Templates {
                    Required: true;
                    Value Value {
                        EffectiveCategories: [Array];
                        Array Array {
                            Minimum: 1;
                            Names: Required;
                            EntryEffectiveCategories: [Definition];
                            DefinitionKinds: [Template];
                            Mixed: false;
                        }
                    }
                }
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

The exact validator must be validated against `Validator.nxscript`; the example
above is direction, not permission to bypass that verification.

### Example manifest

The request's illustrative named doctype form is no longer valid. The current
path-only syntax and named-array convention produce:

```nxscript
doctype "TemplateSet.Validator.nxscript";

TemplateSet PascalSchema {
    Templates: [
        Template Unit {
            Source: "pascal/schema-unit.mustache";
            Output: "{{UnitName}}.pas";
        },

        Template Classes {
            Source: "pascal/schema-classes.mustache";
            Output: "{{UnitName}}Classes.pas";
        }
    ];
}
```

Manifest modules, references, composition, and text composition work only as
already defined by NexusScript. This feature adds no manifest-specific reuse
syntax.

### Manifest interpretation

- The entry compiled manifest document must contain exactly one effective root
  `TemplateSet` for rendering.
- Entries execute in the final compiled `Templates` array order.
- Each entry name is retained for diagnostics.
- `Source` is an effective NexusScript text value. It is not itself rendered as
  Mustache during this initial feature.
- `Output` is first obtained as effective NexusScript text and then rendered as
  Mustache against the input artifact JSON.
- Each template body is independently rendered against that same JSON.
- One entry always maps one source template to one output file.

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
- reading ordered `Template` definitions from `Templates`;
- resolving source templates relative to the declaring manifest document;
- rendering and validating output paths;
- collecting per-entry rendered content before any final write;
- collision checks;
- staged transactional output commit;
- entry-aware diagnostics.

Its internal item/list types should contain only data actually needed for one
render operation, such as:

- entry name and source range;
- declared and resolved template source path;
- declared output expression and rendered relative output path;
- final canonical destination;
- rendered content;
- commit/rollback state while writing.

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

It also provides the corresponding render-from-text operation needed for an
`Output` expression, using the same Mustache engine and JSON. This is still one
render primitive with two input sources, not multi-file behavior inside
Mustache.

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
   5. render and validate every output path against the input JSON;
   6. resolve and preflight every template source;
   7. detect all destination collisions;
   8. render every template to memory or staging storage;
   9. only after all rendering succeeds, commit the complete output set;
   10. return no artifact on stdout.

Manifest artifact documents are not passed through the Schema conversion. The
manifest session exists only to compile and validate the manifest itself.

## Path Resolution and Safety

### Template source paths

- Resolve `Source` relative to the source document that declares the effective
  property, using retained NexusScript provenance.
- This matters when a manifest uses module composition: an inherited source
  path remains relative to its declaring module; a local override becomes
  relative to the overriding document.
- Canonicalize before loading.
- Missing or unreadable sources fail during preflight and identify the entry,
  declared source, and resolved source.
- A source template may be outside the manifest directory through explicit
  relative traversal; the containment restriction applies to generated
  outputs, not template inputs.

### Rendered output paths

For each `Output` expression:

1. render it through Mustache against the shared JSON;
2. reject empty or whitespace-only results;
3. reject rooted paths, drive-qualified paths, UNC paths, device paths, and
   leading directory separators;
4. normalize separators and dot segments;
5. reject any result that denotes a directory rather than a file;
6. combine it with the supplied output root;
7. canonicalize the combined destination;
8. require the destination to remain strictly beneath the canonical output
   root using a directory-boundary-aware comparison;
9. check existing ancestor links/reparse points so a lexically contained path
   cannot escape through the filesystem;
10. retain both declared and rendered values for diagnostics.

The runtime must not validate containment using a string prefix alone.

### Collisions

Before rendering template bodies or creating final output files, reject:

- two entries producing the same canonical destination;
- destinations equivalent under the destination filesystem's path comparison;
- a file destination that is an ancestor of another destination, such as
  `Generated` and `Generated/Unit.pas`;
- a destination colliding with an existing directory;
- any other preflight condition that makes the planned tree impossible.

Diagnostics name both conflicting manifest entries and both rendered paths.

## Transactional Output Behavior

Rendering failures must occur before any final output mutation. Therefore all
output path rendering, source loading, collision checks, and template-body
rendering complete first.

For final writes:

1. create a unique staging directory on the same filesystem as the output
   root;
2. write the complete planned relative tree beneath staging;
3. verify every staged file can be reopened and has the expected byte length;
4. if the output root does not exist, atomically rename the staged root into
   place;
5. if the output root exists, preserve unrelated files and use an operation
   journal:
   - move each existing destination to a same-filesystem backup tree;
   - move each staged file into its final location in deterministic order;
   - record every created directory and moved file;
   - on failure, reverse the journal, remove newly installed files, restore
     replaced files, and remove empty directories created by the operation;
6. delete backup and staging data only after successful commit;
7. report rollback failure separately and retain recovery paths if automatic
   restoration cannot complete.

This promises no partial generated set after an ordinary reported failure. It
does not claim simultaneous atomic visibility of several independent files to
other processes, which ordinary cross-file filesystem APIs cannot guarantee.

Existing files at declared destinations are replaced, matching current
single-output behavior, but unrelated files beneath an existing output
directory are untouched.

## Diagnostics

Errors must identify the narrowest relevant source:

- manifest compilation errors use normal NexusScript diagnostics;
- manifest-definition errors use Validator diagnostics and source ranges;
- root-count errors identify the manifest;
- entry errors name `TemplateSetName.TemplateEntryName`;
- source failures show declared and canonical template paths;
- output-expression failures show the declared expression and rendered result;
- collisions identify both entries;
- Mustache failures identify whether the template body or output expression
  failed;
- staging, commit, and rollback failures identify the affected paths.

Do not catch and replace useful compiler/validator diagnostics with a generic
“manifest failed” message.

## Determinism

- Normalize entries in final compiled array order.
- Render output expressions in that order.
- Preflight and render template bodies in that order.
- Stage and commit files in that order.
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
  - reusable one-template/text Mustache rendering primitive.
- `NexusTools/Script/cli/obNexusScriptTemplateManifest.pas`
  - manifest compilation, validation, normalization, path checks, render plan,
    staging, commit, rollback, and diagnostics.
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
- `NexusTools/Script/README.md`
  - document single-template compatibility and manifest invocation.
- the authoritative NexusScript contract
  - add only the standard TemplateSet consumer/CLI contract if that document
    is intended to cover standard consumers; do not change core language
    syntax or semantics.

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

- `TemplateSet.Validator.nxscript` validates against the self-validator.
- A minimal one-entry manifest passes.
- Multiple named entries preserve order.
- Missing `Templates`, `Source`, or `Output` fails.
- Empty `Templates` fails.
- Unknown kinds and properties fail.
- Unnamed, scalar, mixed, or wrong-kind entries fail.
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
- Output filenames interpolate scalar Mustache values.
- Nested rendered relative output paths create the expected directory tree.
- Entry order and write order are stable.
- Missing source, unreadable source, invalid Mustache, and output-expression
  failure identify the entry and leave no final files.

### Path safety and collisions

- absolute drive path rejected;
- UNC/device path rejected on Windows;
- leading slash/backslash rejected;
- `..` traversal outside root rejected;
- normalization that remains beneath root accepted;
- empty rendered path rejected;
- duplicate literal output rejected;
- duplicate outputs created by different Mustache expressions rejected;
- case-equivalent collision tested according to approved comparison policy;
- file/descendant structural collision rejected;
- existing-directory collision rejected;
- existing symlink/reparse-point escape rejected.

### Transaction behavior

- render failure before commit leaves an absent output root absent.
- render failure leaves an existing output tree byte-for-byte unchanged.
- staging write failure leaves final outputs unchanged.
- commit failure after one or more moves restores replaced files and removes
  newly created files.
- successful commit replaces declared existing files and preserves unrelated
  files.
- staging and backup directories are removed after success.
- forced rollback failure reports recovery paths rather than deleting evidence.

Use isolated temporary roots and deterministic failure injection around the
manifest writer. Do not simulate transaction failures by writing into the real
repository or generated distribution directories.

## Ordered Implementation Stages

### Stage 1: Approve the manifest and CLI contract

- Confirm the `Templates` named-array shape.
- Confirm `/manifest` and required directory-valued `/output`.
- Confirm overwrite and collision comparison policies.
- Add the concise contract/example to the approved documentation location.

Acceptance: no syntax or observable CLI question listed under Decisions remains
implicit.

### Stage 2: Add and self-validate the standard validator

- Implement `TemplateSet.Validator.nxscript` using current validator vocabulary.
- Add positive and negative compilation/validation fixtures.
- Prove self-validation and subject validation through normal sessions.

Acceptance: the manifest structure is declarative and no hard-coded parser
duplicates it.

### Stage 3: Extract the single-render primitive

- Move the private one-template rendering behavior into the focused renderer
  unit.
- Add render-from-text for output expressions through the same Mustache engine.
- Route existing `/template` behavior through the extracted primitive without
  changing its CLI or bytes.

Acceptance: all existing single-template and parity tests remain exact.

### Stage 4: Compile and normalize manifests

- Compile a manifest in its own `TNexusScriptCompilationSession`.
- require and validate its doctype;
- locate exactly one `TemplateSet` root;
- normalize ordered entries and retained source provenance;
- add entry-aware diagnostics.

Acceptance: manifest interpretation reads only compiled NexusScript and invokes
no Schema conversion or second parser.

### Stage 5: Implement preflight and rendering

- Resolve source templates relative to effective declaration provenance.
- Render output expressions against the shared JSON.
- enforce output containment and filesystem-link checks;
- detect duplicate and structural destination collisions;
- render every template through the one-render primitive before final writes.

Acceptance: every deterministic manifest/template/path failure occurs without
creating final output files.

### Stage 6: Implement staged transactional commit

- Write and verify the complete staging tree.
- Add absent-root atomic rename.
- Add existing-root backup journal, ordered commit, and reverse rollback.
- Add deterministic failure injection and cleanup tests.

Acceptance: ordinary reported failures leave no partial generated set and no
silent loss of pre-existing destination files.

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
- Run focused self-validator, manifest, CLI, path-safety, transaction, and
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
- directory-copy/static-file entries;
- executable hooks, callbacks, or post-processing commands;
- template discovery by filename extension;
- implicit manifest validator lookup by filename convention;
- absolute output destinations or opt-outs from containment;
- embedding multi-file behavior in Mustache;
- Pascal-specific names, defaults, units, classes, or code-generation logic;
- changing NexusScript core syntax, dependency semantics, or ValueExpression;
- changing the Schema artifact representation as part of this feature;
- modifying NexusTools/Schema during side-by-side construction.

## Decisions Requiring Approval

1. **CLI option:** approve `/manifest=<file>` as the explicit selector rather
   than overloading `/template` or inferring from filenames.
2. **Manifest shape:** approve `TemplateSet.Templates` as a required named array
   of `Template` definitions rather than direct child definitions.
3. **Empty sets:** approve requiring at least one entry. Allowing an empty set
   is harmless but has no demonstrated initial use.
4. **Existing destinations:** approve replacing only files declared by the
   manifest while preserving unrelated files, matching current single-output
   overwrite behavior.
5. **Collision comparison:** choose always-case-insensitive comparison for
   portable manifests, or destination-filesystem semantics. The proposed
   implementation default is destination-filesystem semantics, with Windows
   comparisons case-insensitive.
6. **Output directory identity:** confirm `/output` is interpreted as a
   directory only when `/manifest` is present; its existing file meaning remains
   untouched in other modes.
7. **Standard validator location:** approve keeping
   `TemplateSet.Validator.nxscript` under `NexusTools/Script/validator` while it
   refers to the current self-validator under `validator/fixtures`, or separately
   promote standard validators out of fixture storage before implementation.

No implementation should begin until these observable choices are approved.

## Delegation

No sub-agent delegation is proposed. The initial work crosses one tight seam:
CLI compatibility, manifest normalization, path security, and transactional
writing must agree exactly. If implementation is later approved, isolated
fixture creation may be delegated only after the contract decisions above are
settled.

## Approval Gate

This plan stops before implementation. Direct human-owner authorization is
required before adding the validator or units, modifying the CLI, building,
running tests, creating fixtures, or producing an implementation archive.
