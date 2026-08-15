# Work Plan: NexusScript Command-Line Interface

## Inputs

- Human-owner request supplied through
  `C:\Users\kcollins\.codex\attachments\6154274f-c541-4ce7-afd8-93a761c3dea5\pasted-text.txt`.
- Current NexusScript compiler, compilation session, doctype association,
  Validator engine, Schema consumer, parity tests, and Mustache parity path.
- Standard repository command-line implementation in
  `NexusLib/core/src/obNXCommandLine.pas`.
- Existing Schema JSON conversion in `obMetaDataJSON.pas` and Mustache
  rendering in `obMustacheRenderer.pas`.
- Repository architecture protocol and Object Pascal standards.

## Objective

Replace the positional, compile-only NexusScript executable interface with a
small useful CLI built on `TNXCommandLine`. The executable will retain
compile-only operation and add Schema-consumer JSON generation, optional
Mustache rendering, output to a file or stdout, and explicit doctype-based
validation.

This is not a generic serialization of the compiled NexusScript tree. JSON and
Mustache output in this pass are produced through the existing Schema consumer
and NexusSchema metadata JSON model. That domain-specific boundary must remain
visible in the implementation and help text.

## Verified Current State

- `NexusScript.lpr` currently accepts exactly one positional filename, compiles
  it with `TNexusScriptCompilationSession`, and prints a root-definition count.
- `TNXCommandLine` already provides registered flags, `/name` and
  `/name=value` parsing, required/value constraints, defaults, unknown-option
  rejection, `/help`, and testable `ParseArguments` state.
- `TNexusScriptCompilationSession` loads module and doctype dependencies and
  retains the entry compiler. Its compiled document exposes the associated
  `DoctypeDocument` without importing that document into the subject namespace.
- `TNexusScriptValidator.Validate` accepts the compiled subject and compiled
  validator document directly and exposes structured validation diagnostics.
- `TNexusScriptSchemaConsumer.Consume` converts the source and compiled Schema
  document into `TMetaDataModuleList` without duplicating conversion logic.
- `MetaDataToMustacheJSON` already returns the exact Schema JSON string used by
  parity tests.
- `RenderMustacheFile` currently accepts filenames only, although its internal
  implementation already renders JSON and template text with
  `TSynMustache.TryRenderJson`.
- The Schema consumer currently resides under `NexusTools/Script/parity`, which
  is no longer an accurate production ownership location once the CLI uses it.

## Supported Interface

Register these flags with `TNXCommandLine`:

```text
/input=<file>       required NexusScript source document
/output=<file>      optional artifact destination
/format=json        optional Schema JSON artifact selection
/template=<file>    optional Mustache template; implies Schema JSON generation
/validate           optional validation through the compiled doctype document
/help               standard TNXCommandLine help flag
```

The executable will reject positional arguments and unknown flags. `/input`,
`/output`, `/format`, and `/template` require values. `/validate` is a
value-free flag. `/help` remains owned by `TNXCommandLine` and must work without
supplying `/input`.

Option interactions are:

- no `/format` and no `/template`: compile only;
- `/format=json`: emit the Schema JSON artifact;
- `/template=<file>`: build the same Schema JSON model and render the template;
- `/template` with `/format=json`: valid and equivalent to `/template` alone;
- any `/format` value other than `json`: error;
- `/output` during compile-only operation: error because no artifact exists;
- `/validate`: require a doctype association, validate before consumer
  conversion, and suppress artifact generation on failure.

The CLI will not infer anything from the input filename or filename components.
The decorative `Customer.Schema.nxscript` convention remains usable but has no
execution semantics.

## Execution Architecture

```text
TNXCommandLine
      |
      v
NexusScript CLI execution boundary
      |
      +--> TNexusScriptCompilationSession
      |          |
      |          +--> optional doctype document
      |
      +--> optional TNexusScriptValidator
      |
      +--> TNexusScriptSchemaConsumer
      |          |
      |          v
      |    TMetaDataModuleList
      |          |
      |          v
      |    MetaDataToMustacheJSON
      |
      +--> optional shared Mustache text renderer
      |
      +--> output file or stdout
```

The argument parser will register and read options only. A small CLI-owned
execution class will own compilation, optional validation, Schema conversion,
template rendering, and artifact delivery. It will accept an injectable output
stream for stdout-mode tests; the executable will adapt the process stdout
handle to that stream. File output remains an explicit destination selected by
the same execution class.

No Schema vocabulary or Schema units will be added to the generic compiler,
model, or compilation session.

## File And Ownership Changes

### `NexusTools/Script/src/NexusScript.lpr`

