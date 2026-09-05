# Work Plan: NexusBot Provider-Neutral Host and Named Provider Registry

## Inputs

- Source request: `nexusbot-named-provider-factory-workplan-request (1).md`,
  supplied by the human owner from `C:\Users\kcollins\Downloads`.
- Related discussion/review notes: supporting the OpenAI API must not add
  provider-name branches to BotHost; construction-only indirection is
  insufficient because Codex/App Server terminology currently reaches the
  host, controller, state, GUI, configuration, control plane, and tests; the
  provider boundary must be tested promptly by a separate OpenAI work item.
- Existing constraints: follow the repository architecture protocol and Pascal
  standards; keep BotHost protocol data modeled through RTTI classes and
  published properties; register tests through `NexusBotHostTestModule`; do not
  create standalone test harnesses; do not add threads, polling, scheduling,
  synchronization infrastructure, dynamic packages, or an OpenAI provider in
  this work item.

## Summary

Replace BotHost's concrete `TNXCodexAppServer` contract with the smallest
provider-neutral contract used by its existing behavior. Introduce a typed,
BotHost-local name-to-class registry, register Codex as the first provider, and
require both NexusScript legality and linked provider registration before a bot
catalog is published.

The existing Codex implementation will directly implement the common provider
contract unless compilation or ownership analysis demonstrates a concrete
reason that direct inheritance is worse. BotHost will own the resulting
provider instance and interact with it only through provider-neutral lifecycle,
prompt, cancellation, state, diagnostic, answer, failure, and bot-control
operations. Codex process and protocol details remain inside
`TNXCodexAppServer`.

Stage 1 deliberately keeps the current Codex execution settings rather than
inventing a generalized configuration hierarchy. The common configuration
will carry the selected provider name and generic model identity; only the
Codex provider will read Codex executable/runtime settings. The next OpenAI
work item will use the demonstrated second configuration shape to determine
whether further separation is warranted.

## Verified Findings

- `TNXBotHost` directly owns and publishes `TNXCodexAppServer` through
  `FAppServer` and `AppServer`.
- Host construction creates the Codex object directly, assigns its limits and
  event handlers, and contains Codex-specific startup configuration.
- Host message admission tests concrete Codex states and submits/cancels
  prompts through concrete App Server methods.
- `TNXBotHostState` and `TNXBotHostSnapshot` expose
  `TNXCodexAppServerState`, `AppServerState`, and `AppServerDetail`.
- The detailed Codex state enumeration has nine values. Controller decisions
  depend only on stopped, ready, busy/working, and failed; the GUI additionally
  displays intermediate startup/stopping phases.
- `TNXBotController` uses App Server names in its action/phase state and status
  construction. It creates host configuration from a catalog entry and its
  deployment binding but does not currently copy the entry's provider name
  into that configuration.
- `TNXBotHostConfig` exposes `CodexModel`, `CodexExecutable`, and
  `ValidateAppServer`; `TNXBotDeploymentBinding` carries the Codex executable
  and runtime directory.
- `TNXBotCatalog.Load` now performs atomic fail-fast publication, but
  `ValidateBinding` still requires Codex executable/runtime fields for every
  provider and does not verify provider registration.
- `Bot.Language.nxscript` is the current authority for legal provider names
  through `AllowedValues: [Codex]`.
- The GUI and live test reach through `FHost.AppServer` to assign
  `OnBotControl`, demonstrating that bot control has not yet crossed a
  provider-neutral host boundary.
- `TNXBotStatus` and the XMPP status representation expose the field/attribute
  names `AppServerState` and `app-server`.
- The existing `TNXClassFactory` has one global, untyped key space shared by
  JSON-RPC request/message classes, LSP transports, and other factory objects.
  It is therefore not an appropriate registry for provider names.
- The Codex class is a plain class with a virtualizable parameterless
  constructor shape, so direct descent from a provider base is structurally
  feasible. No verified ownership requirement currently demands a wrapper.
