# Work Plan: NexusScript Language Server

## Inputs

- Source design: `C:\Users\kcollins\Downloads\nexusscript-language-server-design-revised.md`.
- Related discussion:
  - NexusScriptLS is the dedicated editor-facing server for NexusScript; Pascal NexusLS remains separate.
  - NexusScript core remains the sole parser, compiler, dialect-normalization, validation, Target, reference, composition, and provenance implementation.
  - Every compilation session must use one source-access provider. The ordinary default is filesystem-backed; NexusScriptLS supplies an overlay provider.
  - Failed analysis must remain available as a core-owned result rather than being reduced to one error string or discarded.
  - Semantic node identity is exact within one analysis/document version, not guaranteed across refreshes.
  - Custom JSON-RPC contracts are Pascal classes with published RTTI properties. JSON is only their serialized wire form.
- Existing constraints:
  - `.ai/protocols/architecture-change.md`, `.ai/protocols/codex-workplan-format.md`, root `AGENTS.md`, `NexusTools/Script/AGENTS.md`, and `.ai/standards/pascal.md` apply.
  - No implementation is authorized by this plan.
  - No sub-agent use is authorized.
  - No new product thread is justified. Analysis remains on the language-server execution path unless a concrete blocking boundary is separately demonstrated and approved.
  - Current NexusScript CLI, artifact generation, dialect validation, dependency behavior, Target filtering, and current Pascal NexusLS behavior must remain intact.

## Summary

Complete the existing NexusScriptLS shell by putting three reusable capabilities into NexusScript core first:

1. one universal source-access boundary used by every compilation session;
2. one core-owned analysis result that preserves source, diagnostics, dependency state, and any compiled result on both success and failure;
3. precise parser-owned source ranges for the individual language elements required by editor operations.

NexusScriptLS will then consume those capabilities to provide live diagnostics, symbols, dialect-driven completion, hover, navigation, references, rename, typed semantic models, and narrow semantic source edits. The Nexus Pascal VS Code extension will run NexusScriptLS as a second independent language client and integrate each feature as it becomes available.

The LS adds protocol and editor state around NexusScript. It does not reinterpret NexusScript and does not become a second compiler.

## Verified Findings

- `NexusTools/Script/ls/NexusScriptLS.lpr` already creates a dedicated server using shared `NexusLib/lsp` transport and dispatch infrastructure.
- `TNexusScriptLSModel` currently owns only lifecycle flags and a list of open URI/language/version/text records.
- NexusScriptLS currently registers only lifecycle and full-text document synchronization requests and truthfully advertises only those capabilities.
- Focused shell tests already cover initialize, initialized, open, full-text change, save, close, shutdown, exit, and invalid document lifecycle operations.
- `TNexusScriptCompilationSession` currently performs direct filesystem canonicalization, existence checks, reads, and wildcard/recursive enumeration.
- The session calls `TNexusScriptCompiler.CompileFile` twice for a source involved in dependency loading: once to discover declarations and again after imports are installed.
- A compiler that fails final session compilation is not added to `FCompilers` and is freed by `CompileDocument`; the session primarily exposes `LastError` for that failure.
- `TNexusScriptCompiler.CompileText` retains a source document and diagnostics, but the session lifetime above prevents the LS from reliably owning those failed artifacts.
- Source definitions, properties, values, modules, includes, dialect declarations, and Targets generally retain broad object-level ranges. They do not retain all distinct token ranges required for precise selection, reference-segment navigation, rename, and narrow editing.
- The normalized dialect model already exists publicly in `obNexusScriptLanguageDefinition.pas`; the validator consumes that model. NexusScriptLS can reuse it without interpreting dialect files independently.
- Shared typed LSP DTOs, JSON-RPC dispatch, outbound request support, and transport hosting already live under `NexusLib/lsp`.
- The Nexus Pascal extension currently launches one Pascal-only language client whose document selector contains only `objectpascal` and `pascal`. It does not register a `nexusscript` language or launch NexusScriptLS.
- Current Nexus deployment scripts stage `nexusls`; they do not yet stage or expose NexusScriptLS to the extension.
- The Nexus worktree contains unrelated in-progress Schema dialect relocation changes. Implementation and plan commits must not absorb, revert, or rewrite those changes.

## Architecture Problem

