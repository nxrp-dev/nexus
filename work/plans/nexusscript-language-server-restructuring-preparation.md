# Work Plan: NexusScript Language Server Restructuring Preparation

## Inputs

- Source request: the owner-provided `nexusscript-language-server-restructuring-preparation.md`, supplied from `C:\Users\kcollins\Downloads`, including its required final ownership contract, in-scope restructuring, exclusions, verification requirements, and required plan filename.
- Related discussion/review notes:
  - NexusScript will use a dedicated `NexusScriptLS` process rather than extending the Pascal-oriented `NexusLS` process.
  - NexusScript dialects will eventually be selected by explicit `doctype` under one `nexusscript` editor language ID, but dialect-aware editor behavior is not part of this pass.
  - The NexusScript engine remains owned by `NexusTools/Script`; it is not moved into `NexusLib` merely because the CLI and dedicated language server both consume it.
  - Only verified language-neutral LSP protocol and process infrastructure is shared. Pascal and NexusScript analysis, documents, requests, services, and indexes remain server-owned.
- Existing constraints:
  - `.ai/protocols/architecture-change.md` and `.ai/protocols/codex-workplan-format.md` require a planning-only pass, exactly one matching plan, an explicit approval gate, and a committed/pushed planning artifact.
  - `.ai/protocols/subagents.md` forbids implementation delegation before approval and requires non-overlapping ownership when approved work is delegated.
  - Root and folder `AGENTS.md` rules require narrow changes, Pascal standards, explicit ownership, removal of obsolete abstractions instead of compatibility layers, and no Schema vocabulary in the NexusScript language engine.
  - Current NexusScript CLI/artifact behavior and current Pascal NexusLS behavior must survive the reorganization.
  - Planning inspection was performed at repository commit `9e83b6c1ca3dcf30eee5ff7181e4628508225ab3`, which matched `origin/main` when inspected.

## Summary

Perform one complete physical restructuring that establishes three real ownership boundaries before NexusScript editor intelligence is developed:

1. Reorganize `NexusTools/Script` into a language core, artifact production, CLI front end, and dedicated language-server front end.
2. Move the verified language-neutral LSP protocol and process units from the Pascal server into a shared `NexusLib/lsp` area, separating Nexus-specific project/toolchain protocol extensions and all concrete request execution from the shared layer.
3. Create a minimal compilable `NexusScriptLS` executable that owns its lifecycle and document shell, consumes NexusScript core plus shared LSP infrastructure, and contains no editor-intelligence implementation.

The pass is complete only after the old source locations and obsolete search paths are removed and focused dependency checks prove that neither server nor NexusScript front end consumes another front end's application code.

## Verified Findings

### NexusScript ownership and coupling

- `NexusTools/Script/src/tpNexusScript.pas` owns source positions/ranges and language value/evaluation types, but it also owns `TNexusScriptArtifactValueKind`, an output-facing type used only by artifact consumers.
- `NexusTools/Script/src/obNexusScriptModel.pas` combines source and compiled language models with artifact-facing conveniences:
  - `TNexusScriptExternalSource` and its list describe resolved external artifact inputs;
  - `TNexusScriptCompiledValue.ArtifactKind` and `ArtifactValue` project compiled values for output consumers.
- `NexusTools/Script/src/obNexusScriptCompiler.pas` contains tokenization, parsing, compilation, reference/composition resolution, and diagnostics. The tokenizer and parser are private implementation types in this unit; this restructuring does not require changing that parser boundary.
- `NexusTools/Script/src/obNexusScriptSession.pas` mixes two ownership areas:
  - core recursive compilation and dependency resolution for `doctype`, `module`, and `include`;
  - artifact traversal and external-source collection through `TNexusScriptArtifactDocument`, `ArtifactDocuments`, `ExternalSources`, `BuildArtifactDocuments`, `BuildExternalSources`, and external-source path resolution.