- `TNXCodexAppServer.SubmitPrompt` transfers the supplied prompt into an owned
  command and frees it when enqueueing fails. The provider contract must state
  this ownership behavior rather than leaving it implicit.
- `TNXCodexAppServer` owns the only provider execution thread currently in the
  product. It isolates the blocking child-process pipe interaction from the GUI
  and remains inside the accepted threading boundary.

## Architecture Problem

The catalog already declares a provider, but the runtime model behaves as if
every provider is the Codex App Server. Hiding only the constructor would leave
the host and every consumer coupled to Codex lifecycle names, detailed Codex
state, process configuration, and concrete event access. Adding OpenAI on that
foundation would either introduce provider-name branches throughout BotHost or
force an HTTP Responses implementation to masquerade as an App Server.

Provider legality and provider availability are also incomplete as a combined
configuration invariant. NexusScript can establish that a provider name is
legal, while the linked executable determines whether a class exists for that
name. Because both facts are local and deterministic, publishing a catalog
before checking registration would violate the catalog's fail-fast contract.

Finally, deployment validation currently assumes every provider requires a
Codex executable and runtime directory. That policy belongs to the Codex
provider class, not to the catalog. Leaving it in the catalog would recreate
provider dispatch as soon as OpenAI gains different required settings.

## Target Contract

- Owner: `TNXBotHost` owns exactly one `TNXBotProvider` instance for its entire
  lifetime and frees it only after synchronous provider shutdown.
- Selection:
  - `TNXBotHostConfig.Provider` contains the exact case-sensitive catalog
    provider name;
  - the host constructs the provider through the typed provider registry;
  - no host or controller `if`/`case` selects provider behavior.
- Registry:
  - maps an exact provider name to `TNXBotProviderClass`;
  - supports register, registered/find, and create operations only;
  - rejects blank names, nil classes, duplicates, and unknown lookups clearly;
  - owns no provider instances and performs no execution, routing, discovery,
    capability negotiation, or configuration storage;
  - remains separate from the global `TNXClassFactory` key space.
- Provider lifecycle:
  - provider configuration occurs once after construction and before start;
  - reusable start and stop remain commands whose acceptance is reported to
    the caller;
  - final `Shutdown` synchronously quiesces provider-owned producers and
    permits no later callback into BotHost;
  - BotHost destruction orders shutdown, provider release, and configuration
    release so a provider cannot retain a freed configuration reference.
- Provider operations:
  - submit a `TNXBotPrompt`;
  - cancel all prompts with a reason;
  - cancel prompts for one room with a reason;
  - expose only operations currently required by BotHost;
  - retain Codex-only helpers such as raw interrupt, command count, frame
    limits, and JSON-RPC tool-result submission on the Codex class rather than
    adding them to the common contract.
- Prompt ownership: submitting a non-nil prompt transfers ownership to the
  provider whether the provider accepts or rejects the work, preserving the
  current Codex command ownership behavior.
- Provider events:
  - state change with provider-neutral state and optional detail;
  - diagnostic text;
  - final answer tied to the submitted prompt;
  - prompt failure tied to the submitted prompt;
  - bot-control request using the existing typed operation, authorization,
    completion, result, and token contracts from `tpNXBotControl`.
- State flow:
  - the host-facing states are `stopped`, `starting`, `ready`, `working`,
    `stopping`, and `failed`;
  - Codex initializing, model-resolution, and thread-creation phases collapse
    to `starting`, with useful phase text retained as detail/diagnostic output;
  - Codex `busy` becomes provider `working`;
  - controller decisions use only the provider-neutral state;
  - detailed provider internals do not expand the common enum.
- Configuration:
  - rename `CodexModel` to provider-neutral `Model` because the catalog model
    value is already provider-supplied;
  - add the selected `Provider` name to `TNXBotHostConfig` and populate it from
    the catalog entry;
  - retain the current Codex executable/runtime fields during Stage 1, but only
    `TNXCodexAppServer` may read or validate them after host construction;
  - do not add a configuration descriptor, polymorphic persisted hierarchy,
    string bag, RTTI side channel, or anticipated OpenAI fields;
  - the later OpenAI implementation may reshape provider-specific
    configuration when two real shapes exist.
