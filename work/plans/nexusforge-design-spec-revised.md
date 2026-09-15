# Work Plan: NexusForge Declarative Execution

> Execution-model amendment (2026-09-15): the owner approved ordinary module
> configurations and composition, with each completed operation supplying its
> own `Template`. This supersedes this original plan's separate process-manifest
> matching and `/manifest` argument. See the current
> [execution contracts](../../NexusTools/Forge/docs/contracts.md) and
> [package contracts](../../NexusTools/Forge/docs/packages.md).

Status: First execution milestone implemented and verified; uncommitted owner review.
Date: 2026-09-15

## Inputs

- Human request: "build the work plan".
- Design input: `C:\Users\kcollins\Downloads\nexusforge-design-spec-revised.md`, reviewed in this conversation. The document is architecture input, not implementation authorization.
- Settled review: use existing Targets; Forge reports zero/multiple applicable manifestations at execution time. No validation-language uniqueness extension.
- Settled review: start with native executables, beginning with FPC. The developer supplies the environment and PATH. Do not manage tool versions or repair environments.
- Settled review: use existing Mustache/process techniques; ordinary paths containing spaces and `&` are verification cases. Do not invent an argument language to anticipate limitations.
- Final review clarification: document dialect declaration, effective language composition, and dialect file resolution are separate concerns. An internal `DialectRoot` is only a fallback file-resolution directory; the normal Forge CLI exposes no dialect-selection or dialect-root option.
- Implementation clarification from the owner: `module` is for references/composition; `include` is for aggregation. The initial explicit `(ForgeCore, ForgeFPC, ForgeGit)` composition fixture was rejected. Independent pieces now contribute through `include`, with a shared included-definition view used by presentation and validation. This foundational correction is implemented separately for review before continuing the Forge runtime.
- Resumption clarification: operation pieces use `*.ForgeDef.nxscript`, a Forge packaging convention rather than a NexusScript filename requirement. The include pattern selects these contributions without naming individual tools.
- Governing instructions: `AGENTS.md`, `.ai/protocols/architecture-change.md`, `.ai/protocols/codex-workplan-format.md`, `.ai/standards/pascal.md`, and applicable folder instructions.

## Summary

Add `nxforge` alongside NexusBuild and NexusTask. Compile and validate semantic operations through NexusScript, select their process manifestations through NexusManifest and Targets, render commands with Mustache, and execute them sequentially through one generic runner.

This plan delivers the complete first execution milestone specified in section 35: actual FPC compilation, a second ordinary native tool through the same runtime, clear selection and execution failures, and documented reusable definitions/manifests/templates. Native/cross-compiler construction follows this milestone; it is not claimed by merely compiling an application.

## Verified Findings

- `NexusTools/Script/core/obNexusScriptSession.pas`: `TNexusScriptCompilationSession` accepts `TNexusScriptTargetSelection`, owns compilation attempts, resolves dependencies/dialects, and exposes the compiled entry document and diagnostics.
- In that session, `ResolveDialectPath` first tries the document-relative declared dialect path, then uses `DialectRoot` as a fallback for a relative path. It does not select a different dialect or assemble language rules. `ExpandPatterns` supports module/include discovery; discovery alone is not evidence that the imported pieces form the required effective `Language.Definitions`.
- `NexusTools/Script/core/obNexusScriptModel.pas`: Target selection has an existing `Add(Name, Value)` API. Forge can supply the same selection to operation and manifest compilation without implementing another filtering system.
- `NexusTools/Script/cli/obNexusScriptCommand.pas`: compilation and dialect validation are distinct calls. Forge must invoke validation explicitly; successful compilation alone is insufficient.
- `NexusTools/Script/artifact/obNexusScriptJSON.pas`: the generic emitter consumes compiled documents and emits resolved definitions with metadata. Its public API currently exposes document emission, not a selected-definition render context.
- `NexusLib/script/dialects/NexusManifest/NexusManifest.Language.nxscript`: the present manifest vocabulary describes Models, Templates, and SourceTemplates for artifact rendering. Process manifestations require a small explicit extension; they are not already an executor feature.
- `NexusTools/Script/artifact/obNexusScriptManifest.pas`: current rendering writes artifacts and requires artifact destinations. Its artifact path must not be repurposed to execute commands as a side effect.
- `lib/dmustache/SynMustache.pas` is the existing template engine; `NexusTools/Script/NexusScript.lpi` already includes that library. Reuse it directly without changing `NexusTools/Schema`.
- `NexusTools/Task/src/obNXTaskActions.pas` contains tool-specific methods around `TProcess`. The FPC method merges stderr into stdout. This is useful existing process-handling evidence, but does not meet Forge's distinct stdout/stderr result contract unchanged.
- Existing Script build projects are `NexusTools/Script/NexusScript.lpi` and `NexusTools/Script/tests/NexusScriptTestModule.lpi`. The latter is a test-module library, not a directly executable console test runner.