- `TNexusScriptCompilationSession` caches compilers internally in `FCompilers`, but it does not expose a read-only compiled-document enumeration suitable for an artifact consumer after artifact collection is removed.
- `NexusTools/Script/validator/obNexusScriptValidator.pas` exposes only `TNexusScriptValidator`; all normalized language rule types and all normalization methods are private implementation details of `TNSValidatorEngine`.
- `NexusTools/Script/src/obNexusScriptJSON.pas` and `obNexusScriptExternalSource.pas` are artifact producers even though they currently reside in the general `src` folder.
- Manifest interpretation, model-session orchestration, Mustache rendering, output-path policy, and external-source render selection are concentrated in `NexusTools/Script/cli/obNexusScriptCommand.pas` rather than separated from CLI argument handling.
- `NexusTools/Script/validator/NexusManifest.Language.nxscript` is a manifest-specific production language definition referenced by manifest fixtures and parity manifests. The remaining files under `validator/fixtures` are validation tests.
- `NexusTools/Script/NexusScript.lpi` searches `src;cli;validator` and names the current units directly. Its declared unit count is stale relative to the listed unit indexes. `tests/NexusScriptTestModule.lpi` has the same stale-count problem and the same old paths.
- `NexusTools/Script/tests/tsNexusScriptTests.pas` contains direct helpers and assertions for the current `validator`, `src`, artifact-document, and external-source locations. The parity manifest doctypes also contain direct relative references to `validator/NexusManifest.Language.nxscript`.

### Shared LSP candidates and Pascal ownership

- JSON values, typed JSON-RPC objects/messages, and the class factory already live in `NexusLib/core/src`.
- These current units are language-neutral in responsibility, although some require small dependency-injection cleanup before sharing:
  - `NexusTools/LS/src/tpNXLS.pas`;
  - `obNXLSLogger.pas`;
  - `obNXLSTransport.pas`, `obNXLSStdIOTransport.pas`, `obNXLSTcpIPTransport.pas`, and `obNXLSTransportFactory.pas`;
  - `obNXLSOutboundDispatcher.pas`;
  - `obNXLSDispatcher.pas` after removing its implementation dependency on `obNXLSAllRequests`;
  - `obNXLSServer.pas` after removing construction and global installation of `TNXLSLSPModel`;
  - `protocol/obNXLSProtocolBase.pas`, `obNXLSDocumentSyncParams.pas`, and the standard-LSP portions of `obNXLSProtocolParams.pas` and `obNXLSProtocolObjects.pas`.
- `obNXLSProtocolParams.pas` is not currently purely standard LSP. It also defines Nexus/Pascal-server command parameters for complete-code, invert-assignment, remove-empty-methods, remove-unused-units, project creation, and toolchain configuration.
- `obNXLSProtocolObjects.pas` similarly mixes standard LSP values with Nexus project and toolchain request/result objects.
- `obNXLSDispatcher.pas` is otherwise generic JSON-RPC dispatch, but imports `obNXLSAllRequests` solely to force registration of the Pascal server's request set.
- `obNXLSServer.pas` owns a concrete `TNXLSLSPModel`, creates it internally, sets `TNXLSLSPModel.Current`, routes responses to it, and logs a hard-coded Pascal server name. It is therefore not shareable without an injected application/response boundary.
- `obNXLSTcpIPTransport.pas` is language-neutral transport code but depends on shared command-line settings, Synapse sockets, and the current logger. Those dependencies must remain explicit in both server projects after the move.
- Every unit under `NexusTools/LS/src/parser`, `src/service`, and `src/toolchain` remains Pascal NexusLS application code. In particular, `obNXLSServiceContext.pas` embeds `TNXPasLanguageContext`, Pascal search paths and unit resolution in its abstract context, and also contains the Pascal server's document implementation.
- `obNXLSLSPModel.pas` directly owns `TNXPasLanguageContext`, Pascal configuration, Pascal analysis/reindexing, and all current services.
- Request units under `NexusTools/LS/src/protocol` are concrete command implementations. Several call `TNXLSLSPModel.Current` directly; others encode the Pascal server's currently implemented or rejected method behavior. They are not shared protocol DTOs and will remain Pascal-server owned.
- `NexusTools/LS/nexusls.lpi` and `NexusLSTestModule/NexusLSTestModule.lpi` currently search all protocol/process/application folders under `NexusTools/LS` and do not reference a shared LSP library path.
- `tsNXLSProtocolObjectTests.pas` mixes genuinely shared protocol/transport/outbound-dispatch tests with a Pascal-server initialization dispatch test. `tsNXTestJSONRPCHardeningTests.pas` also mixes JSON-RPC behavior with shared dispatcher assertions.
- Current architecture documentation explicitly says `NexusTools/LS` owns all LSP DTOs and transport behavior. `docs/architecture/system-boundaries.md`, `dependencies.md`, `naming-ownership.md`, `docs/nexus-ls/index.md`, `docs/ecosystem.md`, and `docs/index.md` require correction when the shared layer and second server are introduced.

## Architecture Problem

The repository currently has two implicit monoliths:

