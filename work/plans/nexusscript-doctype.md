# Work Plan: NexusScript Doctype Association

> Historical plan: the named form described below was superseded by
> `doctype Path;`. The current dependency contract and implementation are
> defined by `nexusscript-document-dependencies.md`.

## Inputs

- Source request: direct human-owner request for a work plan, supplied through
  `C:\Users\kcollins\.codex\attachments\86914964-77ee-440e-9af7-ac00508f6534\pasted-text.txt`.
- Current NexusScript compiler, model, session, validator, fixtures, and tests
  under `NexusTools/Script`.
- Current NexusScript validation-system plan and implementation state.
- Existing constraints:
  - this is a work-plan/design task only;
  - `doctype` remains generic compiler metadata;
  - it does not import names or perform validation;
  - filename-based validator/profile discovery is superseded;
  - no NexusLS, editor tooling, automatic validation dispatch, directive
    framework, or domain-specific compiler behavior;
  - unrelated working-tree changes must remain untouched.

## Summary

Add one optional header declaration:

```text
doctype Schema "Schema.nxscript";
```

The declaration associates the current document with another normally compiled
NexusScript document. The association is retained on the compiled document as
metadata. It creates no module import, exposes no definitions to ordinary
reference/composition lookup, and invokes no consumer.

The resulting flow is:

```text
subject source
  -> parse doctype declaration
  -> compilation session loads doctype dependency
  -> both documents compile normally
  -> subject compiled document retains doctype metadata and document pointer
  -> caller may pass that document to a consumer such as TNexusScriptValidator
```

`doctype` replaces semantic discovery from filenames. `.nxscript` remains the
ordinary source-file extension, but filename components have no compiler or
consumer-selection meaning.

## Verified Findings

- `TNexusScriptParser.Parse` currently accepts zero or more leading `module`
  declarations, then treats every remaining top-level construct as a
  definition.
- `ParseModule` already implements the relevant word/string/path token handling
  and source-range capture. A doctype has the simpler `Name Path` shape and no
  root selector.
- `TNexusScriptSourceDocument` owns a module list and its source definitions.
  It has no general directive or document-metadata collection.
- `TNexusScriptCompiledDocument` currently owns only its compiled root
  definitions and source name.
- `TNexusScriptCompilationSession` owns every `TNexusScriptCompiler` in a
  case-insensitive canonical-path cache. Each compiler owns its source and
  compiled documents.
- The session's active canonical-file list already terminates recursive module
  loading and can cover doctype edges without a separate recursion mechanism.
- Module loading calls `AddImportedDocument` or `AddImportedDefinition`, which
  creates addressable imported roots in the importer. Doctype loading must not
  call either operation.
- `TNexusScriptValidator.Validate` already accepts two compiled documents. A
  caller can use the subject document's doctype association as its second
  argument without changing the Validator API or adding automatic dispatch.
- Current validation fixtures and documentation still use names such as
  `Customer.Schema.nxscript` and describe the penultimate component as future
  validator discovery. That semantic convention is now superseded.
- `NexusScript.lpr` currently advertises
  `<name>[.<validator>].nxscript`; this usage text must return to a neutral
  script-file description.
- The current compiler does not enforce `.nxscript` or inspect filename
  components. That extension-agnostic behavior must remain unchanged.

## Architecture Problem

Consumers need an explicit, compiled association between a document and the
document that defines its semantic type. Encoding that choice in the filename
does not place the relationship in the compiled model and forces tooling to
infer semantics outside normal dependency loading.

The correction is one concrete top-level declaration, not a general directive
system. The parser recognizes it, the compilation session loads it through the
existing document dependency graph, and the compiled document exposes the
association. Consumer meaning remains outside the compiler.

## Target Contract

### Syntax and ordering

```text
doctype Name Path;
```

- `Name` is one ordinary word token.
- `Path` follows the same quoted/unquoted scalar path token behavior currently
  accepted for module paths.
- A document may contain zero or one doctype declaration.
- Header declarations may contain `doctype` and `module` declarations in either
  order before the first ordinary definition.