These findings are from source inspection. No builds or process-behavior tests were performed while preparing this plan.

## Architecture Problem

Ordinary tool support should be data: legal operation structure, applicable manifestation, and template. It should not require another Pascal task class or installation-path setting. The missing connection is a small runtime from the resolved semantic model to one external invocation, with a process manifestation contract that does not inherit artifact-output requirements.

## Target Contract

### Entry and execution context

- New executable: `nxforge`, under `NexusTools/Forge`.
- Proposed CLI inputs: operation document, explicit manifest file, and explicit named Target selections. Reuse repository command-line conventions; document exact flag spelling in Stage 1. The operation itself does not select its template.
- Compile operation and manifest documents with the same Target selection. Validate their declared dialects before execution. Missing dialects or invalid operation/manifest structures fail clearly.
- Forge documents identify their dialect through the normal NexusScript declaration. The initial vocabulary is one effective Forge language assembled from the core Forge definition and operation-specific definition pieces using the existing NexusScript include mechanism. FPC and Git contribute rules to that effective language; they are not separate document dialects.
- The normal Forge CLI exposes no dialect-selection or dialect-root option. Any internal dialect search root only locates the document-declared dialect; it does not override that declaration or determine which operation definitions compose the language. Preserve the existing file-resolution mechanism; no new discovery system or wildcard/catalog import syntax is needed for this milestone.
- The initial fixtures must demonstrate separate core, FPC, and Git definition pieces composing into one effective `Language.Definitions` that validates both operation kinds. Finding/importing the files alone does not satisfy this requirement.
- Execute root operations in their resolved declaration order. Definitions used only through composition/reference are not independently scheduled. Confirm order from actual compiled fixtures, including composition and filtering; do not derive order by sorting JSON keys or names.
- The default working directory is the entry Forge document's directory. A generic explicit working-directory override, if supplied, resolves relative to that directory. Template paths resolve relative to their declaring manifest file. Child-relative source/output arguments remain relative to the operation working directory.
- Inherit the developer-supplied environment, including PATH. No first-pass environment mutation, discovery, activation, or compiler selection facility. Resolve native tools by name using that PATH and report launch failures clearly.

### Manifestation and rendering

- Extend the existing NexusManifest dialect with a process-manifest root/section and process entries. Keep artifact manifests and their validation intact. Process entries need only semantic operation-kind identity, a template source, and ordinary NexusScript Targets; no artifact output file is required.
- Stage 1 establishes the concrete syntax in runnable fixtures using the existing Language dialect. Keep both host variants in one manifest fixture to demonstrate Target selection without a parallel mapping system.
- Match each selected operation's effective Kind to applicable process entries using existing NexusScript identifier comparison rules. Require exactly one: zero is missing manifestation; multiple is ambiguity naming all matches. No fallback priority, specificity ranking, or first-match rule.
- Perform this check in Forge over the compiled/filtered model. Check all selected operations before launching the first child, so known selection errors cannot leave an unnecessarily partial execution.
- Render the selected operation's resolved values, including existing metadata, as the template context. Add a narrow selected-definition entry point to the generic JSON emitter if needed; reuse its existing value emission rather than create Forge-specific value conversion. Preserve existing document JSON output.
- Mustache owns tool-specific command construction. Use existing raw interpolation/quoting techniques as appropriate. The runtime uses existing process facilities to launch the rendered invocation; it does not reconstruct FPC options from semantic properties.
- One manifestation produces one native process invocation. No automatic shell, compound command interpretation, new command grammar, or per-tool executor branch. A concrete required case that existing techniques cannot handle must be reported before architectural expansion.

### Ownership and results

- One run object owns compilation sessions, Target selection, render contexts, and execution results for the run. Borrowed compiled definitions remain valid until the owning sessions are released.
- One generic executor owns each child process and its stream buffers through completion, then releases them on success or failure. No plugin interfaces or executor registration framework.
- Execute sequentially on the console application's existing thread. Drain both stdout and stderr while the child runs and after exit; do not wait for exit with unread full pipes. No new worker thread or scheduling framework is planned.
- Each invocation reports operation identity, selected manifestation, rendered command, working directory, distinct stdout/stderr, exit code when a child exited, and success/failure. A launch failure has a diagnostic rather than a fabricated child exit code.
- Exit zero continues; nonzero or launch/render failure stops the run and returns a nonzero Forge status. Retain diagnostics and output for completed/failed operations. No retries, rollback, tolerated-code lists, or automatic recovery.
- Logs identify what actually ran without requiring a receipt/provenance subsystem. GUI behavior and persistence frameworks are not involved.