- NexusScript language semantics, dependency compilation, artifact projection, manifest behavior, and CLI behavior are reachable through the same source directory and, in the session, the same object.
- Standard LSP values and process mechanics are physically owned by the Pascal server and are coupled to its model and globally registered request set.

Adding a dedicated NexusScript language server without restructuring would therefore force one of two invalid dependencies: either NexusScriptLS would compile units directly from the Pascal server tree, or reusable NexusScript semantics would remain mixed with CLI/artifact responsibilities. Both would make physical search paths contradict logical ownership.

The correction is not a generic multi-language analysis framework. It is a pair of strict dependency inversions: front ends consume a NexusScript-owned core, and both server applications consume a small protocol/process library whose host accepts a concrete application instead of constructing the Pascal model.

## Target Contract

### Final dependency graph

```text
NexusLib/core JSON + JSON-RPC
              ^
              |
       NexusLib/lsp
        ^           ^
        |           |
Pascal NexusLS   NexusScriptLS

NexusTools/Script/core
        ^                 ^
        |                 |
Script artifact/CLI   NexusScriptLS
```

Forbidden edges:

- `NexusLib/lsp` -> either language server, either language engine, or Pascal services;
- Pascal `NexusTools/LS` -> `NexusTools/Script`;
- `NexusTools/Script/core` -> `artifact`, `cli`, `ls`, Mustache, or LSP;
- `NexusTools/Script/artifact` -> `cli` or `ls`;
- `NexusTools/Script/ls` -> `cli`, `artifact`, or `NexusTools/LS`;
- either server executable -> the other server executable or application model.

### Shared JSON-RPC/LSP library

- Owner: `NexusLib/lsp` layered over the existing `NexusLib/core` JSON-RPC units.
- Responsibilities:
  - standard typed LSP values and parameters;
  - LSP message framing and stdio/TCP transports;
  - inbound JSON-RPC dispatch and outbound request tracking;
  - a server host that owns process/message-loop mechanics and accepts a language-server application through a narrow injected interface.
- State flow:
  - each executable imports only its own request-registration unit;
  - the shared dispatcher resolves registered request classes without importing a concrete `AllRequests` unit;
  - the shared host passes client responses to an injected application callback and does not construct or globally install either server model;
  - each concrete application supplies its own lifecycle state, request context, advertised capabilities, and outbound-dispatch ownership.
- Does not own documents, analysis, settings policy, indexing, completion, navigation, validation, or concrete inbound request execution.

### Pascal NexusLS

- Owner: `NexusTools/LS`.
- Responsibilities: all existing Pascal language context, documents, Lazarus/FPC configuration, parsing, indexing, services, custom Nexus project/toolchain commands, and concrete LSP request execution.
- State flow: `nexusls.lpr` constructs `TNXLSLSPModel`, installs its existing current-model context for Pascal request units, imports `obNXLSAllRequests`, and injects the model into the shared host.
- Must not reference NexusScript units or advertise NexusScript ownership.

### NexusScript core

- Owner: `NexusTools/Script/core`.
- Responsibilities:
  - ranges and language-level types in `tpNexusScript.pas`;
  - source and compiled models in `obNexusScriptModel.pas`;
  - the existing tokenizer/parser/compiler in `obNexusScriptCompiler.pas`;
  - recursive file/dependency compilation in `obNexusScriptSession.pas`;
  - a public read-only normalized language-definition model and normalization operation in new `obNexusScriptLanguageDefinition.pas`;
  - validation in relocated `obNexusScriptValidator.pas`, consuming the public normalized model rather than owning a second private interpretation.
- State flow: the session compiles and owns dependency compilers/documents and exposes read-only lookup/enumeration needed by consumers. It does not build an artifact document list or resolve external tabular files.
- Does not own LSP behavior, editor documents, CLI flags, JSON projection, Mustache, manifests, external tabular compilation, or output paths.

### NexusScript artifact and CLI front end

- Owner: `NexusTools/Script/artifact` for output production and `NexusTools/Script/cli` for command-line process behavior.
- Responsibilities:
  - `artifact/obNexusScriptArtifactModel.pas`: artifact value categories/projection previously exposed by core model;
  - `artifact/obNexusScriptArtifactContext.pas`: non-owning traversal of a live core compilation session into artifact documents and external-source declarations;
  - relocated `obNexusScriptJSON.pas` and `obNexusScriptExternalSource.pas`;
  - new `obNexusScriptManifest.pas`, receiving the manifest-specific classes and rendering workflow currently private to `obNexusScriptCommand.pas`;
  - `artifact/languages/NexusManifest.Language.nxscript` as the manifest producer's language definition;
  - `cli/NexusScript.lpr` and `cli/obNexusScriptCommand.pas` for flag registration, command selection, stream/file interaction, and orchestration.
