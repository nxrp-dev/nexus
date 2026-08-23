# Work Plan: NexusScript Template Manifest Batching

## Inputs and Authorization

- Human-owner request in conversation to discard the previous manifest plan and
  produce a narrower work plan only.
- Current NexusScript CLI, compilation session, compiled model, validator,
  Mustache renderer, and registered tests.
- Repository architecture-change protocol and Pascal standards.

This plan authorizes no implementation, build, test run, archive, or unrelated
repository change. It replaces the previous manifest-rendering design in full.

## Goal

Keep the existing operation unchanged:

```text
compiled input + one Mustache template -> one output
```

Add only a batching layer:

```text
compiled input + one NexusScript NexusManifest manifest
    -> invoke the existing single-template operation once per Template entry
```

The input document is compiled once and its existing JSON artifact is produced
once. Every manifest entry receives that same JSON. The manifest contains no
pipeline, generation-language, validator-domain, or artifact-domain behavior.

## Verified Current Implementation

`NexusTools/Script/cli/obNexusScriptCommand.pas` already contains both
operations needed by each manifest entry:

- `TNexusScriptCommand.RenderTemplate` renders one Mustache file against one
  JSON string and returns the rendered text;
- `TNexusScriptCommand.WriteOutput` creates the output file's parent
  directories and writes or replaces that one file.

`TNexusScriptCommand.Execute` already compiles the input, optionally validates
it, converts the compiled artifact documents through the current Schema
artifact path, transforms the metadata, and calls `MetaDataToMustacheJSON`
exactly once before the final output decision. Manifest mode branches only
after that JSON has been produced.

The existing compiled model already supplies the manifest data needed:

- `TNexusScriptCompiledDocument.Definitions` preserves compiled root order;
- `TNexusScriptCompiledDefinition.Children` preserves compiled child order;
- `FindProperty` locates `Source` and `Output`;
- `TNexusScriptCompiledProperty.Value.HasEffectiveText` and `EffectiveText`
  expose values after normal references, modules, composition, and text
  composition have been resolved.

`TNexusScriptCompilationSession` and `TNexusScriptValidator` already provide
normal manifest compilation and doctype validation. No compiler, model,
validator-engine, artifact, or Mustache-library change is required.

## Manifest Contract

### Structure

The manifest has exactly one root `NexusManifest`. It contains zero or more
direct child definitions of kind `Template`. Each `Template` requires:

- `Source`, whose compiled value has effective text;
- `Output`, whose compiled value has effective text.

Both `NexusManifest` and `Template` permit auxiliary properties. They have no
manifest-specific meaning; they exist so normal NexusScript references and text
composition can be used at either scope. Unknown child definition kinds are
rejected. A `Template` is valid only beneath `NexusManifest`.

Example:

```nxscript
doctype "NexusManifest.Language.nxscript";

NexusManifest GeneratedFiles {
    Template First {
        Source: "templates/first.mustache";
        Output: "generated/first.txt";
    }

    Template Second {
        BaseName: second;
        Source: "templates/second.mustache";
        Output: @BaseName + ".txt";
    }
}
```

The exact reference spelling is governed by the current NexusScript lookup
rules. The batching feature does not add or reinterpret expression syntax.

### Validator

Add:

```text
NexusTools/Script/validator/NexusManifest.Language.nxscript
```

It is an ordinary validator document using the existing validator vocabulary
and the existing self-validator at its current location. Its intended rules
are:

```nxscript
doctype "fixtures/Language.nxscript";

Language NexusManifest {
    UnknownDefinitions: Reject;
    Definitions: [
        Definition NexusManifest {
            Root: True;
            UnknownProperties: Allow;
            UnknownChildren: Reject;
            Children: [
                Child Templates { Kinds: [Template]; }
            ];
        },

        Definition Template {
            Parents: [NexusManifest];
            UnknownProperties: Allow;
            UnknownChildren: Reject;
            Properties: [
                Property Source {
                    Required: True;
                    Value Value { EffectiveCategories: [Text]; }
                },
                Property Output {
                    Required: True;
                    Value Value { EffectiveCategories: [Text]; }
                }
            ];
        }
    ];
}
```

The implementation must compile this validator and validate it against the
existing self-validator. Existing validators are not moved, renamed, copied,
or reorganized.

The validator establishes the minimal declarative shape. The CLI adapter also
requires exactly one compiled `NexusManifest` root and reports a focused error if
that runtime cardinality is not met.