The compiler contains the correct NexusScript semantics, but its current session boundary assumes complete physical files and treats a failed dependency/compilation as a failed call whose detailed working state may disappear. The source model also lacks several token-specific ranges needed by an editor.

Building editor behavior directly around those limitations would create invalid compensating systems:

- an LS-only parser or text scanner for completion, navigation, and rename;
- duplicated filesystem/session behavior for open buffers;
- guessed source identity based on names;
- free-form JSON semantic models;
- whole-document regeneration for semantic edits;
- persistent node-identity reconciliation across analyses;
- or a second semantic interpretation in TypeScript.

The correction belongs at the existing ownership boundaries: source access, analysis ownership, and source metadata become reusable NexusScript-core capabilities; NexusScriptLS translates those authoritative results into typed LSP behavior.

## Target Contract

### Dependency direction

```text
NexusScript core
    source provider + parser/compiler/session + analysis result
    dialect normalization + validation + provenance
                         ↑
                    NexusScriptLS
                         ↑
          Nexus Pascal VS Code extension
             NexusScript language client
```

`NexusLib/lsp` remains the language-neutral JSON-RPC/LSP layer used by both dedicated servers. Pascal NexusLS and NexusScriptLS do not consume one another.

### Universal source access

- Owner: NexusScript core.
- Every `TNexusScriptCompilationSession` receives a source-access provider and uses it for all semantic source access.
- A session created without an explicit provider owns/uses the standard filesystem provider, preserving normal CLI and artifact behavior.
- The provider owns these operations:
  - canonical document identity;
  - existence/availability;
  - exact source text and optional version;
  - wildcard and recursive enumeration.
- The session retains NexusScript path resolution, dependency traversal, cycle detection, dialect-root policy, imports, includes, and semantic compilation. The provider supplies source facts; it does not compile NexusScript.
- The filesystem provider preserves existing discovery behavior and ordering.
- The LS overlay provider checks its open-document overlay first and delegates to a filesystem provider otherwise.
- An overlay source shadows the backing source with the same canonical identity.
- Backing matches retain their original order. Overlay shadowing must not reorder them, and overlay-only matches must not introduce an unrelated global sort.
- Discovery removes duplicate canonical identities and excludes the declaring document itself by identity, not merely by textual path spelling.
- File identity follows the host filesystem's path semantics. NexusScript language identifiers remain independently case-sensitive.
- A new unsaved document can participate in path-based dependencies/discovery only when it has a filesystem-resolvable URI. An `untitled:` buffer without a path may receive local syntax analysis but cannot resolve relative filesystem dependencies until it acquires a file identity.

### Core-owned analysis result

- Owner: NexusScript core, not NexusScriptLS.
- An analysis owns the compilation session and every successful or failed compiler/source attempt required to keep returned pointers and provenance valid.
- Failure is recorded as result state; it does not remove the attempted source model or diagnostics.
- The result exposes, where available:
  - entry identity and analysis revision;
  - attempted documents and their source versions;
  - partial/recoverable source documents;
  - compiler/parser diagnostics;
  - dependency/discovery failures and dependency relationships;
  - normalized dialect and its diagnostics;
  - validation diagnostics;
  - compiled documents;
  - resolved references and provenance.
- The LS consumes this model directly and maps it to protocol DTOs. It does not copy semantic data into a second internal interpretation.

### Precise source metadata

- Owner: NexusScript parser/source model.
- Preserve existing broad ranges and add distinct ranges for:
  - definition kind and definition name;
  - property name and property value/expression;
  - each component of a reference path;
  - module alias, path, and root selector;
  - include path;
  - dialect path;
  - Target kind and each Target value;
  - other tokens only when an implemented editor operation proves they are required.
- Compiler and compiled-model provenance retains the exact source association needed to reach these ranges.
- NexusScriptLS never reparses or searches source text to manufacture missing semantic spans.

### NexusScriptLS analysis ownership

- Owner: `TNexusScriptLSModel` and NexusScriptLS-owned model/service units.
- The model owns open documents, the overlay provider, current per-entry analyses, dependency relationships, and the active workspace Target selection.
- Document lifecycle changes update the overlay, invalidate affected analyses, reanalyze synchronously through existing ownership, and publish current diagnostics.
- Closing a shadowing document removes it from the overlay; the backing filesystem source becomes visible again if it exists.
- Changes to a known dependency reanalyze affected open entry documents. VS Code file-change notifications may report changes outside open buffers; NexusScriptLS does not create its own watcher thread.
- Reanalysis replaces the prior owned analysis result only after the new result has been produced and mapped. Diagnostic publication also clears diagnostics that no longer exist.