- Catalog validation:
  - NexusScript remains the only authority for whether the provider name is
    legal;
  - the typed registry is the authority for whether its implementation is
    linked;
  - after dialect validation and before publication, the catalog resolves the
    provider class and asks that class to validate its locally knowable
    provider-specific deployment requirements;
  - common deployment validation such as XMPP identity, resource, nickname,
    TLS/endpoint combinations, and secret environment-variable name remains in
    the catalog;
  - Codex validates its executable and runtime requirements without a provider
    name branch in the catalog;
  - missing registration or provider-specific configuration failure rejects
    the complete candidate catalog.
- Control flow: BotHost owns the common bot-control event and wires it into the
  provider. UI and live-test code assign the handler through the host contract,
  never by retrieving or casting the concrete provider.
- Status contract: runtime status uses `ProviderState` and the XMPP
  `provider-state` attribute. Codex-specific App Server wording remains only in
  Codex implementation diagnostics and documentation that actually describes
  its process protocol.

## Scope

- `NexusTools/BotHost/src/tpNXBotHost.pas`
  - replace the Codex App Server enum with the provider-neutral state enum;
  - retain the existing bot-prompt source of truth unless moving it is required
    to avoid a unit dependency cycle.
- New `NexusTools/BotHost/src/obNXBotProvider.pas`
  - define the provider base, common event types, protected event dispatch, and
    the small typed provider registry;
  - keep registration and construction in this one unit unless Pascal unit
    dependencies prove that a separate registry unit materially simplifies the
    design.
- `NexusTools/BotHost/src/obNXCodexAppServer.pas`
  - directly implement the provider contract;
  - register as exact name `Codex`;
  - own Codex-specific validation and configuration consumption;
  - collapse detailed public states while retaining useful details;
  - preserve its process, JSON-RPC, request, prompt, tool, and shutdown logic.
- `NexusTools/BotHost/src/obNXBotHost.pas`
  - own `TNXBotProvider` instead of `TNXCodexAppServer`;
  - construct it by configured provider name;
  - expose provider-neutral lifecycle/state/control surfaces;
  - remove the concrete App Server property and all Codex-specific access.
- `NexusTools/BotHost/src/obNXBotHostConfig.pas`
  - add provider identity, rename generic model state, and replace App Server
    validation vocabulary;
  - retain Codex execution fields for the Codex implementation during this
    stage without generalizing them.
- `NexusTools/BotHost/src/obNXBotHostState.pas`
  - store and snapshot provider-neutral state and detail;
  - own the single provider-state-to-text conversion.
- `NexusTools/BotHost/src/obNXBotCatalog.pas`
  - require a registered provider before atomic publication;
  - divide common deployment validation from polymorphic provider-specific
    class validation;
  - remove unconditional Codex execution-field validation.
- `NexusTools/BotHost/src/obNXBotController.pas`
  - populate provider-neutral configuration;
  - rename App Server phases/actions and use provider-neutral state;
  - preserve current controller lifecycle behavior without provider dispatch.
- `NexusTools/BotHost/src/tpNXBotControl.pas`
  - rename status `AppServerState` to `ProviderState`.
- `NexusTools/BotHost/src/obNXXMPPBotControl.pas`
  - rename the status wire attribute from `app-server` to `provider-state` in
    both serialization and parsing.
- `NexusTools/BotHost/src/obNXBotControlInterpreter.pas`
  - render provider state without App Server terminology.
