# Work Plan: NexusScript Document Dependencies

## Inputs

- Human-owner work-plan request supplied through
  `C:\Users\kcollins\.codex\attachments\ec9ddaa9-12ce-4e47-87f2-60e64d068c0f\pasted-text.txt`.
- Current NexusScript language contract at
  `C:\Users\kcollins\Downloads\nexus-declarative-language-contract.md`.
- Existing module and named-doctype parser/model/session implementation.
- Existing Schema artifact conversion, CLI, validation fixtures, and
  Storm/inForce parity tests under `NexusTools/Script`.
- Repository architecture protocol, NexusScript folder instructions, and
  Object Pascal standards.

## Objective

Make two focused dependency-language changes:

1. simplify doctype syntax from `doctype Name Path;` to `doctype Path;` and
   remove the unused name from every model and call site;
2. add repeatable `include Path;` header declarations that add separately
   compiled documents to the entry session's ordered artifact set without
   importing their symbols or merging compiler scopes.

The three dependency relationships remain distinct:

```text
module   -> compile and expose an explicit namespace alias
doctype  -> compile and retain one associated contract document
include  -> compile and add the document to the artifact set
```

No directive performs textual insertion. No artifact-dispatch, plugin, or
public extension architecture is introduced.

## Syntax

### Doctype

```text
doctype "Schema.Validator.nxscript";
doctype Schema.Validator.nxscript;
```

- zero or one declaration;
- one path and no name;
- top-level header syntax only;
- quoted and unquoted path handling matches module paths;
- may be interleaved with modules and includes before the first definition;
- the old `doctype Schema "Schema.Validator.nxscript";` form is invalid.

### Include

```text
include "inForceMain.nxscript";
include common.inForceMain.nxscript;
```

- zero or more declarations;
- one path per declaration;
- top-level header syntax only;
- quoted and unquoted path handling matches module and doctype paths;
- may be interleaved with modules and doctype before the first definition.

If the same physical document must supply both symbols and artifact content,
both relationships are written:

```text
module Core "Core.nxscript";
include "Core.nxscript";
```

## Verified Current State

- `TNexusScriptSourceDoctype` currently stores `Name`, `Path`, and
  `SourceRange`.
- `TNexusScriptCompiledDocument` currently stores `DoctypeName`, declared path,
  source range, canonical source name, and a non-owning compiled-document
  pointer.
- `ParseDoctype` currently requires a word name before collecting the path.
- The parser already treats module and doctype declarations as header syntax
  and diagnoses them after ordinary definitions.
- `TNexusScriptCompilationSession.CompileDocument` already supplies a
  canonical-path compiler cache and one active-file stack shared by module and
  doctype edges.
- A cached document can already be reached through more than one relationship.
- The current artifact command converts only `EntryCompiler.SourceDocument`
  and `EntryCompiler.CompiledDocument`.
- Storm parity currently compensates by loading Storm and inForce separately
  into one metadata list after compiling them in separate sessions.
- The Storm NexusScript source already module-imports inForce for references,
  but module loading alone intentionally does not add inForce metadata to the
  artifact.

## Model Changes

### Source declarations

In `obNexusScriptModel.pas`:

- remove `Name` from `TNexusScriptSourceDoctype`;
- retain only `Path` and `SourceRange`;
- add `TNexusScriptSourceInclude` with `Path` and `SourceRange`;
- add an owning ordered include list to `TNexusScriptSourceDocument`;
- initialize and free that list with the existing module and definition lists.

Includes remain source dependency declarations. They do not become definitions,
properties, aliases, or compiled members.

### Compiled doctype association

Remove `DoctypeName` from `TNexusScriptCompiledDocument` and simplify
`SetDoctype` accordingly. Retain exactly:

- declared path;
- declaration source range;
- canonical source identity;
- non-owning compiled doctype document pointer.

The pointer remains valid for the compilation session lifetime, matching the
current doctype ownership rule.

### Ordered artifact documents

Add a small generic session-owned artifact-document entry containing:

- the source document;
- its compiled document.

Expose a read-only ordered artifact-document list from
`TNexusScriptCompilationSession`. The list entries are owned by the session;
the source and compiled documents remain owned by their cached compilers.

This representation gives the artifact path the exact source/compiled pair its
existing conversion API requires without adding artifact context to every
compiled document or exposing compiler-cache internals.

## Parsing Changes

In `obNexusScriptCompiler.pas`:

- change `ParseDoctype` to collect exactly one path after the keyword;
- reject zero paths, multiple path operands, and the old named syntax;
- add `ParseInclude` using the same path-token assembly rules;
- append valid includes in declaration order;
- recognize module, doctype, and include in one header loop;
- diagnose include declarations after the first ordinary definition;
- preserve existing duplicate-doctype diagnostics;
- add deterministic include syntax/header diagnostics without renumbering
  unrelated existing diagnostics.

