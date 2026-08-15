# Work Plan: NexusScript Command-Line Interface

## Inputs

- Human-owner request supplied through
  `C:\Users\kcollins\.codex\attachments\6154274f-c541-4ce7-afd8-93a761c3dea5\pasted-text.txt`.
- Human-owner corrections made during review:
  - artifact generation is the normal NexusScript CLI operation;
  - JSON is the default final artifact;
  - a template changes the final stage from raw JSON to rendered text;
  - compilation is an internal pipeline stage, not a command-line mode;
  - no format, JSON, compile, or implementation-selection option belongs in
    this phase.
- Standard command-line implementation in
  `NexusLib/core/src/obNXCommandLine.pas`.
- Existing NexusScript compiler, doctype loading, Validator engine,
  compiled-document-to-metadata conversion, metadata JSON generation, and
  Mustache rendering code.
- Repository architecture protocol and Object Pascal standards.

## Objective

Replace the positional NexusScript executable interface with a useful artifact
command built on `TNXCommandLine`.

Every successful invocation follows one fixed pipeline:

```text
NexusScript source
  -> compiled document
  -> existing metadata JSON representation
  -> optional Mustache rendering
  -> stdout or output file
```

The CLI does not ask the user to select any internal implementation role or
intermediate representation. Compilation and JSON construction happen because
they are required by the artifact pipeline.

## Supported Command Line

```text
/input=<file>       required NexusScript source document
/output=<file>      optional output destination; stdout when omitted
/template=<file>    optional Mustache template
/validate           optional validation through the document's doctype
/help               standard TNXCommandLine help
```

No other operation or mode flags are introduced.

Examples:

```text
NexusScript /input=Customer.Schema.nxscript
NexusScript /input=Customer.Schema.nxscript /output=Customer.json
NexusScript /input=Customer.Schema.nxscript /template=Firebird.mustache
NexusScript /input=Customer.Schema.nxscript /template=Firebird.mustache /output=Customer.sql
NexusScript /input=Customer.Schema.nxscript /validate /output=Customer.json
```

Behavior is fixed:

- without `/template`, emit JSON;
- with `/template`, build the same JSON and render it through Mustache;
- without `/output`, write the final artifact to stdout;
- with `/output`, write the final artifact to that file;
- with `/validate`, validate after compilation and before artifact generation;
- `/help` uses the standard generated help behavior and does not require
  `/input`.

Positional arguments, unknown options, and missing required values are errors
under the existing `TNXCommandLine` rules. Because `TNXCommandLine` permits a
value on a value-free registered flag, the CLI execution class will explicitly
reject `/validate=<value>`.

## Existing Representation Boundary

The JSON emitted in this phase is the representation already used by the
NexusScript Schema parity and Mustache artifact path. It is not advertised as a
generic serialization of every internal NexusScript compiler object.

The CLI will call the existing compiled-document-to-metadata conversion and
`MetaDataToMustacheJSON`. It will not duplicate those mappings. If an input
document cannot be represented by that existing path, artifact generation
fails clearly rather than silently producing empty or misleading JSON.

This limitation is documented as current artifact behavior. It does not create
a command-line selection mechanism, public extension API, registry, discovery
rule, or future plugin contract.

## Verified Current State

- `NexusScript.lpr` currently accepts exactly one positional source filename,
  compiles it through `TNexusScriptCompilationSession`, and reports a root
  definition count.
- `TNXCommandLine` already provides registered options, `/name` and
  `/name=value` syntax, required/value constraints, unknown-option rejection,
  generated help, and testable `ParseArguments` support.
- `TNexusScriptCompilationSession` compiles the entry document and its module
  and doctype dependencies.
- The compiled entry document retains its associated `DoctypeDocument` without
  importing the doctype document into its namespace.
- `TNexusScriptValidator.Validate` accepts a compiled subject document and the
  associated compiled doctype document.
- The existing NexusScript Schema parity path converts the compiled source into
  `TMetaDataModuleList`, then calls `MetaDataToMustacheJSON`.
- `RenderMustacheFile` currently performs the required Mustache operation but
  only through filenames. Its internal renderer already operates on JSON and
  template text.

## Architecture

```text
TNXCommandLine
      |
      v
NexusScript command execution
      |
      +--> TNexusScriptCompilationSession
      |
      +--> optional TNexusScriptValidator
      |         subject + subject.DoctypeDocument
      |
      +--> existing compiled-document-to-metadata conversion
      |
      +--> MetaDataToMustacheJSON
      |
      +--> optional shared Mustache text renderer
      |
      +--> stdout or file
```