- State flow: CLI creates core compilation sessions, passes them to artifact consumers while sessions remain alive, and writes the resulting output. Artifact context does not own or mutate the core session.
- Core never depends back on artifact or CLI units.

### NexusScriptLS front end

- Owner: `NexusTools/Script/ls`.
- Responsibilities in this pass:
  - its executable/project and command-line transport selection;
  - lifecycle state and a server-owned open-document shell;
  - its own minimal lifecycle/document-sync request registrations;
  - an explicit dependency seam to NexusScript core and the shared LSP host.
- Future request/model/service units remain under `ls/src/protocol`, `ls/src/model`, and `ls/src/service`; they will not be added to the Pascal server.
- State flow: `NexusScriptLS.lpr` imports only NexusScriptLS request registrations, constructs its model and selected shared transport, and injects them into the shared host.
- This pass advertises only capabilities actually supported by the structural shell. It performs no parsing, compilation, validation, completion, navigation, or indexing on document changes.

## Scope

### NexusScript physical moves and splits

- Move without compatibility copies:
  - `NexusTools/Script/src/tpNexusScript.pas` -> `NexusTools/Script/core/tpNexusScript.pas`;
  - `src/obNexusScriptModel.pas` -> `core/obNexusScriptModel.pas`;
  - `src/obNexusScriptCompiler.pas` -> `core/obNexusScriptCompiler.pas`;
  - `src/obNexusScriptSession.pas` -> `core/obNexusScriptSession.pas`, after removing artifact responsibilities;
  - `validator/obNexusScriptValidator.pas` -> `core/obNexusScriptValidator.pas`;
  - `src/obNexusScriptJSON.pas` -> `artifact/obNexusScriptJSON.pas`;
  - `src/obNexusScriptExternalSource.pas` -> `artifact/obNexusScriptExternalSource.pas`;
  - `src/NexusScript.lpr` -> `cli/NexusScript.lpr`;
  - `validator/VALIDATION.md` -> `docs/validation.md`;
  - `validator/fixtures/*` -> `tests/fixtures/validation/*`;
  - `validator/NexusManifest.Language.nxscript` -> `artifact/languages/NexusManifest.Language.nxscript`.
- Create:
  - `core/obNexusScriptLanguageDefinition.pas`;
  - `artifact/obNexusScriptArtifactModel.pas`;
  - `artifact/obNexusScriptArtifactContext.pas`;
  - `artifact/obNexusScriptManifest.pas`.
- Split responsibilities:
  - move `TNexusScriptArtifactValueKind`, artifact projection helpers, `TNexusScriptExternalSource`, `TNexusScriptArtifactDocument`, artifact-document traversal, and external-source traversal out of core types/model/session into the named artifact units;
  - add only the read-only compiler/document enumeration and lookup needed on `TNexusScriptCompilationSession` for downstream artifact traversal;
  - move normalized language rule types and normalization diagnostics/logic out of the validator's private `TNSValidatorEngine` into the public, owned, read-only language-definition model; update the validator to consume that model directly;
  - move manifest-specific private classes and workflow out of `obNexusScriptCommand.pas` into `obNexusScriptManifest.pas` without changing manifest behavior.
- Update `NexusScript.lpi`, `tests/NexusScriptTestModule.lpi`, `tests/tsNexusScriptTests.pas`, all affected fixture doctypes, parity manifest paths, `README.md`, parity documentation, and validation documentation.
- Remove the empty obsolete `src` and `validator` trees after all callers are updated.

### Shared LSP extraction

- Create `NexusLib/lsp/AGENTS.md`, explicitly referencing `.ai/standards/pascal.md` and the language-neutral ownership boundary.
- Move these units from `NexusTools/LS/src` to `NexusLib/lsp/src` or its `protocol` subfolder, retaining unit names unless a split below requires a new name:
  - `tpNXLS.pas`;
  - `obNXLSLogger.pas`;
  - `obNXLSTransport.pas`;
  - `obNXLSStdIOTransport.pas`;
  - `obNXLSTcpIPTransport.pas`;
  - `obNXLSTransportFactory.pas`;
  - `obNXLSDispatcher.pas`;
  - `obNXLSOutboundDispatcher.pas`;
  - `obNXLSServer.pas`;
  - `protocol/obNXLSProtocolBase.pas`;
  - `protocol/obNXLSProtocolParams.pas`;
  - `protocol/obNXLSProtocolObjects.pas`;
  - `protocol/obNXLSDocumentSyncParams.pas`.