A tiny shared path-token collector may be extracted from the existing module
and doctype parsing only if it removes their current duplicated dot/path
assembly. It must not collapse the three declarations into a generic directive
model because their operands and semantics differ.

## Loading And Cycle Behavior

In `obNexusScriptSession.pas`, every include declaration will:

1. resolve relative to the declaring document;
2. canonicalize through the same existing filename path;
3. call the same `CompileDocument` recursion used by modules and doctype;
4. add no compiler import or namespace alias;
5. rely on the shared cache for repeated physical paths;
6. rely on the shared active-file stack for module/doctype/include cycles.

Included documents compile normally, so their own module, doctype, and include
dependencies are processed. Loading a document through module or doctype does
not itself make that document an artifact participant.

Error wrapping will identify an include relationship and declaring document
while retaining the underlying missing-file, compilation, or cycle error.

## Artifact-Set Construction And Ordering

Build the artifact set only after the entry document and its complete
dependency graph compile successfully. Derive it by traversing source include
edges, not by enumerating the compiler cache.

The exact deterministic order will be:

1. entry document first;
2. includes visited depth-first in declaration order;
3. each included document added before its own transitive includes;
4. first encounter of a canonical physical path wins;
5. later encounters of that canonical path are skipped with their subtree
   already represented by the first traversal.

This produces a stable pre-order artifact set, guarantees entry participation,
and prevents module- or doctype-only documents from leaking in merely because
they exist in the cache. It also matches the current Storm parity accumulation
order: Storm first, then included inForce.

The canonical identity set used for deduplication is separate from the ordered
artifact list. Case handling follows the compilation session's existing
canonical-path/cache behavior.

## Artifact Path Changes

Update `obNexusScriptCommand.pas` and the shared NexusScript test helper to:

- compile the entry once;
- optionally validate the entry against its doctype exactly as today;
- iterate `Session.ArtifactDocuments` in order;
- pass each source/compiled pair through the existing Schema conversion into
  the same `TMetaDataModuleList`;
- apply metadata transformation once after all artifact documents contribute;
- generate JSON and optional Mustache output once.

No Schema vocabulary enters the generic parser, model, compiler, or session.
The Schema mapping remains under `NexusTools/Script/parity` as required by the
folder instructions. `NexusTools/Schema` remains unchanged.

If any artifact document cannot be represented by the existing conversion,
the entire command fails before output rather than silently omitting that
document.

## Fixture And Contract Migration

Update all NexusScript fixtures and examples from named to path-only doctype,
including:

- Validator/Schema/Customer validation fixtures;
- CLI validation fixtures;
- doctype parser/loading/cycle fixtures;
- documentation and examples under `NexusTools/Script`;
- the authoritative language contract in Downloads;
- directly affected repository work-plan language where it describes current
  syntax rather than historical superseded syntax.

Update the contract's dependency section to define include, its non-namespace
semantics, transitive artifact participation, canonical deduplication, and the
specified artifact ordering. Preserve the decorative filename convention as
non-semantic.

Add `include "inForceMain.Schema.nxscript";` to the Storm parity fixture while
retaining its `module Core ...` declaration. The two declarations intentionally
express separate relationships.

## Implementation Stages

### Stage 1: Simplify doctype

- Remove source and compiled doctype name fields/properties.
- Change parsing to path-only syntax.
- Update session association and error wording.
- Migrate fixtures, tests, contract, and documentation.

Acceptance: path-only doctypes compile and retain path/range/canonical document
metadata; named doctypes fail; no `DoctypeName` or source-doctype `Name` remains.

### Stage 2: Add include source syntax

- Add include declaration/list ownership.
- Add parser recognition, path parsing, header ordering, and diagnostics.
- Add focused syntax tests for zero, one, many, malformed, and misplaced
  includes.

Acceptance: includes are ordered header declarations and create no source or
compiled definitions/aliases.

### Stage 3: Load include dependencies

- Traverse direct include declarations during document compilation.
- Reuse canonical cache and active dependency stack.
- Add missing-file, compilation-failure, direct cycle, transitive cycle, and
  mixed-edge cycle coverage.

Acceptance: all dependency edges terminate through one deterministic cycle
system and includes never call `AddImportedDocument` or
`AddImportedDefinition`.

### Stage 4: Build the ordered artifact set

- Add session-owned artifact entries/list.
- Build entry-first depth-first pre-order from include declarations.
- Deduplicate by canonical physical identity.
- Expose the completed list only after successful entry compilation.
- Clear prior artifact state before each public `CompileFile` call.

Acceptance: entry is always first; transitive includes follow declaration
order; duplicate paths participate once; module/doctype-only documents do not
participate.

### Stage 5: Aggregate artifact conversion