### Target context

- Untargeted compilation is the default and retains canonical compiler behavior, including duplicate diagnostics when same-identity Target variants survive together.
- A client may provide one optional workspace-level multidimensional Target selection.
- Target kind names and values remain free-form and case-sensitive. NexusScriptLS does not hard-code `Platform`, `Architecture`, `Target`, or any other dimension.
- The selection is immutable during one analysis.
- Changing or clearing it invalidates and rebuilds affected open-document analyses.
- Per-document Target selection is not part of this implementation.

### Standard language features

- Diagnostics come only from core parser/compiler/session/dialect/validator results and are published against the document where each problem originates.
- Document symbols describe source declarations, not compiled-only inherited material.
- Completion derives legal members, child kinds, scalar values, arrays, and reference candidates from syntax context plus the normalized dialect model.
- Hover and navigation use resolved semantic objects, exact source association, and provenance.
- References initially cover documents present in the current owned analysis set.
- Rename is introduced only after navigation/reference identity is proven and operates on resolved identities and precise ranges, never textual replacement.

### Typed custom protocol

- Owner: NexusScriptLS Pascal protocol units.
- `nexusscript/documentModel`, `nexusscript/dialectModel`, Target-context operations, and semantic-edit operations use concrete Pascal request/result classes with published RTTI properties.
- The Pascal classes are the data contract. JSON is generated/consumed by the existing RTTI JSON-RPC machinery.
- TypeScript declares matching transport types but does not reinterpret dialects or invent untyped semantic fields.
- Protocol DTOs contain data only. Compiler, validation, and edit policy remain in NexusScript core/NexusScriptLS services.

### Analysis-scoped semantic identity and edits

- Node IDs are opaque and exact only within the analysis/document version that produced them.
- Node IDs distinguish semantic occurrences, including repeated projections of
  the same inherited source member under different compiled receivers.
- Provenance `winner` identifies replacement semantics. Additive composition
  retains all contributors and intentionally has no single winner.
- “Exact source identity” means exact ownership and provenance within that analysis; it is not a promise that an ID survives refresh.
- Every node-addressed request carries the analysis/document version.
- A stale version is rejected; the client refreshes its document model before retrying.
- Semantic operations produce the narrowest practical standard text/workspace edits around parser-owned ranges.
- The LS never regenerates the whole source document from the compiled or semantic model.
- Comments and unrelated formatting remain untouched.
- An operation that cannot be expressed safely with available ranges is rejected until the core source model supplies the necessary range.

### VS Code client

- Owner: `C:\gitdev\tools\nexus-pascal`.
- Register one `nexusscript` language ID for `.nxscript`; dialects do not become VS Code language IDs.
- Launch and own a second `LanguageClient` for NexusScriptLS, independent of the Pascal client and its project/toolchain services.
- Discover NexusScriptLS through the installed Nexus toolchain/deployment contract rather than a developer-machine hard-coded path.
- Add capabilities to the client/server only as the corresponding stage becomes functional.
- Integrate standard features through LSP and custom semantic features through the typed NexusScript protocol.

## Scope

### Nexus repository

- `NexusTools/Script/core/obNexusScriptSession.pas`
- `NexusTools/Script/core/obNexusScriptCompiler.pas`
- `NexusTools/Script/core/obNexusScriptModel.pas`
- `NexusTools/Script/core/obNexusScriptLanguageDefinition.pas` only where read-only model access needed by the LS is missing
- New narrowly owned NexusScript core source-provider and analysis-result object units
- `NexusTools/Script/ls/src/model/*`
- New `NexusTools/Script/ls/src/service/*` units for analysis and individual language features
- `NexusTools/Script/ls/src/protocol/*`
- `NexusTools/Script/ls/NexusScriptLS.lpr` and project search/unit entries
- `NexusTools/Script/ls/tests/*`
- `NexusTools/Script/tests/*` for source-provider, analysis-result, parser-range, and unchanged compiler/session behavior
- `NexusLib/lsp` protocol DTOs only when a required standard LSP type is genuinely absent
- Nexus staging/deployment scripts needed to install NexusScriptLS beside NexusLS