- Refactor the moved `obNXLSServer.pas` around a small language-neutral application contract that supplies server identity, receives client responses, and is attached to the transport. Preserve explicit ownership of model/application and transport in the constructor/destructor contract.
- Remove `obNXLSAllRequests` from the moved dispatcher. Each executable must force registration through its own program uses list.
- Split the nonstandard types out of the moved protocol DTO units into Pascal-owned files:
  - `NexusTools/LS/src/protocol/obNXLSRefactoringProtocol.pas` for complete-code, invert-assignment, remove-empty-methods, and remove-unused-units parameters;
  - `obNXLSProjectProtocol.pas` for project request values, fields, messages, outputs, details, files, parameters, and results;
  - `obNXLSToolchainProtocol.pas` for toolchain request values, descriptors, parameters, and results.
- Keep all current `*Requests.pas`, `obNXLSAllRequests.pas`, `utNXLSCommandNames.pas`, `obNXLSLSPModel.pas`, `obNXLSSettings.pas`, and every `parser`, `service`, and `toolchain` unit under `NexusTools/LS`. Update them to import shared DTOs/process units and the new Pascal-owned custom protocol units.
- Update `nexusls.lpr` to construct and inject `TNXLSLSPModel`, import its request registry explicitly, and use the shared host. Update both Pascal LS project files and their search paths.

### Shared LSP tests

- Create `NexusLib/lsp/tests/NexusLSPTestModule.lpr`, `NexusLSPTestModule.lpi`, and focused shared test units for:
  - standard typed LSP object serialization/deserialization;
  - transport framing;
  - generic inbound dispatch without a concrete server model;
  - outbound request registration/response matching;
  - injected host/application ownership and response routing.
- Split the generic cases currently in `tsNXLSProtocolObjectTests.pas` into the shared test module. Keep the Pascal initialization/capability dispatch case in a Pascal-owned test unit because it exercises `TNXLSLSPModel` and Pascal request registration.
- Keep NexusTest boundary and Pascal-specific cases in `NexusLSTestModule`; move only dispatcher cases whose subject becomes `NexusLib/lsp`, avoiding duplicate test coverage in both modules.

### Dedicated NexusScriptLS shell

- Create:
  - `NexusTools/Script/ls/NexusScriptLS.lpr`;
  - `NexusTools/Script/ls/NexusScriptLS.lpi`;
  - `ls/src/model/obNexusScriptLSModel.pas`;
  - `ls/src/model/obNexusScriptLSDocument.pas`;
  - `ls/src/protocol/obNexusScriptLSLifecycleRequests.pas`;
  - `ls/src/protocol/obNexusScriptLSDocumentSyncRequests.pas`;
  - `ls/src/protocol/obNexusScriptLSAllRequests.pas`.
- The shell will support initialization state, shutdown/exit, and full-text open/change/save/close storage only. It will return a minimal truthful capability set and perform no language analysis.
- Its project paths may include only its own `ls/src` folders, `NexusTools/Script/core`, `NexusLib/core/src`, `NexusLib/lsp/src` and protocol paths, plus verified third-party transport dependencies. It must not include `NexusTools/LS`, `NexusTools/Script/cli`, or `NexusTools/Script/artifact`.
- Reserve future NexusScript-specific request, model, cache, and service ownership beneath the `ls` tree; do not create empty generalized analysis abstractions during this pass.

### Documentation and repository wiring

- Update `docs/architecture/system-boundaries.md`, `dependencies.md`, `naming-ownership.md`, `docs/nexus-ls/index.md`, `docs/ecosystem.md`, and `docs/index.md` for `NexusLib/lsp`, Pascal-only NexusLS, and the new NexusScriptLS boundary.
- Update `NexusTools/Script/README.md`, moved validation documentation, and parity documentation for final paths without describing out-of-scope editor features as implemented.
- Inspect `scripts/nexus-pascal-deploy-ls.bat`, NexusTask staging scripts, installer inputs, and archive inputs after the moves. Update only inputs whose referenced project/unit paths actually changed. The existing Pascal `nexusls.lpi` path remains stable; NexusScriptLS packaging and VS Code activation remain out of scope.
- Correct every affected LPI unit entry/count, unit search path, output path, and test-module registration. Remove all obsolete paths rather than retaining forwarding units or duplicate sources.

## Out Of Scope