- Register the five NexusScript flags through the CLI execution class.
- Set `TNXCommandLine.AllowUnknownFlags := False`, then parse and validate using
  the established Nexus executable pattern.
- Invoke the execution boundary.
- Send errors to `StdErr`, return a nonzero exit code, and never write
  diagnostics into stdout artifact output.
- Preserve a concise compile-success message only for compile-only mode.

### `NexusTools/Script/cli/obNexusScriptCommand.pas` (new)

- Own flag registration and interpretation for the NexusScript executable.
- Enforce cross-option rules that `TNXCommandLine` cannot express, including
  supported format values and `/output` requiring an artifact operation.
- Compile through `TNexusScriptCompilationSession` and surface its diagnostic
  failure without reimplementing parsing or resolution.
- When `/validate` is present, require `DoctypeDocument`, invoke the existing
  Validator engine, and format all validator diagnostics with their codes,
  source positions, and messages.
- Convert artifacts through `TNexusScriptSchemaConsumer` and
  `MetaDataToMustacheJSON`.
- Render templates through the shared Mustache text API.
- Write the final artifact either to the requested file or the supplied stdout
  stream. Do not print status text in artifact mode.
- Keep the class narrowly CLI-specific; do not define a consumer registry,
  plugin interface, or reusable command framework.

### Schema consumer ownership

- Move `obNexusScriptSchemaConsumer.pas` from `NexusTools/Script/parity` to
  `NexusTools/Script/consumers/schema` without changing its domain behavior.
- Update NexusScript project and test search paths/call sites to use the new
  ownership location.
- Keep parity fixtures and parity assertions under `parity`; only the reusable
  consumer implementation moves.

This prevents a production executable from depending on a test/parity-owned
folder while preserving the already verified conversion implementation.

### `NexusTools/Schema/src/obMustacheRenderer.pas`

- Add one shared text-to-text rendering function accepting JSON text and
  template text and returning rendered text.
- Make the existing file-based renderer delegate to that function.
- Preserve existing file-rendering behavior and error wording.

This is the smallest change that allows the CLI to render directly to stdout
or a chosen output file without temporary JSON files or duplicated
`TSynMustache` calls.

### Project files

- Update `NexusTools/Script/NexusScript.lpi` with CLI, Schema consumer,
  Validator, Schema metadata/JSON, core command-line, and Mustache unit paths.
- Update `NexusTools/Script/tests/NexusScriptTestModule.lpi` for the promoted
  consumer and CLI execution unit.
- Do not add these domain dependencies to the generic compiler units.

### Documentation

- Add a concise CLI section under `NexusTools/Script` documenting exact syntax,
  compile-only behavior, Schema-specific JSON semantics, template implication,
  stdout/file behavior, validation via doctype, and exit/error behavior.
- State explicitly that filename components are decorative and are not used for
  consumer or validator discovery.

## Implementation Stages

### Stage 1: Establish production ownership for the Schema consumer

- Move the existing consumer unit from `parity` to `consumers/schema`.
- Update test and project search paths without changing conversion behavior.
- Confirm the existing Schema JSON and Mustache parity tests still exercise the
  same consumer class.

Acceptance: there is one Schema conversion implementation, production code no
longer depends on a parity-owned unit, and existing parity behavior is
unchanged.

### Stage 2: Expose in-memory Mustache rendering

- Extract the existing `TryRenderJson` operation behind a public text-based
  function in `obMustacheRenderer`.
- Delegate `RenderMustacheFile` through the new function.
- Add focused success and invalid-template/JSON tests while retaining the
  existing file-based rendering tests.

Acceptance: file and in-memory rendering share one implementation and produce
the same output.

### Stage 3: Build the CLI execution boundary

- Add registered option definitions and generated help descriptions.
- Add format and option-combination validation.
- Implement compile-only, JSON, template, validation, file-output, and
  stream-output paths.
- Ensure artifact generation performs Schema conversion exactly once and a
  template consumes that same JSON string.
- Treat missing input/template files, compiler failures, absent doctypes,
  validation failures, unsupported formats, consumer rejection, rendering
  failures, and output-write failures as explicit command failures.

Acceptance: the command class contains orchestration but no parser,
NexusScript compiler logic, Schema mapping duplication, or Mustache engine
duplication.

### Stage 4: Replace the executable front end

- Replace positional argument handling with the standard `TNXCommandLine`
  lifecycle.
- Route artifact bytes only to stdout when `/output` is absent.
- Route error text only to stderr and return a nonzero exit status.
- Write compile-only status without creating an artifact.

Acceptance: every supported example uses `/name` or `/name=value`, `/help` is
generated by the shared framework, and stdout artifacts are not contaminated by
status or diagnostics.