Argument parsing remains separate from command execution. A small CLI-owned
class will register options, enforce option semantics, run the fixed pipeline,
and deliver the final artifact. This boundary exists to keep orchestration out
of the program file and make stdout/file behavior directly testable; it is not
an extension or dispatch abstraction.

The generic NexusScript lexer, parser, source model, compiler, and compilation
session remain unaware of command-line options, metadata JSON, and Mustache.

## Planned File Changes

### `NexusTools/Script/src/NexusScript.lpr`

- Remove positional argument handling and the compile-only success path.
- Register NexusScript options through the command execution class.
- Set `TNXCommandLine.AllowUnknownFlags := False`.
- Call the standard parse and validation lifecycle.
- Execute the artifact pipeline.
- Write errors to `StdErr` and return exit code `1` without contaminating
  stdout.

### `NexusTools/Script/cli/obNexusScriptCommand.pas` (new)

- Register `/input`, `/output`, `/template`, and `/validate`; `/help` remains
  the standard internally registered option.
- Read values from `TNXCommandLine` without adding another argument parser.
- Compile `/input` through `TNexusScriptCompilationSession`.
- Optionally validate through `CompiledDocument.DoctypeDocument`.
- Produce metadata and JSON through the existing implementation.
- If `/template` is supplied, load it and render the JSON through the shared
  Mustache text API.
- Hold the completed artifact in memory until all compilation, validation,
  conversion, and rendering steps succeed.
- Write the final artifact to `/output` or an injected stdout stream.
- Report compilation and validation diagnostics without reproducing their
  semantic logic.

The class is an executable-specific coordinator. It does not define public
extension behavior or dynamic selection.

### Existing compiled-document-to-metadata conversion

- Reuse the existing implementation currently exercised by NexusScript Schema
  parity tests.
- If its current `parity` location would make the production executable depend
  on a test-owned folder, move that unit unchanged to an internal artifact
  location under `NexusTools/Script` and update project/test paths.
- Do not rename its concepts, change conversion semantics, or generalize it as
  part of this task.
- Keep parity fixtures and parity assertions in the parity folder.

This is a repository ownership correction only if required by project wiring;
it is not a new runtime concept.

### `NexusTools/Schema/src/obMustacheRenderer.pas`

- Add one text-to-text rendering function accepting JSON text and template text
  and returning the rendered text.
- Make the existing filename-based renderer delegate to that function.
- Preserve existing rendering behavior and errors.

This prevents temporary JSON files and avoids duplicating direct
`TSynMustache.TryRenderJson` usage in the CLI.

### Project files

- Add CLI orchestration and its existing unit dependencies to
  `NexusTools/Script/NexusScript.lpi`.
- Add the CLI unit and required paths to
  `NexusTools/Script/tests/NexusScriptTestModule.lpi`.
- Do not add artifact or command-line dependencies to generic compiler units.

### Documentation

- Document the five supported options and the four principal invocation forms.
- State that raw JSON is the normal output and `/template` replaces raw JSON
  with rendered output.
- State that the current JSON is the existing artifact representation, not a
  dump of compiler internals.
- State that filename components are decorative and have no execution meaning.
- Do not describe speculative public extension or selection behavior.

## Implementation Stages

### Stage 1: Make Mustache rendering usable in memory

- Extract the text rendering operation already inside `RenderMustacheFile` into
  one public text-to-text function.
- Delegate the existing file API to it.
- Add focused equivalence and failure tests.

Acceptance: file and in-memory rendering share one implementation and produce
identical rendered text.

### Stage 2: Add the fixed artifact pipeline

- Add the CLI execution class.
- Compile the input and retain the entry source and compiled document.
- When requested, validate against the explicit doctype association.
- Invoke the existing metadata conversion and JSON generation.
- Optionally render the resulting JSON through the supplied template.
- Do not write anything until the complete artifact exists.

Acceptance: one code path always produces JSON and conditionally performs one
additional Mustache stage. There are no selectable output modes or internal
implementation switches.

### Stage 3: Add destination handling

- Use an injectable stream for default stdout delivery.
- Write the same completed artifact to `/output` when present.
- Use one explicit encoding so stdout and file results are byte-equivalent.
- Avoid leaving partial output files when an earlier pipeline stage fails.

Acceptance: stdout contains only the artifact, file output contains the same
artifact bytes, and failures produce neither partial artifact stream output nor
partial destination content.

### Stage 4: Replace the executable interface

- Register the four task options and use standard `/help` support.
- Reject unknown and positional arguments through `TNXCommandLine`.
- Route exceptions and diagnostics to stderr.
- Remove the former positional and compile-only behavior.

Acceptance: the executable implements exactly the documented option set and
every normal successful invocation produces an artifact.

### Stage 5: Regression verification and documentation