- Error-tolerant/recoverable NexusScript parsing or any parser behavior change.
- New token ranges, declaration identities, compiled-to-source provenance, or composition contributor modeling.
- Open-buffer compilation, source-provider APIs, dependency invalidation, document indexing, or analysis caches.
- Changes to NexusScript lookup, composition, tags, casing, syntax, compiled values, or validation semantics except the behavior-preserving extraction of normalization and artifact projections.
- `doctype`-driven editor behavior, recursive dialect analysis in the LS, dialect validation, or language-rule caching.
- NexusScript diagnostics, completion, document symbols, hover, navigation, references, semantic tokens, formatting, or code actions.
- `.nxscript` VS Code registration, TextMate grammar work, or a second VS Code language-client lifecycle.
- Changes to Pascal analysis, Pascal project semantics, toolchain behavior, service behavior, or advertised capabilities.
- A common document model, generic language-analysis interface, multi-language host, or shared completion/navigation/index framework.
- Schema-, NexusManifest-, or other dialect-specific editor behavior.
- Moving the NexusScript engine into `NexusLib`.
- Packaging or deployment of NexusScriptLS beyond the structural project/build proof requested here.
- Fixing the separately noted NexusScript case-sensitivity audit or SQL apostrophe escaping issue.

## Staged Implementation Plan

### Stage 1: Record the implementation baseline and protect behavior

After approval, start from a clean worktree and record the current commit. Build and run the existing NexusScript and Pascal LS projects/tests before moving files. Record any pre-existing failure rather than folding unrelated corrections into this restructuring.

Checkpoint: the existing CLI, NexusScript tests, Pascal NexusLS, and NexusLS tests have a recorded baseline, and no implementation file has yet moved.

### Stage 2: Extract standard typed LSP values

1. Create `NexusLib/lsp` ownership instructions and final source folders.
2. Move the four typed protocol/value units into `NexusLib/lsp/src/protocol`.
3. Split Nexus project, toolchain, and Pascal refactoring command DTOs into the three Pascal-owned protocol units named in Scope.
4. Update Pascal request, service, toolchain, project, and test imports.
5. Add the shared LSP test module and move/split generic protocol-object tests without duplicating them.
6. Remove the old DTO files and old path entries from `NexusTools/LS`.

Checkpoint: the shared protocol test module, Pascal NexusLS, and NexusLSTestModule compile; Pascal behavior tests remain unchanged; `NexusLib/lsp` contains no project/toolchain/Pascal types.

### Stage 3: Extract transport, dispatch, outbound, and host mechanics

1. Move `tpNXLS`, logger, transport implementations/factory, inbound dispatcher, outbound dispatcher, and server host to `NexusLib/lsp/src`.
2. Remove request-registration ownership from the dispatcher; import `obNXLSAllRequests` explicitly from `nexusls.lpr`.
3. Replace the server host's concrete `TNXLSLSPModel` construction with the injected language-neutral application contract. Remove hard-coded model-global installation and hard-coded server identity from the shared host.
4. Adapt `nexusls.lpr` and `TNXLSLSPModel` to the injected host contract while preserving current ownership and outbound-response behavior.
5. Move the corresponding generic tests into the shared module and retain Pascal dispatch/capability tests under NexusLS.
6. Remove all old process-unit files and source-path dependencies under `NexusTools/LS`.

Checkpoint: the shared infrastructure tests pass; Pascal NexusLS and its complete test module build and run from the new shared path; the shared dispatcher/host imports no Pascal request registry or model.

### Stage 4: Reorganize NexusScript core and expose normalization

1. Create the final `core`, `artifact`, and documentation folders.
2. Move language types, model, compiler, session, and validator to `core`.
3. Extract private normalized rule types and normalization into `obNexusScriptLanguageDefinition.pas` with read-only public access. Preserve current vocabulary, diagnostic codes/messages/ranges, matching behavior, and foundational `Language.nxscript` behavior.
4. Change `TNexusScriptValidator` to request one normalized language definition and validate against it; delete the private duplicate rule classes and normalizer from the validator.
5. Split artifact document/external-source traversal out of `TNexusScriptCompilationSession`. Add only explicit read-only session document/compiler lookup needed by `TNexusScriptArtifactContext`.
6. Move artifact-only types/projection methods out of `tpNexusScript` and `obNexusScriptModel` into artifact-owned units, updating JSON/manifest callers.

Checkpoint: core units compile without artifact, CLI, Mustache, LSP, or Pascal LS dependencies; NexusScript validation/compiler tests pass against the relocated public normalization path.

### Stage 5: Reorganize artifact production and CLI