### Stage 5: Tests and documentation

- Add CLI parsing and execution tests to the existing NexusScript suite.
- Add small valid/invalid source and Mustache fixtures only where current
  fixtures do not express the case.
- Document the Schema-specific nature of the initial artifact producer and the
  absence of filename semantics.
- Run focused searches proving no command parser or conversion logic was
  duplicated.

Acceptance: supported behavior is documented and all focused and regression
tests pass.

## Test Plan

### Command-line parsing

- registered flag names and generated help text;
- required `/input`;
- value requirements for input, output, format, and template;
- value-free `/validate`;
- unknown flag rejection;
- positional argument rejection;
- unsupported `/format` rejection;
- `/output` without an artifact operation rejection;
- parser global state reset between cases with `ClearRegisteredFlags`.

### Execution

- valid compile-only invocation and success summary;
- missing input file;
- invalid NexusScript source;
- `/format=json` produces the exact existing Schema parity JSON;
- `/template=<file>` produces the expected rendered text without `/format`;
- `/template` plus `/format=json` produces the same output;
- `/output=<file>` writes the artifact and does not emit it to the injected
  stdout stream;
- omitted `/output` writes the exact artifact to the injected stdout stream;
- stdout artifact contains no compile-success or diagnostic text;
- missing template file;
- invalid Mustache/JSON rendering failure;
- Schema consumer rejection of a compiled non-Schema document;
- `/validate` succeeds through the subject's doctype document;
- `/validate` fails when no doctype is associated;
- validator diagnostics prevent file and stdout artifact emission.

### Regression

- full NexusScript compiler and module tests;
- doctype parsing/loading/isolation/cycle tests;
- Validator self-validation and finite-value tests;
- Schema validation tests;
- inForce and Storm exact JSON parity;
- existing Mustache rendering parity;
- `NexusScript.lpi` clean build;
- `NexusScriptTestModule.lpi` clean build;
- complete registered NexusScript test suite.

## Focused Verification Searches

- no new argument tokenizer/parser outside `obNXCommandLine`;
- no filename-component validator or consumer inference;
- no `TSynMustache.TryRenderJson` duplication in the CLI;
- no duplicated Schema-to-metadata or metadata-to-JSON mapping in the CLI;
- no Schema, Validator, JSON, Mustache, or command-line units added to generic
  compiler/model/session unit dependencies;
- no production dependency on `NexusTools/Script/parity`.

## Error And Output Contract

- Successful artifact mode: artifact only on stdout unless `/output` is used.
- Successful file-output mode: artifact written to the file; stdout remains
  free of artifact content.
- Successful compile-only mode: concise success text on stdout.
- Any failure: diagnostic text on stderr and process exit code `1`.
- Command syntax/help completion retains the standard `TNXCommandLine`
  behavior and exit codes.
- Output uses one explicit text encoding for stdout and files so the same
  artifact is byte-equivalent across destinations.
- No partially generated artifact is emitted after compilation, validation,
  conversion, or rendering failure. File output is prepared in memory before
  the destination is replaced.

## Deferred Scope

- Generic serialization of the NexusScript source or compiled model.
- Automatic consumer selection from doctype names or documents.
- Consumer/plugin registration, discovery, DLL ABI, or opaque handles.
- Filename-based validator or profile discovery.
- NexusLS/VS Code integration.
- Build execution, Installer packaging, or arbitrary third-party consumers.
- Subcommands or an additional argument parser.
- Changes to NexusScript syntax, compiler semantics, doctype loading, Validator
  vocabulary, or Schema conversion semantics.

## Implementation Decisions

- `/validate` is included because doctype support is present and already exposes
  the compiled associated document required by the Validator engine.
- `json` means the existing Schema-consumer Mustache JSON model in this pass;
  help and documentation must not call it generic NexusScript JSON.
- A template always implies that JSON model. Requiring `/format=json` would add
  no information.
- `/output` is rejected in compile-only mode rather than silently creating an
  empty file or redirecting a status message.
- Output is generated fully before writing, which keeps stdout clean and avoids
  leaving a partial destination on semantic failures.

## Sub-Agent Plan

No delegation is requested for planning. If implementation is later approved
and delegation is explicitly requested, one bounded NexusScript CLI worker may
own the new `cli` unit, project wiring, and focused tests. The main agent must
retain review of the generic/domain boundary, the Schema consumer promotion,
shared Mustache API, complete verification, and archive inspection.

## Approval Gate

This file is a work plan only. It authorizes no implementation edits, builds,
tests, executable runs, archive creation, or other implementation activity.
Implementation begins only after direct human-owner approval.