### Nexus Pascal extension repository

- `package.json` language/grammar/activation contributions for `nexusscript`
- a generic NexusScript TextMate grammar for lexical presentation only; it must not encode dialect semantics
- dedicated NexusScriptLS client lifecycle, executable discovery, selectors, capabilities, Target context, and custom request types
- extension tests/build wiring needed to prove independent Pascal/NexusScript clients

## Out Of Scope

- Moving NexusScript core into `NexusLib`
- Adding NexusScript behavior to Pascal NexusLS
- Combining both languages into one server process or one language client
- Reinterpreting NexusScript or its dialects in TypeScript
- Separate VS Code language IDs or clients for individual dialects
- Presentation metadata such as widget, icon, color, or editor-control declarations in dialect files
- A workflow engine, generalized project database, or speculative incremental compiler
- Persistent semantic node IDs or cross-refresh identity reconciliation
- Whole-document source regeneration or a formatting engine
- A second LS parser, regex parser, or heuristic name/reference scanner
- Per-document Target selection
- An LS-owned filesystem watcher thread
- Any new product thread without a separately reviewed blocking justification
- Refactoring Pascal NexusLS services or protocol implementations except the minimum extension composition needed for the independent client
- Implementing the future structured/GUI editor itself
- Unrelated NexusScript language, dialect, artifact, or CLI changes

## Staged Implementation Plan

### Stage 1 — Universal source-access boundary

1. Add one NexusScript-core source-provider contract and filesystem implementation.
2. Make every `TNexusScriptCompilationSession` use a provider; construct/own the filesystem provider by default when none is supplied.
3. Route canonicalization, existence, reading, dialect lookup, dependency lookup, and pattern enumeration through the provider.
4. Preserve existing CLI/session path resolution and discovery ordering.
5. Add the NexusScriptLS overlay provider over the filesystem provider, using canonical file identities and the existing open-document lifecycle.
6. Support shadowing, backing fallback, file-identified unsaved dependencies, overlay-aware discovery, declaring-document self-exclusion, and duplicate-identity removal without introducing a global sort.

Acceptance:

- Existing CLI/session tests retain their behavior through the default provider.
- Open text overrides disk text.
- A newly opened file-identified unsaved document can be resolved directly and through wildcard/recursive discovery.
- Closing an overlay restores the backing source or removes the source when no backing document exists.

### Stage 2 — Core-owned analysis result and precise ranges

1. Introduce one core-owned analysis/result model that owns the session and attempted compiler artifacts through result lifetime.
2. Reshape session compilation so failed documents remain inspectable with their partial source and diagnostics.
3. Record dependency/discovery failures against the source operation that produced them rather than exposing only one flattened `LastError`.
4. Add precise token ranges to source declarations and populate them in the existing parser.
5. Preserve exact source associations through compiled provenance without weakening the established clone/transfer ownership rules.
6. Add only the parser recovery needed to retain useful structure after common incomplete-edit states; do not build a second parser or general error-recovery framework.

Acceptance:

- Success and failure both return owned analysis results.
- A failed parse/compile retains available source structure, exact diagnostics, source versions, and dependency relationships.
- All enumerated language tokens have tested precise ranges.
- Existing compilation, composition, imports, references, Targets, provenance, dialect validation, CLI, and artifact tests remain valid.

### Stage 3 — Live diagnostics and baseline extension integration

1. Add a NexusScriptLS analysis service owning per-entry results.
2. Reanalyze the complete open-document set on open/change/save/close. This is
   the intentional initial invalidation rule; a reverse dependency map is
   deferred until measured workspace scale demonstrates that it is needed.
3. Publish parser, compiler, dependency, dialect-normalization, and validation diagnostics using canonical source ranges.
4. Clear stale diagnostics when an error disappears, an analysis stops owning a diagnostic, or an open source closes.
5. Register `.nxscript`/`nexusscript` in the Nexus Pascal extension with a generic syntax grammar.
6. Stage/discover NexusScriptLS beside NexusLS and launch it through a dedicated extension client.
7. Keep the Pascal client's lifecycle, selectors, and services independent.

Acceptance:

