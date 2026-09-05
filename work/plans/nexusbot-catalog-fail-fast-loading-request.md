# Work Plan: NexusBot Catalog Fail-Fast Loading and Availability Removal

## Inputs

- Source request: `nexusbot-catalog-fail-fast-loading-request (1).md`, supplied
  by the human owner from `C:\Users\kcollins\Downloads`.
- Related discussion/review notes: the catalog is configuration and must load
  as one valid unit; malformed configuration is not an unavailable bot;
  runtime availability and runtime diagnostic detail remain separate from
  catalog validity.
- Existing constraints: follow the repository architecture protocol and Pascal
  standards; keep BotHost JSON-RPC contracts RTTI/property modeled; register
  tests through `NexusBotHostTestModule`; do not create standalone test
  harnesses; do not introduce threads, provider infrastructure, hot reload, or
  OpenAI support as part of this correction.

## Summary

Replace the current partial catalog-load model with a binary, atomic contract.
`TNXBotCatalog.Load` will compile and dialect-validate the complete NexusScript
document, validate catalog and deployment invariants into unpublished candidate
state, and publish that state only if every check succeeds. A failed load will
report useful diagnostics without publishing any candidate entry or disturbing
entries from the last successful load.

Remove `Available` and per-entry load diagnostics from catalog entries and from
the bot status/wire representations. Preserve actual runtime state, runtime
diagnostic detail, and `bceUnavailable` cases that describe failures occurring
after a valid catalog has loaded.

## Verified Findings

- `TNXBotCatalogEntry` currently stores both `Available` and `Diagnostic`.
- `TNXBotCatalog.Load` clears the published entry list before attempting the
  load, so a failed replacement cannot preserve the previously valid catalog.
- Dialect validation diagnostics are collected, but validation failure does not
  stop entry construction.
- `ValidationDiagnosticForDefinition` maps document validation failures onto
  individual entries so valid definitions can be retained beside malformed
  definitions.
- Duplicate bot names are diagnosed and skipped rather than failing the whole
  catalog.
- Missing, duplicate, and incomplete deployment bindings become unavailable
  entries rather than load failures.
- The loader procedurally rejects providers other than `Codex` even though
  `Bot.Language.nxscript` already declares `AllowedValues: [Codex]`.
- Load success is currently `FEntries.Count > 0`; it does not mean the complete
  catalog and deployment configuration were valid.
- `Bots.Mixed.nxscript` and `TestBotCatalog` explicitly preserve and test the
  partial-validity behavior being removed.
- `TNXBotStatus.Available` is copied from the catalog, serialized as the XMPP
  `available` attribute, parsed by the IQ client path, rendered by the human
  interpreter, and included in Codex tool-result text.
- `TNXBotStatus.Diagnostic` has two sources: obsolete catalog load diagnostics
  and legitimate runtime App Server detail. Only the catalog-derived source is
  invalid under the new contract.
- `TNXBotController.ExecuteInvite` contains a catalog-entry availability gate
  that becomes impossible once only valid entries can be published.
- The GUI frees the failed catalog and raises only `Could not load the NexusBot
  catalog.`, discarding the useful diagnostics held by the catalog.
- BotHost deterministic tests are registered in
  `NexusBotHostTestModule.lpr`; the removed standalone test runners are not part
  of the current test architecture.
- The GUI and tests construct catalogs directly. No verified hot-reload owner,
  generation model, or catalog notification mechanism exists.

## Architecture Problem

The current catalog represents two unrelated conditions through the same
object state:

1. whether the source and deployment configuration were valid enough to create
   a bot; and
2. whether a valid bot is presently operating successfully.

Retaining malformed definitions as unavailable entries makes every downstream
consumer participate in catalog validation. The controller, human interpreter,
Codex tool output, IQ status contract, and tests all carry branches that exist
only because invalid configuration was published. It also permits the loader
to report success for a document that failed its authoritative NexusScript
dialect validation.

Catalog construction and runtime operation need distinct contracts. Catalog
loading determines whether a bot entity exists. Runtime state determines what
that valid entity is currently doing and whether a runtime service has failed.

## Target Contract

- Owner: `TNXBotCatalog` owns published catalog entries and diagnostics from the
  most recent load attempt.