- A second doctype is a compile-time duplicate-declaration error.
- `doctype` after the first ordinary definition is a compile-time header-order
  error, not an attempted definition.
- `doctype` is only recognized at document root.
- The declaration does not support aliases, root selectors, multiple paths,
  inheritance, fallback, or chaining syntax.

### Source model

Add one dedicated source-doctype object owned by
`TNexusScriptSourceDocument`, containing:

- declared name;
- declared path text;
- declaration source range.

Do not add a generic directive collection. `doctype` and `module` remain
separate concrete concepts because they have different cardinality and
semantics.

### Compiled model

`TNexusScriptCompiledDocument` exposes one optional association containing:

- declared doctype name;
- declaration source range;
- declared path text;
- canonical referenced source identity;
- the compiled doctype `TNexusScriptCompiledDocument`.

The association is absent when no doctype was declared. Its compiled-document
pointer is non-owning: the compilation session owns the referenced compiler and
document, just as it owns all documents participating in the dependency graph.
The subject compiled document copies its name/path/range/identity metadata and
must not free the referenced document.

The association remains valid for the lifetime of the compilation session.
The API and documentation must state that compiled documents obtained from a
session do not outlive that session.

Do not represent the doctype as a synthetic compiled definition. It must not
appear in `Definitions`, `FindDefinition`, imported roots, scopes, references,
composition, arrays, or consumer traversal.

### Loading and cycle behavior

Generalize the session's private loader conceptually from `CompileModule` to
compiling a document dependency by canonical path. Both module and doctype
edges use:

- path resolution relative to the declaring file;
- canonical-path caching;
- compile-once behavior;
- active-file cycle detection;
- ordinary compilation of the referenced document, including its own modules
  and optional doctype.

The edge behavior then diverges:

- module edge: expose imported roots under their declared names;
- doctype edge: set compiled-document metadata only.

Cycle detection must cover module-only, doctype-only, and mixed dependency
cycles. Diagnostics should use document/dependency wording where the same path
is shared, while doctype-specific missing-path errors should identify the
doctype declaration. Do not retain misleading "module cycle" text for a
doctype cycle.

The loader must not place a partially compiled document into the completed
cache. On failure it removes the active-file marker and releases the partial
compiler through the existing `try/finally` ownership path.

### Namespace behavior

Given:

```text
doctype Schema "Schema.nxscript";

Thing Root {
    Value: @Schema.Rule;
}
```

the reference fails unless an independent `module ...;` declaration imports
that root. The doctype name is metadata, not a scope entry. The same
rule applies to composition selectors.

A doctype does not participate in the addressable namespace, so only imported
and local root names participate in root collision checks.

### Validator integration

Do not change `TNexusScriptValidator.Validate`. The focused integration is a
caller-side test equivalent to:

```text
SubjectDocument.Doctype.Document
  -> passed as AValidatorDefinition
```

No automatic validation, recursive validator chaining, filename parsing, or
consumer selection is added.

The validation fixture chain should become explicit metadata:

```text
Customer.nxscript
  doctype Schema "Schema.nxscript"

Schema.nxscript
  doctype Validator "Validator.nxscript"

Validator.nxscript
  no doctype; explicit self-validation remains a Validator API test
```

The terminal validator definition must not declare itself as its own doctype,
because that would correctly be a document dependency cycle. Self-validation
is a consumer operation, not a loading relationship.

### Filename convention removal

- Rename semantic-looking validation fixtures to neutral ordinary filenames:
  `Customer.nxscript`, `Schema.nxscript`, and `Validator.nxscript`.
- Add explicit doctype declarations to `Customer.nxscript` and
  `Schema.nxscript` as described above.
- Update test references and validator documentation.
- Change the NexusScript executable usage text back to a neutral
  `<script-file>` form.
- Correct repository work-plan/documentation statements that assign semantic
  meaning to a penultimate filename component.
- Do not add filename parsing, extension enforcement, or compatibility
  discovery for the superseded convention.