1. Move JSON and external-source producers into `artifact` and implement the artifact context over the core session's read-only API.
2. Extract manifest-specific classes, validation/orchestration, model selection, template rules, output-path policy, and external-data rendering from `obNexusScriptCommand.pas` into `obNexusScriptManifest.pas` and associated artifact units.
3. Move the CLI entry point into `cli`; keep the root `NexusScript.lpi` as the stable project entry and update it to final unit paths.
4. Move validation fixtures/documentation and the manifest language definition to their final owners. Update every test and parity doctype path.
5. Update NexusScript tests so core tests consume only core units and artifact/CLI tests explicitly consume artifact/CLI units within the same test project.
6. Delete obsolete `src` and `validator` files/directories and remove their search paths.

Checkpoint: NexusScript CLI and complete tests compile and pass; representative raw JSON, template, manifest, external-data, validation, and parity cases retain their current outputs/errors.

### Stage 6: Add the dedicated NexusScriptLS structural project

1. Create the named NexusScriptLS project, model/document shell, and server-owned lifecycle/document request units.
2. Wire the executable to shared transports/host and only its own request registry.
3. Give the model a narrow, explicit NexusScript-core dependency seam without running compilation or analysis on document events.
4. Advertise only full-text synchronization and other lifecycle capabilities the shell actually implements; all editor-intelligence capabilities remain absent/false.
5. Verify the project search paths exclude Pascal NexusLS and NexusScript artifact/CLI folders.

Checkpoint: NexusScriptLS clean-builds and completes an initialize -> initialized -> open/change/save/close -> shutdown -> exit protocol smoke sequence without invoking editor intelligence.

### Stage 7: Remove obsolete paths and document the final graph

1. Update architecture and subsystem documentation named in Scope.
2. Inspect build, staging, installer, deployment, and archive references and update only affected paths.
3. Remove obsolete unit entries, search paths, duplicate test registrations, compatibility copies, and temporary move artifacts.
4. Run the complete build/test matrix and forbidden-dependency greps.
5. Review the final file tree and dependency map against every completion criterion in the request.

Checkpoint: all final verification passes, all old locations are absent, and the diff contains no NexusScript editor-intelligence implementation.

## Sub-Agent Delegation

- No sub-agent is used while preparing or reviewing this plan.
- After explicit implementation approval, use two sequential named worker roles because the write sets are naturally separated but meet at project wiring:
  - `Shared LSP worker`: owns `NexusLib/lsp`, the shared-test module, and necessary adaptations under `NexusTools/LS`. It performs Stages 2-3.
  - `NexusScript restructuring worker`: owns `NexusTools/Script`, including core/artifact/CLI moves and the NexusScriptLS shell. It performs Stages 4-6 only after the shared host contract is integrated.
- Do not run these workers concurrently. Both stages edit project/search-path assumptions, and NexusScriptLS must target the accepted shared host API rather than a competing draft.
- Main Codex responsibilities:
  - establish and communicate the exact approved plan and clean-worktree baseline;
  - review the shared application/host ownership contract before accepting Stage 3;
  - integrate project files, documentation, and repository-wide path cleanup in Stage 7;
  - run the complete build/test/grep matrix and inspect every worker diff;
  - create the required post-implementation architecture archive and report results.
- Workers must not preserve old files, add forwarding units, expand into editor features, or edit the other worker's owned subsystem without reassignment by Main Codex.

## Verification Plan

### Clean builds

Use normal or forced Lazarus builds; do not use the known-broken `--build-mode=Debug` path for these projects.

```text
lazbuild -B NexusLib\lsp\tests\NexusLSPTestModule.lpi
lazbuild -B NexusTools\LS\nexusls.lpi
lazbuild -B NexusTools\LS\NexusLSTestModule\NexusLSTestModule.lpi
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
lazbuild -B NexusTools\Script\ls\NexusScriptLS.lpi
```

### Automated tests

Run all registered suites in the shared LSP, Pascal NexusLS, and NexusScript modules through `nxtest_host.exe`, using the actual target paths declared by the final LPI files:

```text
output\NexusTestHost\nxtest_host.exe output\NexusLSP\tests\x86_64-win64\NexusLSPTestModule.dll run-all
output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-all
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-all
```

Keep or add focused regression cases proving:

- current Pascal initialization/capability and document workflows still dispatch through the Pascal request registry;
- shared dispatcher operation does not require either concrete model;
- shared host transfers client responses to its injected application;
- NexusScript core compilation/session/normalization/validation behavior is unchanged;
- artifact document order, module/include treatment, external-source ordering/collision handling, JSON output, manifest rendering, and Mustache output are unchanged after their extraction;
- NexusScriptLS stores full-text document lifecycle state and advertises no unimplemented language features.