- `NexusTools/BotHost/uiNXBotHostMain.pas`
  - use provider-neutral status, controls, and host-level bot-control wiring;
  - retain the present layout and behavior.
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`
  - add registered deterministic provider/registry/catalog tests and revise
    existing host/controller/control-plane expectations.
- `NexusTools/BotHost/tests/tsNXBotHostLiveTests.pas`
  - update provider-neutral host access and status expectations without
    broadening the existing Openfire/Codex scenario.
- Test-only NexusScript catalog/language fixtures under
  `NexusTools/BotHost/catalog/` only if required to demonstrate a provider name
  that is dialect-valid but deliberately unregistered.
- `NexusTools/BotHost/README.md`
  - document the provider-neutral host boundary and named registration;
  - retain App Server terminology in the Codex-specific protocol sections.
- `NexusTools/BotHost/NexusBotHost.lpi` and
  `NexusTools/BotHost/tests/NexusBotHostTestModule.lpi` only as needed to add
  the new provider unit and test fixtures to their project metadata/search
  paths.

## Out Of Scope

- OpenAI provider implementation, HTTP calls, Responses API objects, streaming,
  credentials, configuration, conversation state, or function-call mapping.
- Any additional provider implementation, fallback, failover, health checking,
  discovery, or dynamic loading.
- A generalized factory, plugin manager, provider manager, dependency-injection
  container, capability model, descriptor system, or service locator.
- A universal provider configuration hierarchy or speculative OpenAI settings.
- Changes to Codex JSON-RPC schemas, process transport, typed RTTI/property data
  contracts, request deadlines, or tool semantics.
- Changes to NexusScript grammar, compiler behavior, or general validator
  semantics.
- XMPP behavior other than the provider-state field name in the existing BotHost
  status control plane.
- GUI redesign, catalog/roster redesign, hot reload, or unrelated BotHost
  cleanup.
- New threads, queues, timers, polling loops, schedulers, event buses, or
  synchronization constructs.
- Compatibility aliases for the removed Codex/App Server host API or status
  field names.
- Standalone test runners or harness applications.

## Staged Implementation Plan

### Stage 1: Establish common provider types and the typed registry

1. Replace `TNXCodexAppServerState` in the shared BotHost type unit with the
   six-state provider-neutral enum and provider-neutral state-name function.
2. Add `TNXBotProvider` with the common configuration, lifecycle, prompt,
   cancellation, state, diagnostic, final-answer, prompt-failure, and
   bot-control surface described in the target contract.
3. Move the common event type definitions out of the Codex unit. Keep the
   bot-control payload composed from existing `tpNXBotControl` types; do not
   introduce JSON or untyped payloads.
4. Implement a case-sensitive typed registry backed by the smallest suitable
   owned collection. Provide register, registered/find, and create operations
   with explicit duplicate/unknown errors.
5. Do not derive the registry from or delegate it to `TNXClassFactory`; this
   avoids its unrelated global key space and untyped casts.

### Stage 2: Make Codex the first provider implementation

1. Make `TNXCodexAppServer` descend directly from `TNXBotProvider` and call its
   inherited construction/destruction paths.
2. Implement only the common virtual operations using the existing Codex
   command ownership and execution paths. Keep Codex-only public/test helpers
   on the concrete class.
3. Consume `CodexExecutable`, `RuntimeDirectory`, limits, model, and instructions
   inside the Codex provider rather than in `TNXBotHost`.
4. Implement Codex's provider-specific deployment/configuration validation as a
   virtual class operation usable before an instance is constructed.
5. Replace Codex's public detailed state enum with provider state. Emit
   startup-phase detail while mapping initializing, resolving-model, and
   creating-thread transitions to `starting`; map busy to `working`.
6. Route event emission through the base provider's protected typed dispatch
   methods without adding a queue, pump, or callback adapter object.
7. Register the class under the exact case-sensitive name `Codex` during normal
   unit initialization, following existing Nexus self-registration practice.
8. Add an adapter only if direct descent produces a demonstrated Pascal
   dependency or ownership conflict that cannot be removed more simply. If
   that occurs, stop and document the concrete conflict before expanding the
   approved architecture.

### Stage 3: Replace the host's concrete provider dependency

1. Add `Provider` and provider-neutral `Model` to `TNXBotHostConfig`; remove the
   `CodexModel` name and `ValidateAppServer` vocabulary without compatibility
   aliases.
2. Populate the provider and model from `TNXBotCatalogEntry` in controller and
   distinguished-GUI host construction.
3. Have `TNXBotHost` create the selected provider through the typed registry,
   configure it once, attach its typed event handlers, and own it.
4. Replace `FAppServer`, `AppServer`, `StartAppServer`, `StopAppServer`, and
   App Server callback methods with provider-neutral equivalents.
5. Expose bot-control handler assignment through `TNXBotHost`, so callers no
   longer retrieve the provider object solely to wire an event.
6. Convert room-message readiness, prompt submission, disconnect/leave
   cancellation, and shutdown to the common provider contract.
7. Preserve the existing synchronous shutdown ordering and ensure the provider
   is freed before any configuration it may reference.
8. Remove any obsolete Codex unit dependency from the host interface and
   implementation.

### Stage 4: Enforce provider authority during catalog loading

1. After successful NexusScript dialect validation, resolve every candidate
   entry's provider through the registry before publishing the catalog.
2. Report an understandable diagnostic naming the bot and unregistered provider
   when lookup fails; reject the entire unpublished candidate.
3. Keep common XMPP/deployment checks in `TNXBotCatalog.ValidateBinding`.
4. Move the unconditional Codex executable/runtime requirements out of the
   catalog and invoke the resolved provider class's validation hook instead.
5. Accumulate independent provider/binding diagnostics where the existing
   atomic loader can do so simply, but publish nothing when any error exists.
6. Preserve the distinction between an illegal provider rejected by the
   dialect and a legal but unlinked provider rejected by registry validation.
7. Do not create provider instances during catalog validation and do not add
   availability state to entries.

### Stage 5: Provider-neutralize state and consumers

1. Replace host snapshot `AppServerState`/`AppServerDetail` with
   `ProviderState`/`ProviderDetail` and update its setter and formatter.
2. Rename controller App Server phases/actions to provider phases/actions and
   preserve the current INVITE state transitions using provider-neutral values.
3. Rename `TNXBotStatus.AppServerState` to `ProviderState` and update human
   status rendering and Codex typed tool-result text.
4. Replace the XMPP status attribute `app-server` with `provider-state` in both
   serializer and parser. Do not retain a compatibility attribute.
5. Update the GUI display, Start/Stop labels, handlers, and activity messages to
   provider vocabulary while leaving Codex-internal diagnostics factual.
6. Update live-test and distinguished-host bot-control assignment to use the
   host-level provider-neutral event.
7. Review README occurrences individually: generic host/controller descriptions
   become provider-neutral, while descriptions of the actual Codex App Server
   protocol and fixture keep their correct names.

### Stage 6: Registered tests and subtraction pass

1. Add registry tests for exact `Codex` registration, typed lookup/creation,
   case sensitivity, duplicate rejection, blank/nil registration rejection,
   and unknown lookup failure.
2. Use a test-only NexusScript language/catalog pair, if necessary, to prove a
   dialect-valid but deliberately unregistered provider fails catalog loading
   before publication. Do not add `OpenAI` to the production dialect merely to
   manufacture this test.
3. Preserve a separate test proving an illegal provider continues to fail in
   ordinary NexusScript dialect validation before registry validation.
4. Revise host/controller tests to exercise the provider contract, generic
   state, start/stop, prompt ownership, cancellation, final answer/failure,
   bot-control, and synchronous final shutdown.
5. Keep the existing concrete Codex process test for Codex-specific JSON-RPC,
   pipe, and detailed runtime behavior; provider abstraction does not replace
   concrete implementation coverage.
6. Update LIST/STATUS/INVITE/DISMISS, interpreter, Codex result formatting, and
   XMPP serialization/parsing assertions for `ProviderState` and
   `provider-state`.
7. Remove dead App Server forwarding, duplicate state conversion, and obsolete
   Codex-specific host helpers exposed by the new boundary. Do not add
   compatibility shims.
8. Compare added and removed implementation LOC. If the net increase exceeds
   the request's rough 100-line ceiling, inspect first for wrapper forwarding,
   duplicate registries/state, unnecessary configuration objects, or invented
   abstractions and simplify before accepting the result.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan does not authorize
spawning, resuming, messaging, or delegating to sub-agents. Plan approval and
implementation approval do not grant sub-agent permission; the human owner
must explicitly request sub-agent use in the current conversation.

## Verification Plan

- Build the BotHost GUI and registered BotHost test module:

  ```powershell
  lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
  lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
  ```

- Build the existing fake Codex App Server external-process fixture used by the
  registered pipe integration test. It remains a fixture, not a standalone test
  harness:

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

- Run the registered Openfire/Codex live test when the local services and
  credentials are available. Confirm the existing bot can start, connect, join,
  answer, expose bot control, report provider-neutral status, leave, and shut
  down without a callback after shutdown returns.
- Manually launch the GUI and verify Start Provider, Stop Provider, provider
  state/detail, current Codex model identity, activity copy behavior, and the
  normal distinguished NexusBot lifecycle.
- Treat the following as focused structural inspections, not artificial unit
  tests:
  - `TNXBotHost` and `TNXBotController` contain no `TNXCodexAppServer`
    dependency and no provider-name `if`/`case` dispatch;
  - no concrete `AppServer` property or external `Host.AppServer` reach-through
    remains;
  - the global `TNXClassFactory` contains no provider registrations;
  - the provider registry contains only names and typed class references;
  - catalog validation contains no unconditional `CodexExecutable` or
    `RuntimeDirectory` requirement and calls provider-class validation without
    provider-name branching;
  - no host-facing `TNXCodexAppServerState`, `AppServerState`, `app-server`,
    `StartAppServer`, or `StopAppServer` remains;
  - Codex-specific App Server wording remains only in the concrete Codex
    implementation, its protocol/tests, and accurate documentation;
  - no new thread, poller, dispatcher, queue, timer, scheduler, event bus,
    critical section, or synchronization framework was added for provider
    abstraction;
  - no compatibility alias or wrapper survives without a verified requirement.
- Run `git diff --check`, inspect the final diff for ownership and naming, record
  added/removed LOC for the feature, and create the required fresh source
  archive after approved implementation.

## Risks And Questions

- Provider unit dependencies must be arranged without circular interface uses.
  Shared enums/event signatures belong in the existing `tp...` type units; the
  provider object belongs in an `ob...` unit. Moving `TNXBotPrompt` is permitted
  only if required to establish that dependency direction.
- Direct Codex inheritance is the expected result. An adapter would increase
  object ownership and event forwarding and is not authorized merely for
  stylistic separation.
- The common provider configuration operation will necessarily receive enough
  Stage 1 configuration to start Codex. This is intentionally temporary and
  must not become justification for a universal provider property bag.
- Self-registration depends on the Codex provider unit being linked before
  catalog loading. Both the GUI and test module project uses must make that
  dependency explicit; registration must not rely accidentally on an unrelated
  transitive unit.
- A test-only dialect must have a distinct fixture identity and must not change
  the production list of legal providers. Its purpose is to prove the boundary
  between dialect legality and executable registration.
- Renaming `app-server` to `provider-state` is an intentional BotHost control
  plane wire change. Serializer, parser, typed status, human rendering, Codex
  result formatting, and tests must change together; no legacy dual field is
  required.
- Collapsing Codex startup states must preserve useful operator information in
  detail or diagnostics without turning those phases back into common enum
  values.
- The current provider thread remains justified solely by blocking child-process
  pipe work that must not freeze the GUI. This plan neither authorizes another
  thread nor treats the provider abstraction as an execution boundary.
- No unresolved human design choice blocks implementation. If the compiler
  demonstrates that direct inheritance creates a material dependency or
  ownership defect, implementation must pause rather than silently introduce
  the optional wrapper.

## Approval Gate

This work plan is for review only. No source implementation, build, test,
launch, archive, or implementation change begins until the human owner
explicitly authorizes it. Approval to implement does not authorize sub-agent
use.