- Editing unsaved NexusScript produces current diagnostics without saving.
- Dependency diagnostics are published on the originating document and dependent entries reanalyze when the dependency changes.
- VS Code launches NexusScriptLS only for the `nexusscript` selector and Pascal documents remain owned by NexusLS.

### Stage 4 — Recoverable source structure and document symbols

1. Retain useful source declarations during representative incomplete edits.
2. Implement typed document-symbol requests from the source model.
3. Use the broad declaration range and precise name selection range.
4. Preserve source nesting and omit compiled-only inherited declarations from the source outline.
5. Wire and advertise document symbols in the extension/server.

Acceptance:

- Symbols remain useful for valid and representative incomplete documents.
- Symbol ranges and selection ranges point to the correct source tokens.

### Stage 5 — Dialect-driven completion

1. Determine source syntax position and enclosing source definition from the existing parser/source model.
2. Consume the normalized dialect model for legal properties, child kinds, scalar values, arrays, requiredness priority, and reference constraints.
3. Resolve reference and module candidates through the active analysis and selected Target context.
4. Provide useful syntax-local completion when semantic compilation is temporarily unavailable.
5. Wire and advertise completion end to end.

Acceptance:

- Completion choices change with dialect, source location, scope, and Target context without TypeScript or LS hard-coded dialect vocabulary.

### Stage 6 — Hover and navigation

1. Implement hover for declarations, effective/local values, Target applicability, reference targets, and provenance where available.
2. Implement declaration/definition navigation for references, composition selectors, module dependencies/selectors, includes, and dialect declarations.
3. Resolve destinations from semantic identity and exact source associations, never ambiguous name-only source recovery.
4. Wire and advertise each implemented capability end to end.

Acceptance:

- Cross-document and local navigation reaches exact tokens, including same-name targeted source alternatives after selection.

### Stage 7 — References and rename

1. Enumerate references from resolved identities in the current analysis/dependency set.
2. Implement document highlights from the same identity path where appropriate.
3. Implement rename only for identities whose complete affected source set is known.
4. Produce precise workspace edits for declaration names and qualified reference components.
5. Reject ambiguous, incomplete, or stale rename requests rather than performing string replacement.

Acceptance:

- References and rename operate across analyzed files and do not modify same-spelled unrelated identifiers.

### Stage 8 — Typed semantic document and dialect APIs

1. Define NexusScript-owned Pascal RTTI DTOs for document model, dialect model, provenance/effective state, allowed operations, and workspace Target selection.
2. Add typed request/result classes and matching TypeScript transport types.
3. Generate opaque node IDs within each owned analysis and include the analysis/document version in returned models.
4. Reject all node-addressed operations whose version does not match the current analysis.
5. Expose semantic constraints without presentation/widget metadata.

Acceptance:

- Protocol round-trip tests prove the published Pascal object graph is the serialized contract.
- The client obtains a complete generic semantic model without loading or interpreting dialect source itself.

### Stage 9 — Narrow semantic edit API

1. Implement the smallest useful semantic operations: add/remove child, set/remove local property, set reference, rename, create override, and reset/remove override.
2. Convert each operation into versioned standard text/workspace edits around precise parser-owned ranges.
3. Preserve surrounding comments and unrelated formatting.
4. Reject operations that cannot be expressed safely; add a missing core range only when that concrete operation requires it.
5. Keep composition/override meaning in NexusScript core and LS services, not the client.

Acceptance:

- Focused tests prove surgical edits, inherited override behavior, reset behavior, formatting/comment preservation, and stale-request rejection.

### Stage 10 — Structured-editor readiness and final integration

1. Exercise the typed document/dialect models, allowed operations, provenance, Target changes, reanalysis, and semantic edits through the extension client.
2. Verify that text edits and semantic edits operate on the same VS Code document and analysis version.
3. Confirm that no GUI-specific presentation policy has leaked into dialects or the server.
4. Confirm deployment contains both independent language-server executables and the extension resolves each through the installed toolchain contract.

Acceptance:

- The extension exposes a stable server contract sufficient for a later structured editor while ordinary `.nxscript` text editing is fully functional.

## Sub-Agent Delegation

No sub-agent use is authorized. Plan approval or implementation approval does not authorize delegation. Implementation remains with the primary Codex unless the human owner explicitly requests sub-agent use in a later message.