## Scope

Expected new files/areas:

- `NexusTools/Forge/AGENTS.md`, referencing the repository Pascal standards.
- `NexusTools/Forge/NexusForge.lpi`, `cli/NexusForge.lpr`, and `cli/obNXForgeCommand.pas`.
- `NexusTools/Forge/src/obNXForge.pas`: compile, validate, select, render, and ordered execution orchestration.
- `NexusTools/Forge/src/obNXForgeProcess.pas`: the generic native process executor.
- `NexusTools/Forge/src/tpNXForge.pas`: shared execution result types where needed across units.
- `NexusTools/Forge/tests/NexusForgeTests.lpi`, console runner, focused cases, and fixtures.
- `NexusTools/Forge/examples/`: a small FPC build and second-tool example with manifests/templates; no machine-specific absolute tool paths.
- `NexusTools/Forge/docs/contracts.md`: actual CLI, document/manifest examples, environment responsibility, failure behavior, and verification instructions.
- `NexusLib/script/dialects/NexusForge/`: the shared effective Forge language, assembled from its core and separate FPC/Git operation-definition pieces.

Expected narrow existing changes:

- `NexusLib/script/dialects/NexusManifest/NexusManifest.Language.nxscript`: process manifestation vocabulary without removing artifact forms.
- `NexusTools/Script/artifact/obNexusScriptJSON.pas`: selected-definition emission if required, with existing-output regression coverage.
- `NexusTools/Script/tests/`: manifest validation and generic emitter regression cases affected by those changes.

Unit boundaries may be combined where a separate unit has no useful responsibility. This list does not authorize adding framework layers to fill filenames.

## Out Of Scope

- Rewriting, replacing, or adding compatibility wrappers to NexusBuild/NexusTask.
- Tool-specific Pascal command builders or installation-path settings.
- Schema changes, installer integration, package distribution, or GUI/LSP extensions.
- Compiler-version management, environment correction, PATH repair, SDK discovery, and tool activation.
- Shell/script execution and automatic interpreters.
- Dependency graphs, parallel operations, mutable variables, named-artifact machinery, caching, incremental builds, plugins, and build receipts.
- New validation-language semantics for manifestation uniqueness or new import syntax.
- Native/cross-toolchain construction in this first milestone. Its eventual acceptance remains an actual target compile/link using the produced toolchain, not compiler-file existence.

## Staged Implementation Plan

### Stage 1: Establish concrete documents and integration boundaries

Create the Forge project skeleton, composed operation dialect, and process manifest vocabulary. Specify CLI flags without dialect-selection or dialect-root options. Create separate core, FPC, and Git language-definition pieces and demonstrate their composition into one effective Forge language using existing mechanisms. Create FPC plus Git operation fixtures (Git is the second native executable; it is already used in this repository). Demonstrate host-target filtering and preserve declared operation order using the real compiler and validator. Keep Git behavior in definitions/templates; use a local fixture repository, with no network access.

Acceptance: both operation kinds validate against the document-declared, composed Forge language; invalid operation-specific properties fail. Verify effective rules, not only successful file discovery. Document how the declared dialect is located using existing resolution behavior. Zero/one/multiple manifestation cases are represented; existing artifact manifests still validate. No custom compiler semantics or task classes.

### Stage 2: Resolve and render

Implement ownership of sessions and per-operation matching. Reuse the generic resolved JSON emitter with the smallest selected-definition API necessary. Render the existing Mustache templates. Test inherited/default values, multiple differently named operations using the same template, list values, and inactive Targets. Diagnose missing templates and preserve operation/manifest identity in errors.

Acceptance: exact expected rendered commands from compiled semantic values, with no Forge-specific FPC option logic or changes to existing document JSON shape.

### Stage 3: Execute one native invocation

Implement the single process path with deterministic working directory, inherited environment/PATH, separate output streams, stop-on-failure, and cleanup. Start with the existing process API and template techniques. Verify actual argument delivery through FPC compilation of paths containing spaces and `&`; do not solve hypothetical command syntaxes.

Acceptance: successful native FPC compile; useful launch/compiler diagnostics; no hang with substantial output on both streams; no later operation starts after failure.

### Stage 4: Complete the generic execution milestone

Wire ordered operations through the CLI. Execute a local Git operation through a semantic definition, manifestation, and template using the identical runner. Complete selection, ordering, working-directory, result, and cleanup tests. Document examples and record exact verification results and prerequisites.