## CLI Contract

Add:

```text
/manifest=<file>
```

Compatibility rules:

- `/manifest` and `/template` are mutually exclusive;
- all existing invocations without `/manifest` behave exactly as today;
- `/template` retains its current template path, output file, stdout, and byte
  behavior;
- manifest mode requires `/output=<directory>` because it can produce several
  files and cannot use stdout as a destination;
- `/validate` continues to control validation of the input document only;
- the manifest is always validated through its own explicit doctype;
- no mode, consumer, format, language, or filename-inference option is added.

In manifest mode, `/output` is only the base directory beneath which entry
`Output` paths are written. It does not claim ownership of that directory. The
directory may already exist, unrelated files remain untouched, and an entry
uses the current single-file write behavior for its own destination.

## Minimal Adapter and Execution Flow

Keep the adapter private to `obNexusScriptCommand.pas`. Add small private
helpers for manifest compilation/enumeration and entry-aware error wrapping;
do not add a public framework or a generic execution unit.

After the existing input JSON has been produced once:

1. Compile the manifest in a separate `TNexusScriptCompilationSession`.
2. Require an explicit resolved doctype and validate the compiled manifest with
   `TNexusScriptValidator`.
3. Locate the single compiled root `NexusManifest`.
4. Iterate its direct compiled `Children` in list order.
5. For each `Template` child:
   1. read `Source.Value.EffectiveText` and `Output.Value.EffectiveText`
      directly, requiring `HasEffectiveText` for both;
   2. resolve `Source` relative to the manifest file's directory;
   3. resolve `Output` beneath the `/output` base directory using the ordinary
      safe-relative-path checks below;
   4. call the existing `RenderTemplate` with the already-produced JSON and
      resolved source path;
   5. call the existing `WriteOutput` for that entry's resolved destination.
6. Stop at the first compilation, validation, rendering, or writing failure.

Wrap per-entry failures with the compiled identity
`NexusManifestName.TemplateName` while retaining the underlying message. Files
written by earlier entries remain written. No rollback or all-or-nothing claim
is made.

An empty valid `NexusManifest` succeeds without rendering or writing anything.

## Path Handling

- Resolve `Source.EffectiveText` relative to the manifest file, using the same
  base regardless of whether composition or a module supplied the value.
- Treat `Output.EffectiveText` as a relative path beneath `/output`.
- Reject an empty output value, rooted/absolute output path, or a normalized
  output path that escapes the output base through `..` traversal.
- Pass the accepted final filename to existing `WriteOutput`; reuse its parent
  directory creation and file replacement behavior.
- Do not add collision preflight, directory ownership, staging, transactions,
  rollback, backup, or replacement semantics. If two entries name the same
  file, deterministic sequential execution means the later ordinary write
  replaces the earlier file, matching `WriteOutput` behavior.

These are local filename checks for safely interpreting a relative manifest
output. They do not introduce a general path-security subsystem.

## Exact Files

### Add

- `NexusTools/Script/validator/NexusManifest.Language.nxscript`
  - minimal `NexusManifest`/`Template` validator described above.
- focused fixtures under `NexusTools/Script/tests/fixtures/manifest/`
  - manifests, Mustache files, and invalid cases used only by the tests below.

### Modify

- `NexusTools/Script/cli/obNexusScriptCommand.pas`
  - register `/manifest`, enforce option compatibility, compile/validate and
    enumerate the manifest, resolve entry paths, and reuse `RenderTemplate` and
    `WriteOutput` per entry.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - add focused validator and CLI batching coverage while retaining all current
    `/template` assertions.
- `NexusTools/Script/README.md`
  - document `/manifest`, its output-base meaning, compiled path values,
    sequential writes, and partial-output-on-failure behavior.

No project file change is expected because the adapter remains in the existing
command unit and `.nxscript` validators/fixtures are runtime files.

### Expected Unchanged

- `NexusTools/Script/src/obNexusScriptCompiler.pas`
- `NexusTools/Script/src/obNexusScriptModel.pas`
- `NexusTools/Script/src/obNexusScriptSession.pas`
- `NexusTools/Script/validator/obNexusScriptValidator.pas`
- all existing validator files
- `NexusTools/Script/parity/obNexusScriptSchemaConsumer.pas`
- `NexusTools/Schema/src/obMustacheRenderer.pas`
- `lib/dmustache/*`