- Responsibilities:
  - compile the entire configured NexusScript document;
  - require and apply its declared dialect;
  - reject any dialect validation failure;
  - enforce unique bot names;
  - require exactly one complete deployment binding for every bot;
  - validate only locally knowable declared configuration;
  - publish entries only after the complete candidate passes;
  - report the actual reasons for a failed load.
- Candidate ownership:
  - candidate entries are owned locally by `Load` while validation proceeds;
  - no candidate object is inserted into `FEntries` before success;
  - on success, ownership of the complete candidate replaces the published
    entry list and the former published list is released;
  - on failure, the candidate is released and `FEntries` remains unchanged;
  - a new catalog therefore remains empty after its first failed load.
- Diagnostic ownership:
  - `FDiagnostics` describes the most recent failed load attempt;
  - failure diagnostics may change without changing the published entry list;
  - successful loading clears stale failure diagnostics;
  - successfully published entries carry no load diagnostic.
- Static validation boundary:
  - validate required fields, exact binding association, binding uniqueness,
    configured environment-variable names, supported provider values through
    the NexusScript dialect, parseable values, and required field combinations;
  - do not resolve or inspect secret values;
  - do not test process startup, network reachability, TLS negotiation, remote
    authentication, quota, or provider health.
- Runtime state flow:
  - `TNXBotStatus` continues to describe active state, App Server state, XMPP
    state, joined rooms, and genuine runtime detail;
  - `bceUnavailable` remains available for actual runtime/transport failure;
  - no runtime consumer recreates a catalog-validity Boolean under another
    name.
- Operator behavior: GUI startup includes the collected catalog diagnostics in
  its failure report rather than replacing them with a generic message.

## Scope

- `NexusTools/BotHost/src/obNXBotCatalog.pas`
  - remove entry `Available` and `Diagnostic` state;
  - remove per-definition diagnostic salvage;
  - replace `BindingAvailable` with explicit static binding validation;
  - construct and validate an unpublished candidate;
  - fail on compilation, dialect, duplicate-name, missing-binding,
    duplicate-binding, or incomplete-binding errors;
  - remove redundant procedural provider validation;
  - replace the published list only after complete success.
- `NexusTools/BotHost/src/obNXBotController.pas`
  - stop deriving status availability and catalog diagnostics;
  - remove impossible INVITE rejection of a published unavailable entry;
  - retain runtime failure mappings and runtime App Server detail.
- `NexusTools/BotHost/src/tpNXBotControl.pas`
  - remove `TNXBotStatus.Available` while retaining its real runtime fields and
    runtime `Diagnostic` detail.
- `NexusTools/BotHost/src/obNXXMPPBotControl.pas`
  - remove the `available` status attribute from serialization and parsing;
  - preserve runtime diagnostic serialization and `service-unavailable` error
    mapping where they remain operationally meaningful.
- `NexusTools/BotHost/src/obNXBotControlInterpreter.pas`
  - remove unavailable-entry rendering and render valid inactive/active state
    directly.
- `NexusTools/BotHost/src/obNXCodexAppServer.pas`
  - remove catalog availability from typed bot-control result text without
    changing the RTTI/property-modeled JSON-RPC contract.
- `NexusTools/BotHost/uiNXBotHostMain.pas`
  - retain the catalog diagnostic text before freeing the failed catalog and
    surface it through the actual startup error.