Existing filenames outside the focused NexusScript fixtures do not need broad
renaming merely because they contain multiple dots. The rejected behavior is
semantic inference, not dots in filenames.

## Scope

- Dedicated source doctype model and source-document ownership.
- Optional compiled-document doctype association and documented lifetime.
- Parser support for one root header declaration.
- Session loading, canonical identity, caching, and mixed-edge cycle handling.
- Neutral filename/documentation corrections directly associated with the
  superseded validator-discovery convention.
- Focused compiler/session/validator-side tests and doctype fixtures.

## Out Of Scope

- Automatic validation or validator dispatch.
- Validator engine redesign or renaming.
- Meaning assigned to the doctype name by the compiler.
- NexusLS, VS Code, hover, completion, navigation, or diagnostics integration.
- Filename-based semantic discovery or extension enforcement.
- Multiple doctypes, doctype inheritance, fallback, chaining semantics, or
  recursive consumer invocation.
- General directives, arbitrary document metadata, annotations, attributes, or
  a plugin mechanism.
- Documentation generation.
- Changes to NexusSchema production integration, schema metadata, rendering,
  NexusTask, Installer, UI, Build, or unrelated projects.

## Staged Implementation Plan

### Stage 1: Add source and compiled doctype models

- Add the dedicated source declaration object with name, path, and range.
- Make the source document own zero or one declaration.
- Add the compiled association fields and a narrow setter/constructor path used
  by the session.
- Keep the referenced compiled-document pointer non-owning and clear about
  session lifetime.

Acceptance: construction/destruction tests cover absent and present metadata;
freeing a subject document does not free or corrupt the referenced doctype
document.

### Stage 2: Parse the header declaration

- Factor only the path-token collection shared naturally by `module` and
  `doctype`; do not introduce a general directive parser.
- Parse interleaved leading module/doctype declarations.
- Enforce `Name Path`, one declaration, terminating semicolon, and header
  ordering.
- Preserve source range and declared path text.
- Assign distinct, deterministic diagnostics for duplicate, malformed, and
  misplaced declarations.

Acceptance: focused `CompileText` parser tests cover no declaration, quoted and
unquoted paths, duplicates, missing name/path/semicolon, extra pieces, nested
text, and declaration after a definition.

### Stage 3: Load and associate the doctype document

- Generalize the session's dependency loader while preserving the canonical
  compiler cache and active-file ownership.
- Resolve doctype paths relative to their declaring file.
- Compile the doctype and all of its dependencies normally.
- Attach the doctype metadata after the subject's final successful compile.
- Never call module-import APIs for the doctype edge.
- Make missing-file and dependency-cycle errors deterministic and relevant to
  both module and doctype edges.

Acceptance: focused file-fixture tests prove successful loading, canonical
source identity, compiled pointer availability, missing-file failure,
doctype-only cycles, mixed module/doctype cycles, and cache reuse when the same
physical document is reached through multiple edges.

### Stage 4: Prove namespace isolation and module coexistence

- Add a doctype document containing recognizable definitions.
- Prove a subject cannot reference or compose those definitions through the
  doctype name.
- Prove an ordinary module beside the doctype remains addressable.
- Prove module imports beside a doctype retain ordinary root-name behavior and
  do not collide with doctype metadata.

Acceptance: only explicit module imports affect reference/composition lookup;
all existing module tests remain unchanged.

### Stage 5: Connect the explicit validation fixture chain

- Rename the three validation fixtures to neutral filenames.
- Add `doctype Schema "Schema.nxscript";` to the customer subject.
- Add `doctype Validator "Validator.nxscript";` to the Schema validator.
- Keep the terminal Validator definition free of a self-doctype.
- Update the validator-side test to retrieve each validator definition from the
  compiled subject's doctype association and pass it to the unchanged
  `Validate` API.
- Retain the explicit Validator-self-validation test.

Acceptance: Customer validates with its associated Schema document; Schema
validates with its associated Validator document; Validator validates itself
explicitly; no test derives semantic meaning from any filename.

### Stage 6: Remove superseded filename semantics and verify