- Iterate the session artifact list in the CLI and parity helper.
- Accumulate all documents before the single transformation/JSON/render pass.
- Convert Storm parity to one include-driven compile/conversion call.

Acceptance: Storm/inForce exact JSON and Mustache parity pass without manually
loading inForce after Storm.

### Stage 6: Full verification and archive

- Run focused syntax, loading, namespace-isolation, artifact ordering, CLI, and
  parity tests.
- Run clean NexusScript executable and test-module builds.
- Run the complete registered NexusScript suite.
- Run boundary searches for removed names and prohibited include behavior.
- Create and inspect the required source archive.

Acceptance: all tests pass; generic/domain boundaries remain intact; archive
contains the implementation and fixtures without compiled binaries.

## Test Plan

### Doctype

- no doctype;
- quoted and unquoted path-only doctype;
- declared path, range, canonical identity, and compiled pointer retention;
- old named doctype rejected;
- duplicate doctype rejected;
- malformed and misplaced doctype rejected;
- doctype remains invisible to references and absent from artifact documents.

### Include syntax and loading

- one include;
- multiple includes in declaration order;
- quoted and unquoted include paths;
- malformed and misplaced includes;
- transitive includes;
- missing included file;
- invalid included document;
- direct include cycle;
- transitive include cycle;
- mixed module/include/doctype cycles;
- repeated canonical paths compile once and participate once.

### Relationship isolation

- included definitions are unresolved without a module alias;
- module-only documents do not enter the artifact set;
- doctype-only documents do not enter the artifact set;
- the same physical document may be both module-imported and included;
- matching paths across different relationship types share the compiler cache
  without sharing semantics;
- an included document's transitive includes participate;
- an included document's modules and doctype do not participate unless reached
  separately through include.

### Artifact ordering and output

- entry always occupies index zero;
- depth-first declaration-order traversal is exact;
- first canonical occurrence wins duplicate participation;
- multiple artifact documents accumulate into one metadata list;
- transformation runs once after accumulation;
- unsupported included artifact document fails the command;
- stdout and file behavior remain unchanged;
- Storm/inForce exact JSON parity passes from the Storm input alone;
- existing Mustache parity remains exact.

### Regression

- existing reference, composition, array, module, and validation tests;
- doctype validation through the CLI;
- CLI JSON/template/output/error tests;
- Validator self-validation and finite-value tests;
- inForce standalone parity;
- clean `NexusScript.lpi` build;
- clean `NexusScriptTestModule.lpi` build;
- complete registered suite.

## Focused Verification Searches

- no `DoctypeName`, source-doctype `Name`, or named doctype fixture remains;
- no include path is added to symbol tables or compiler imports;
- no include source text is concatenated or reparsed into the parent;
- no artifact set is built by enumerating every cached compiler;
- no module or doctype edge implicitly adds artifact participation;
- no duplicate Schema mapping or metadata transformation loop;
- no Schema vocabulary added to generic compiler/session units;
- no filename-component semantics introduced.

## Genuine Ambiguities And Decisions

### Artifact order

The request requires deterministic ordering but does not state a traversal
order. This plan proposes entry-first, depth-first pre-order in include
declaration order, deduplicated on first canonical encounter. Artifact order is
observable in generated metadata/JSON, so this rule should be treated as part
of the approved behavior rather than an incidental container detail.

### Root `include` definition kind

The current generic grammar permits arbitrary words as definition kinds, so a
root definition written `include Name {}` is currently syntactically possible.
Recognizing `include` as a root header keyword reserves that spelling in the
top-level declaration position. Nested definitions with kind `include` remain
ordinary definitions because header declarations are recognized only at the
document root. This is the smallest unavoidable grammar conflict introduced by
the requested syntax.

No other contract conflict was found. Path-only doctype removes metadata that
has no namespace or loading function, and include can remain fully orthogonal
to module and doctype.

## Explicitly Out Of Scope

- Textual source insertion or macro processing.
- Making included definitions referenceable without a module.
- Merging included definitions into the entry compiler scope.
- Making modules or doctypes implicit artifact participants.
- Automatic validation caused by doctype or include.
- Artifact selection, plugin discovery, DLL interfaces, or public extension
  standards.
- Filename-based dependency or validator inference.
- Changes to metadata transformation semantics, Mustache semantics, or
  `NexusTools/Schema`.
- Legacy NexusSchema data-source batch generation.

## Sub-Agent Plan

No delegation is requested for planning. If implementation is later approved
and delegation is explicitly requested, one bounded NexusScript dependency
worker may own parser/model/session changes and focused fixtures. Main Codex
will retain artifact-path integration, contract review, complete regression
verification, and archive inspection.

## Approval Gate

This is a work plan only. It authorizes no implementation edits, builds, tests,
executable runs, archive creation, or other implementation activity.
Implementation begins only after direct human-owner approval.