## Verification Plan

### Nexus core and server builds

- Build `NexusTools/Script/NexusScript.lpi`.
- Build `NexusTools/Script/ls/NexusScriptLS.lpi`.
- Build the existing Pascal `NexusTools/LS/nexusls.lpi` after any shared LSP DTO additions.
- Compile frequently after each structural stage rather than deferring integration until the end.

### Registered Pascal test modules

- Run `NexusTools/Script/tests/NexusScriptTestModule.lpi` for unchanged compiler/session/CLI/artifact behavior plus source-provider, analysis-result, parser-range, dependency, dialect, reference, composition, and Target coverage.
- Run `NexusTools/Script/ls/tests/NexusScriptLSTestModule.lpi` for document lifecycle, overlay behavior, diagnostics, symbols, completion, navigation, references, rename, typed custom requests, Target contexts, and semantic edits.
- Run `NexusLib/lsp/tests/NexusLSPTestModule.lpi` when shared standard LSP DTOs or transport behavior change.
- Run `NexusTools/LS/NexusLSTestModule/NexusLSTestModule.lpi` when shared LSP types or extension/server coexistence can affect Pascal NexusLS.
- Use the repository unit-test framework only; do not create standalone test harnesses.

### Extension verification

- Run `npm.cmd run compile` in `C:\gitdev\tools\nexus-pascal` after TypeScript changes.
- Run `npm.cmd run esbuild` when bundled runtime behavior changes.
- Add automated extension/client tests for language registration, executable selection, independent client lifecycles, selectors, and typed custom requests.

### Focused source checks

- No direct `FileExists`, `LoadFromFile`, `FindFirst`, or equivalent source access remains in compilation-session paths that must use the provider.
- No NexusScriptLS code reparses source or interprets dialect rules independently.
- No custom semantic protocol request/result is assembled as free-form JSON.
- No rename or semantic edit uses string-wide replacement or whole-document regeneration.
- No new thread, polling loop, deadline worker, or LS-owned filesystem watcher is introduced.
- No NexusScriptLS unit imports Pascal NexusLS application/service/parser units, and the Pascal client selector does not claim `nexusscript`.

### Manual end-to-end verification

- Open a saved NexusScript file, change it without saving, and observe current diagnostics and symbols.
- Open a new file-identified unsaved dependency and verify direct and wildcard/module discovery uses it.
- Introduce and correct a dependency error and confirm originating and dependent diagnostics update/clear.
- Verify dialect-driven completion in at least the foundational Language dialect and two production dialects from the common catalog.
- Navigate local and cross-document references, composition selectors, modules/includes, and dialect paths.
- Exercise same-name Target alternatives in untargeted and explicitly targeted workspace contexts.
- Rename one resolved definition and verify unrelated same-spelled names remain unchanged.
- Request a semantic model, modify the document, and confirm the stale model cannot apply an edit.
- Apply property/child/override/reset edits and confirm surrounding comments and formatting survive.
- Open Pascal and NexusScript files together and confirm the two dedicated clients operate independently.

## Risks And Questions

- Parser recovery must make forward progress at end-of-file and malformed constructs without turning the parser into a separate generalized recovery architecture.
- The analysis result must preserve compiler/source lifetimes without cloning semantic graphs or retaining pointers beyond their owners.
- File URI conversion and canonical identity must remain correct across Windows and Linux while language identifiers remain case-sensitive.
- Overlay discovery must preserve existing backing-provider order and avoid duplicate identities without adding a global sorting policy.
- A file without a filesystem-resolvable URI cannot participate in relative path semantics; local syntax analysis is the only meaningful pre-save behavior for such a buffer.
- Rename must remain unavailable when the server cannot prove it has the complete affected identity set.
- The exact typed request name and persistence source for workspace Target selection may follow existing extension configuration conventions during implementation, but the semantic rule in this plan is fixed: one optional workspace selection, untargeted by default.
- NexusScriptLS executable staging must integrate with the existing installed-toolchain contract without hard-coded development paths or coupling it to the Pascal server process.
- No unresolved question currently requires a design decision before implementation authorization.

## Approval Gate

This document is a work plan only. It authorizes no implementation, build, test, launch, archive, or sub-agent activity. Implementation begins only after the human owner explicitly approves it.