- `NexusTools/BotHost/catalog/Bots.Mixed.nxscript`
  - rename or replace it as an explicitly negative Bot-dialect fixture, keeping
    test intent outside the dialect suffix.
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`
  - replace partial-load assertions with atomic failure assertions;
  - update control, interpreter, Codex-result, and IQ wire expectations;
  - cover preservation of a previously published catalog.
- `NexusTools/BotHost/tests/tsNXBotHostLiveTests.pas`
  - update status-wire assertions if the live test currently expects the
    removed attribute; preserve the existing live behavior otherwise.
- `NexusTools/BotHost/README.md`
  - remove any description of partial availability and document the valid
    catalog/runtime-state boundary if the existing text exposes it.

## Out Of Scope

- OpenAI provider implementation or credentials.
- A generalized provider or plugin availability framework.
- Testing secret values or remote credential acceptance during catalog load.
- Catalog hot reload, fallback policy, generations, observers, notifications,
  or synchronization.
- New NexusScript grammar or validator behavior.
- Catalog/roster terminology changes.
- Removal of legitimate runtime diagnostics or runtime transport errors.
- JSON-RPC restructuring or free-form JSON handling.
- Unrelated BotHost refactoring.
- Standalone test runners or test harness applications.

## Staged Implementation Plan

### Stage 1: Establish atomic catalog construction

1. Remove `FAvailable`, `FDiagnostic`, and their public properties from
   `TNXBotCatalogEntry`.
2. Remove `ValidationDiagnosticForDefinition`; dialect validation failure will
   terminate the load after copying all validator diagnostics into
   `FDiagnostics`.
3. Introduce a locally owned candidate `TNXBotCatalogEntryList` inside `Load`.
   All duplicate searches and entry construction during the attempt operate on
   this candidate, not `FEntries`.
4. Keep `FEntries` untouched through compilation, dialect validation, catalog
   invariant validation, binding validation, and candidate construction.
5. After complete success, replace the published list with the candidate in one
   small ownership operation and release the former list. On every failure,
   release only the candidate.
6. Define success as successful completion of all validation and publication,
   not merely the presence of one entry. Preserve the dialect's authority over
   whether an empty catalog is legal; do not invent an additional non-empty
   rule unless the existing Bot language requires it.

### Stage 2: Make deployment validation reject the catalog

1. Reshape `BindingAvailable` into a validation helper that adds a concrete
   catalog diagnostic rather than returning entry availability state.
2. For each candidate bot, require exactly one binding and diagnose zero or
   multiple bindings with the bot name.
3. Validate every binding field required by `CreateConfiguredHost` to
   instantiate the configured host, including locally knowable endpoint/TLS
   field combinations already required by the existing configuration model.
4. Validate the configured password environment-variable name but do not read
   its value.
5. Allow `Bot.Language.nxscript` to reject unsupported `Provider` values through
   `AllowedValues`; delete the duplicate `Provider <> 'Codex'` branch.
6. Accumulate independent catalog/binding errors when doing so remains simple,
   but publish nothing if any error exists.

### Stage 3: Remove catalog availability from consumers

1. Remove `TNXBotStatus.Available` and update every record constructor and test
   fixture that initializes it.
2. Update `TNXBotController.MakeStatus` to populate runtime status directly and
   retain only runtime diagnostic detail.
3. Delete the INVITE branch that rejects an entry because its catalog state is
   unavailable. Keep not-found, capacity, connection, join, transport, and
   lifecycle failure behavior intact.
4. Simplify human status rendering to distinguish inactive bots from active
   runtime state without an unavailable catalog branch.
5. Remove `available` from the BotHost IQ status XML serializer and parser.
   Preserve the typed status structure and all remaining runtime fields.
6. Remove `available=...` from Codex bot-control result formatting. Do not alter
   the RTTI-declared App Server request/result object model beyond the requested
   status-field removal.
7. Audit `bceUnavailable`, `<bot-unavailable>`, `service-unavailable`, and
   `Diagnostic` uses individually. Retain those driven by runtime or transport
   behavior; remove only catalog-derived cases.

### Stage 4: Surface failure diagnostics to the operator

1. In GUI catalog startup, capture the complete `Diagnostics.Text` before
   freeing the failed catalog.
2. Raise an understandable startup failure containing the catalog path/context
   and the reported compiler, validator, or deployment diagnostics.
3. Keep catalog and configuration cleanup deterministic on that exception path.
   Do not introduce a recovery or retry path.

### Stage 5: Replace fixtures and tests

1. Rename or replace `Bots.Mixed.nxscript` with a negative fixture name that
   retains the established Bot dialect suffix and identifies invalid test
   intent in its basename or fixture location.
2. Split the existing broad catalog test into focused registered tests where
   this improves failure identification, while keeping all tests in
   `NexusBotHostTestModule`.
3. Prove valid complete loading and effective compiled values.
4. Prove compile failure, missing doctype/dialect failure, mixed valid-invalid
   definitions, duplicate bot names, missing bindings, duplicate bindings, and
   incomplete static binding configuration all fail with useful diagnostics.
5. Prove a failed candidate publishes no partial entries, preserves a prior
   successful catalog, and leaves a fresh catalog empty.
6. Prove unsupported providers fail through ordinary dialect validation.
7. Update LIST, STATUS, INVITE, DISMISS, interpreter, Codex tool-result, and IQ
   serialization/parsing assertions for the status shape without `Available`.
8. Preserve focused coverage of genuine runtime unavailable/transport results
   and runtime diagnostic detail.
9. Update the live test only where its expected status wire shape changed; do
   not broaden its interoperability scenario.

### Stage 6: Documentation and removal audit

1. Update BotHost documentation that describes catalog availability or partial
   loading.
2. Search the BotHost tree for the removed entry/status fields, partial-load
   fixture name, procedural provider check, and generic GUI error.
3. Review every remaining `Diagnostic` and `bceUnavailable` occurrence and
   confirm it represents runtime state or transport behavior.
4. Remove dead helpers and branches exposed by the new invariant instead of
   retaining compatibility shims.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan does not authorize
spawning, resuming, messaging, or delegating to sub-agents. Plan approval and
implementation approval do not grant sub-agent permission; the human owner
must request sub-agent use explicitly in the current conversation.

## Verification Plan

- Build the BotHost GUI and registered BotHost test module:

  ```powershell
  lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
  lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
  ```

- Build the existing fake App Server process fixture used by the registered
  pipe integration test. It remains a fixture, not a standalone test harness:

  ```powershell
  fpc -B -MObjFPC -Sh `
    -FUoutput\NexusBotHostTests\fake-units `
    -FEoutput\NexusBotHostTests\bin `
    NexusTools\BotHost\tests\FakeCodexAppServer.lpr
  ```