### Protocol smoke tests

- Start each server over stdio independently and send valid framed initialize, initialized, shutdown, and exit messages.
- For NexusScriptLS, additionally send full-text didOpen/didChange/didSave/didClose notifications for a `.nxscript` URI and confirm clean lifecycle handling without diagnostics or analysis.
- Confirm malformed framing/error responses remain covered by the shared infrastructure tests.

### Forbidden-dependency greps

Run focused searches and require no matches except comments/tests that explicitly assert absence:

```text
rg -n "obNXPas|obNXLSLSPModel|obNXLS.*Service|obNexusScript" NexusLib\lsp
rg -n "obNexusScript(JSON|ExternalSource|Artifact|Manifest|Command)|obNXLS|obMustache" NexusTools\Script\core
rg -n "obNXLSLSPModel|obNXPas|NexusTools[\\/]LS|obNexusScript(Command|JSON|ExternalSource|Artifact|Manifest)" NexusTools\Script\ls
rg -n "obNexusScript|NexusTools[\\/]Script" NexusTools\LS
rg -n "obNexusScriptCommand" NexusTools\Script\artifact NexusTools\Script\core NexusTools\Script\ls
```

Confirm obsolete paths and duplicate sources are gone:

```text
rg -n "NexusTools[\\/]Script[\\/]src|NexusTools[\\/]Script[\\/]validator|\.\.[\\/]src|\.\.[\\/]validator" NexusTools\Script NexusTools\LS NexusLib\lsp scripts docs
rg -n "NexusTools[\\/]LS[\\/]src[\\/](protocol[\\/]obNXLSProtocol|obNXLS(Dispatcher|OutboundDispatcher|Server|Transport|Logger))" . --glob '!work/**'
```

Inspect unit declarations and final files to ensure each moved unit has exactly one physical owner and no forwarding/alias unit remains.

### Behavior and artifact checks

- Run representative existing CLI invocations for raw JSON, JSON plus Mustache, a valid manifest, an invalid manifest, and external CSV/JCSV/TSV/TAB processing.
- Compare outputs and error text with the Stage 1 baseline. This restructuring does not authorize contract changes.
- Validate both parity manifests after their `doctype` paths move.
- Inspect project metadata and generated dependency output to confirm:
  - Pascal NexusLS reaches LSP units only through `NexusLib/lsp`;
  - NexusScriptLS has no `NexusTools/LS`, `cli`, or `artifact` unit path;
  - NexusScript CLI reaches core and artifact but not `ls`;
  - core reaches none of its consumers.
- Run `scripts\New-NexusSourceArchive.ps1` only after approved implementation and final verification, as required for an architecture milestone.

## Risks And Questions

- `obNXLSProtocolParams.pas` and `obNXLSProtocolObjects.pas` contain dense cross-references. Splitting custom project/toolchain DTOs must preserve class-factory registration, published-property types, and initialization ordering. Compile immediately after each split.
- The class factory is global within each process. Removing `obNXLSAllRequests` from the shared dispatcher makes executable-level registration order explicit; importing both servers' registries into one executable is forbidden.
- The current server host owns both transport and model implicitly. The injected replacement must document ownership precisely to avoid double-freeing either object or leaving the outbound dispatcher attached to a destroyed transport.
- TCP transport brings Synapse and command-line configuration into the shared LSP layer. Keep those as explicit process-infrastructure dependencies; do not move Pascal settings/toolchain policy with them.
- Moving validation and manifest language files changes executable-relative and repository-relative test paths. Every doctype reference must be updated atomically with its file move.
- Artifact traversal currently relies on the session's private compiler cache and on the session remaining alive. The new read-only session API and non-owning artifact context must preserve that lifetime explicitly without exposing a mutable compiler list.
- Extracting normalization must be behavior-preserving. Public rule objects must expose read-only traversal/find operations rather than mutable lists that allow the LS or validator to rewrite the normalized dialect.
- No architecture question currently requires owner direction: the supplied request fixes the server split, final ownership, physical-reorganization requirement, shared-layer scope, and excluded feature work. If implementation inspection shows that a named supposedly standard protocol type encodes a current NexusLS-only extension beyond the verified project/toolchain/refactoring groups, stop and classify it by the same ownership rule rather than silently placing it in the shared library.

## Approval Gate

This planning artifact authorizes no restructuring implementation, build, test, launch, archive, or delegated worker activity. No implementation begins until the human owner reviews this plan and explicitly authorizes it.