Acceptance: every section-35 criterion is demonstrated, including both ordinary tools and selection errors. Review production code for tool-specific execution branches and unnecessary abstractions. Create the implementation source archive using `scripts/New-NexusSourceArchive.ps1` and verify Forge sources, fixtures, dialects, and documentation are included.

### Subsequent toolchain work

After this milestone, plan the concrete bootstrap/native/cross/RTL/package/staging sequence against a specified FPC source revision and developer-supplied prerequisites. Keep those commands in definitions/manifests/templates. This plan neither fabricates that sequence nor introduces an activation subsystem in anticipation of it.

## Sub-Agent Delegation

Implementation remains local. No sub-agent use is authorized by this plan or by implementation approval; it requires a separate explicit human request.

## Verification Plan

Proposed commands after implementation authorization and project creation:

```powershell
lazbuild -B NexusTools\Forge\NexusForge.lpi
lazbuild -B NexusTools\Forge\tests\NexusForgeTests.lpi
& .\output\NexusForgeTests\x86_64-win64\NexusForgeTests.exe
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
git diff --check
```

Set the new project targets under `output/NexusForge` and `output/NexusForgeTests`, with separate unit output directories. Use existing Script dependency/search paths and NexusTest cases; keep the new runner a directly executable console project returning nonzero for failure/error, zero tests, or unexpected skips. Run affected existing Script regression cases through the repository test host; determine and document its actual invocation during implementation rather than treat the module DLL as an executable.

| Area | Required evidence |
| --- | --- |
| Validation | Unknown/missing properties and invalid values fail before execution; compiler diagnostics retain source context. |
| Language composition | Separate core, FPC, and Git pieces produce one effective `Language.Definitions`; both operation kinds validate and their invalid properties fail. Discovery/import success alone is insufficient. |
| Dialect resolution | The document declaration remains authoritative; document-relative lookup and any internal fallback root locate that declared file. The CLI has no dialect-selection or dialect-root option. |
| Targets | Host/target dimensions stay separate; inactive entries are excluded by existing filtering; variants coexist in one manifest. |
| Selection | One proceeds; zero names the operation; multiple names operation and matches; no child starts after selection preflight fails. |
| Rendering | Resolved/inherited values, lists, and multiple operation names render correctly; existing generic JSON output remains unchanged. |
| Actual execution | FPC compiles a trivial program; source/output paths containing spaces and `&` succeed through the real renderer/executor. |
| Genericity | Local Git operation succeeds through the same code path with no tool-specific runtime branch. |
| Context | Running Forge from a different launch directory preserves document-relative behavior; PATH lookup uses supplied environment; missing tool fails clearly. |
| Ordering/failure | Declaration order is preserved after compilation/filtering; nonzero child exit stops following operations; launch and render failures are distinct. |
| Output/lifetime | Separate stdout/stderr, including large output on both; final bytes collected after exit; child objects and buffers released on all result paths. |
| Regression | Artifact manifest validation/rendering and existing document JSON cases remain valid. |

Focused inspection:

```powershell
rg -n 'uses|TProcess|CommandLine|Executable|Parameters|CurrentDirectory|poStderrToOutPut' NexusTools/Forge
rg -n 'FPCPath|GitPath|LazarusRoot|TThread|cmd.exe|powershell|TFPC|TNpm|TGit' NexusTools/Forge
```

Review matches in context: test data/documentation may mention excluded behavior. Inspect actual dependencies and execution flow; grep absence is not proof. Manually review CLI diagnostics, operation order, both stream outputs, and successful generated executable existence. No GUI test is required. Record tool versions as test evidence, not as a new runtime management feature.

## Risks And Questions

- Concrete process-manifest syntax and selected-operation JSON exposure are small necessary integrations with existing contracts, to be settled in Stage 1/2 fixtures. Do not assume conceptual examples are already accepted source syntax.
- The current shared artifact manifest must continue to work; process entries must not accidentally be rendered as files or executed by the artifact command.
- Exact process quoting and PATH behavior must be verified with installed FPC facilities. Existing techniques are the starting point; no new grammar is pre-authorized.
- Developers supply functioning FPC/Git executables and environment. Missing prerequisites are reported plainly; implementation does not install or repair them.
- This first milestone does not establish cross-toolchain reproducibility or build a bootstrap compiler. Those claims require the later concrete toolchain sequence and its compile/link test.
- No additional architecture decision is currently required from the owner before reviewing this plan. Incompatible findings during implementation must be reported rather than silently expanding scope.

## Approval Gate

The original planning request authorized only the plan handoff. The owner subsequently authorized implementation and explicitly resumed Forge after the include/projection corrections. This implementation is ready for owner review; no implementation commit or push was requested.