- Restore neutral NexusScript CLI usage text.
- Update `VALIDATION.md` and directly affected repository plan/documentation
  language to identify doctype metadata as the future consumer/tooling seam.
- Search for penultimate-extension validator discovery claims or code.
- Run clean compiler and test-module builds, the complete NexusScript suite,
  all validation/self-validation tests, and existing inForce/Storm parity.
- Create and inspect the required source archive.

Acceptance: no filename-semantic inference or extension enforcement exists;
the generic compiler contains only doctype structural/loading concepts and no
Validator, Schema, Build, Installer, or UI meaning.

## Sub-Agent Delegation

- Proposed role after approval: a `NexusScript doctype worker` owning
  `NexusTools/Script/src`, doctype fixtures, and focused tests.
- Ownership boundary: no edits to NexusSchema, NexusLS, NexusTask, Installer,
  Build, UI, or unrelated working-tree files. Validator edits are limited to
  fixture/test call sites and documentation; the engine API remains unchanged.
- Main Codex responsibilities: review parser/model/session ownership, inspect
  namespace isolation, integrate fixture changes, run full verification and
  boundary searches, and inspect the archive.
- Coordination risk: model, parser, and session changes form one tight ownership
  seam and should not be edited concurrently by separate workers.

No sub-agent is started during planning. Implementation delegation begins only
after direct human approval and only if delegation is explicitly requested or
permitted by the active agent policy.

## Verification Plan

- Parser/model tests:
  - no doctype;
  - quoted and unquoted paths;
  - name/path/range retention;
  - duplicate, misplaced, and malformed declarations.
- Session/loading tests:
  - doctype successfully compiles;
  - compiled name, declared path, canonical identity, and document pointer;
  - missing file;
  - doctype cycle;
  - mixed doctype/module cycle;
  - shared dependency cache behavior.
- Namespace tests:
  - doctype definitions unavailable to references and composition;
  - modules beside doctypes remain available;
  - doctype metadata does not participate in imported-root collisions.
- Validator-side tests:
  - subject-associated Schema document passed to `Validate`;
  - Schema-associated Validator document passed to `Validate`;
  - explicit Validator self-validation still passes;
  - invalid finite validator vocabulary still fails through the associated
    validator document.
- Regression:
  - clean `NexusScript.lpi` build;
  - clean `NexusScriptTestModule.lpi` build;
  - complete registered test suite;
  - existing module behavior;
  - inForce and Storm exact JSON/rendering parity.
- Focused searches:
  - no doctype name added to compiler symbol tables;
  - no `AddImportedDocument`/`AddImportedDefinition` call for doctype edges;
  - no filename-component semantic inference;
  - no extension enforcement;
  - no domain vocabulary in generic doctype code.
- Archive:
  - run `scripts\New-NexusSourceArchive.ps1`;
  - verify doctype source, fixtures, tests, and documentation are present;
  - verify no compiled binaries are present.

## Risks And Questions

### Compiled-document lifetime

The doctype document pointer is safe only while the compilation session owns
its compiler cache. This matches the current session-owned graph, but it must be
documented rather than hidden. Adding reference counting or independent cloned
documents would be unnecessary architecture for the current API.

### Diagnostic wording

The current loader reports module-specific text for errors generated by its
generic active-file/path mechanism. The implementation should distinguish
doctype declaration errors while using neutral document-dependency wording for
cycles shared by module and doctype edges. Diagnostic codes/messages may change
for module-cycle failures, but module behavior must not.

### `CompileText` boundary

`TNexusScriptCompiler.CompileText` has no compilation-session path loader. It
can parse and retain a doctype declaration but cannot resolve file dependencies
by itself, just as module imports require the session for full loading. Focused
parser tests may use `CompileText`; successful doctype association tests must
use `TNexusScriptCompilationSession.CompileFile`.

No Validator API change, filename rule, or broader language abstraction is
required.

## Approval Gate

This plan is a design artifact only. No doctype implementation, fixture rename,
build, test, archive, or documentation correction begins until the human owner
explicitly approves implementation.