- Add focused CLI tests and fixtures.
- Run the complete NexusScript suite and parity paths.
- Run clean executable and test-module builds.
- Search for duplicate parsing, conversion, rendering, and filename inference.
- Update user-facing CLI documentation.
- Create and inspect the required source archive after approved implementation.

Acceptance: new CLI behavior passes, existing compiler/validator/parity behavior
is unchanged, and the archive contains sources and fixtures without binaries.

## Validation Behavior

When `/validate` is absent, compilation proceeds directly to artifact
generation.

When `/validate` is present:

1. compile the subject and its dependencies;
2. require an associated `DoctypeDocument`;
3. pass the subject and associated document to the existing Validator engine;
4. stop before metadata/JSON generation if validation fails;
5. report each validation diagnostic through stderr with its code, source
   location, and message.

The CLI does not derive validation behavior from filename components and does
not search for validator files independently.

## Error And Output Contract

- Success without `/template`: JSON artifact only.
- Success with `/template`: rendered artifact only.
- No `/output`: artifact goes to stdout.
- `/output`: artifact goes to the named file.
- Help: standard `TNXCommandLine` help and exit behavior.
- Failure: diagnostic text goes to stderr and process exit code is `1`.
- Compilation, validation, conversion, template loading, rendering, and output
  failures do not emit a successful artifact.
- Missing input or template files identify the relevant path.
- A document unsupported by the existing metadata conversion fails explicitly.

## Test Plan

### Command-line parsing

- `/input` is required and requires a value;
- `/output` and `/template` require values when supplied;
- `/validate` works without a value and `/validate=<value>` is rejected;
- `/help` works without `/input`;
- unknown options are rejected;
- positional arguments are rejected;
- removed mode-like option names are not registered and are rejected;
- `ClearRegisteredFlags` resets shared parser state between tests.

### JSON artifact

- `/input=<valid-schema-script>` emits the exact existing parity JSON to the
  injected stdout stream;
- `/output=<file>` writes the same JSON bytes and leaves stdout empty;
- missing input file fails without output;
- invalid NexusScript fails without output;
- a compiled document unsupported by the existing conversion fails clearly.

### Mustache artifact

- `/template=<file>` implies JSON construction and emits expected rendered text;
- `/template` plus `/output` writes rendered output and leaves stdout empty;
- the JSON passed to Mustache is exactly the JSON emitted without a template;
- missing template file fails without output;
- rendering failure fails without partial output;
- shared in-memory and file rendering produce equivalent results.

### Validation

- `/validate` succeeds using the subject's associated doctype document;
- absence of a doctype is an explicit error;
- validation failure reports diagnostics and prevents JSON generation;
- validation failure prevents template rendering and output-file replacement;
- filename components never affect validation.

### Regression

- complete lexer/parser/compiler tests;
- reference, array, composition, module, and doctype tests;
- Validator self-validation and finite-value tests;
- Schema validation tests;
- inForce and Storm exact JSON parity;
- existing Mustache rendering parity;
- clean `NexusScript.lpi` build;
- clean `NexusScriptTestModule.lpi` build;
- complete registered NexusScript suite.

## Focused Verification Searches

- no argument parser outside `obNXCommandLine`;
- no filename-component semantic inference;
- no duplicated compiled-document-to-metadata mapping;
- no duplicated metadata-to-JSON mapping;
- no direct `TSynMustache.TryRenderJson` call in the CLI;
- no mode-selection flags or code paths;
- no command-line, JSON, metadata, or Mustache dependencies added to generic
  compiler/model/session units;
- no speculative registry, discovery, ABI, plugin, or dispatch machinery.

## Explicitly Out Of Scope

- Compile-only command-line operation.
- Output-format selection.
- Explicit JSON selection.
- Runtime implementation selection.
- Generic serialization of compiler internals.
- Public extension APIs, standards, registries, discovery, or DLL interfaces.
- Automatic behavior inferred from filename components.
- Subcommands or another argument parser.
- NexusLS/VS Code integration.
- Build execution, Installer packaging, or arbitrary external integrations.
- Changes to NexusScript syntax, doctype semantics, Validator vocabulary, or
  existing metadata conversion semantics.

## Sub-Agent Plan

No delegation is requested for planning. If implementation is later approved
and delegation is explicitly requested, one bounded CLI worker may own the new
CLI unit, project wiring, and focused tests. Main Codex retains responsibility
for integration review, generic-boundary verification, complete test execution,
and archive inspection.

## Approval Gate

This is a work plan only. It authorizes no implementation edits, builds, tests,
executable runs, archive creation, or other implementation activity.
Implementation begins only after direct human-owner approval.