- Run the complete registered deterministic BotHost suite through
  `NexusTestHost`:

  ```powershell
  $env:NEXUS_BOTHOST_FAKE_APP_SERVER = `
    (Resolve-Path output\NexusBotHostTests\bin\FakeCodexAppServer.exe)
  output\NexusTestHost\nxtest_host.exe `
    output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
    run-suite NexusBotHost
  ```

- Rebuild and run the deterministic NexusXMPP target if implementation changes
  any shared NexusXMPP code. The expected implementation is BotHost-local, so a
  shared network-library change would require explicit scope review first.
- Run the registered Openfire test when the local test environment is
  available, confirming LIST/STATUS omit `available`, valid INVITE/DISMISS still
  work, and runtime failure details remain representable. Do not treat the
  optional live test as a substitute for deterministic coverage.
- Manually start the GUI with an invalid catalog or deployment binding and
  confirm the visible startup error includes the actual catalog diagnostic,
  then restore valid configuration and confirm normal startup.
- Focused searches must show:
  - no `TNXBotCatalogEntry.Available` or entry load `Diagnostic`;
  - no `TNXBotStatus.Available` or XMPP `available` status attribute;
  - no `ValidationDiagnosticForDefinition` or partial-validation salvage;
  - no procedural `Provider <> 'Codex'` validation;
  - no `Bots.Mixed.nxscript` partial-load fixture;
  - no generic-only GUI catalog-load error;
  - all remaining `bceUnavailable` and status `Diagnostic` uses are tied to
    verified runtime/transport behavior.
- Run `git diff --check`, inspect the final diff for scope and net simplification,
  and create the required fresh source archive after approved implementation.

## Risks And Questions

- The candidate-list duplicate lookup must not call the published catalog's
  `Find` method while construction is in progress; doing so would compare
  against the wrong generation and compromise both duplicate detection and
  preservation of the old catalog.
- Replacing an owning `TObjectList` must transfer ownership exactly once. The
  candidate, former published entries, and failure cleanup must not free the
  same entry or leak a rejected candidate.
- `FDiagnostics` intentionally reflects the latest load attempt even when a
  failed attempt preserves older published entries. Callers must not interpret
  the presence of those diagnostics as corruption of the retained entries.
- Removing the XMPP `available` attribute is an intentional control-plane wire
  change. Both serializer and parser tests must change together; no compatibility
  alias or defaulted replacement field is required.
- Existing runtime `Diagnostic` and `bceUnavailable` names cover more than the
  rejected catalog model. Mechanical deletion would remove useful operational
  information, so each occurrence requires classification.
- GUI diagnostic propagation must retain the text before freeing the catalog.
- No unresolved design choice blocks implementation.

## Approval Gate

This work plan is for review only. No source implementation, build, test,
launch, archive, or source change begins until the human owner explicitly
authorizes implementation. Approval to implement does not authorize sub-agent
use.