If implementation proves one of these must change, stop and identify the exact
missing current facility before expanding scope.

## Focused Tests

### Existing compatibility

- Existing JSON-output tests pass unchanged.
- Existing `/template` to stdout and file tests remain byte-identical.
- Existing missing-template diagnostics remain unchanged.
- Help adds `/manifest` and no unrelated option.
- `/template` plus `/manifest` fails clearly.
- `/manifest` without `/output` fails clearly.

### Manifest compilation and validation

- The new validator validates against the existing self-validator in its
  current location.
- A manifest with one root and zero entries is valid and performs no writes.
- Missing `Source` or `Output`, a wrong root kind, an unknown child kind, or a
  nested `Template` in an invalid location fails validation or adapter
  cardinality checks as appropriate.
- Auxiliary properties on both `NexusManifest` and `Template` are accepted.
- A missing or invalid manifest doctype fails even when `/validate` is absent.

### Batching and compiled values

- Two entries render two different templates against the same JSON artifact.
- Entry processing and observable overwrite behavior follow compiled child
  order.
- Literal `Source` and `Output` values are read from `EffectiveText`.
- A local auxiliary property reference plus text composition produces the
  expected output filename.
- Root-scope reference, module, and composition fixtures each prove the adapter
  consumes already-compiled effective values rather than reimplementing those
  language features.
- `Source` and `Output` text containing Mustache delimiters is not interpolated
  by the adapter.

### Paths and diagnostics

- Template source paths resolve relative to the manifest.
- Nested relative output paths are created beneath `/output` through existing
  `WriteOutput` behavior.
- Absolute output paths, empty output values, and traversal outside `/output`
  are rejected with the entry identity.
- A missing source, Mustache failure, and output-write failure identify the
  current manifest entry and preserve the underlying error.
- When a later entry fails, processing stops and an earlier successfully
  written output remains, explicitly proving the absence of rollback.

Use isolated temporary output roots so ordinary overwrite and partial-output
tests do not affect repository files.

## Ordered Implementation Stages

### Stage 1: Add the minimal validator and fixtures

- Add `NexusManifest.Language.nxscript` without moving existing validators.
- Add valid and invalid manifest fixtures.
- Prove the new validator is accepted by the existing self-validator and that
  its subject rules accept auxiliary properties while enforcing required
  effective-text fields and child kinds.

### Stage 2: Add the CLI adapter

- Register and parse `/manifest`.
- Enforce `/template` mutual exclusion and required `/output`.
- Add private compilation, validation, root selection, entry enumeration, and
  entry-context helpers in `obNexusScriptCommand.pas`.
- Read compiled `EffectiveText`; do not parse or interpolate property source
  text.

### Stage 3: Batch the existing operation

- Resolve each entry's source and safe relative output paths.
- In compiled child order, call existing `RenderTemplate`, then existing
  `WriteOutput`.
- Stop on the first failure and retain any earlier completed writes.

### Stage 4: Verify and document

- Run the focused tests above and the complete registered NexusScript suite.
- Clean-build NexusScript and its test module.
- Confirm existing single-template output remains byte-identical.
- Search the change for staged-output, transaction, pipeline, Pascal-specific,
  Schema-specific, new interpolation, or new artifact abstractions.
- Update the README with only the delivered CLI contract and failure behavior.

## Non-Goals

- atomic multi-file publication, staging, rollback, backups, or journals;
- destination-directory creation policy beyond what individual writes require;
- destination-directory ownership, cleaning, replacement, or emptiness;
- collision detection or preflight of all entries;
- task graphs, pipelines, processors, generators, or build-system behavior;
- Pascal-, Schema-, validator-generation-, or artifact-specific fields;
- alternate artifacts, consumers, contexts, or per-entry data;
- Mustache processing of `Source` or `Output`;
- new NexusScript syntax, references, expressions, or compiler semantics;
- validator relocation or reorganization;
- parallel execution, conditions, dependencies, hooks, or post-processing;
- changes to the existing `/template` contract or Mustache implementation.

## Delegation

No sub-agent delegation is proposed. The implementation is one narrow CLI seam
whose parsing, compiled-model enumeration, render call, write call, and tests
should be kept together.

## Approval Gate

This plan stops before implementation. Direct human-owner authorization is
required before adding the validator or fixtures, modifying the CLI or README,
building, or running tests.
