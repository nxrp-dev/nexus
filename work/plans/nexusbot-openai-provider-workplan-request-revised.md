# Work Plan: NexusBot OpenAI Responses Provider

## Owner correction: Synapse transport

On 2026-09-06 the owner corrected the transport decision: all Nexus socket
work uses Synapse. The WinHTTP-specific selections in the original approved
plan below are superseded by a Synapse `THTTPSend` implementation using the
existing OpenSSL 3 provider. The correction preserves the executor boundary,
blocking-provider worker, independent 1 MiB protocol response bound, request
timeout, typed RTTI request/response model, and provider behavior. TLS peer and
hostname verification remain mandatory. `OpenAICAFile` supplies the explicit
typed deployment path to a public CA bundle, independent of the XMPP server CA
file. The Windows-only provider guard is removed; no second socket stack is
introduced.

## Inputs

- Source request:
  `C:\Users\kcollins\Downloads\nexusbot-openai-provider-workplan-request-revised.md`.
- Related discussion/review notes: the accepted named-provider factory is the
  foundation; the first OpenAI milestone is ordinary non-streaming
  conversation only; `Model` remains catalog-owned; room selection remains an
  INVITE/lifecycle concern; continuity may use one provider-local previous
  response ID; and “no persistence” means no local persisted conversation
  state, not an unsupported claim about OpenAI-side retention.
- Official OpenAI documentation consulted:
  [Create a model response](https://developers.openai.com/api/reference/resources/responses/methods/create)
  and [Conversation state](https://developers.openai.com/api/docs/guides/conversation-state).
  The current API contract supports `POST /v1/responses`, bearer
  authentication, `instructions`, string `input`, `previous_response_id`, and
  a heterogeneous `output` array. The documentation states that response
  objects are retained for 30 days by default and shows response chaining with
  `previous_response_id` and retained responses.
- Existing constraints: follow the Nexus architecture protocol and Pascal
  standards; RTTI classes and published properties are the JSON contract; keep
  tests inside `NexusBotHostTestModule`; do not create a standalone test
  harness; do not persist secrets; do not add sub-agents, a generic provider or
  HTTP framework, retries, tools, streaming, or unrelated refactoring.

## Summary

Add `TNXOpenAIProvider` as the second concrete implementation of the accepted
`TNXBotProvider` contract. It will issue one non-streaming Responses API call
at a time on one provider-owned worker, deliver answers and failures through
the existing direct Pascal events, and retain at most one previous response ID
in memory for provider-instance conversation continuity.

The provider will use a small OpenAI-specific synchronous HTTP executor backed
by Windows WinHTTP for this Win64 milestone. WinHTTP supplies the blocking
operation that justifies the worker and uses the Windows certificate store and
hostname checks by default. The implementation will not disable those checks,
will not alter NexusXMPP trust configuration, and will not introduce a shared
HTTP layer.

The production catalog will contain both `NexusBot` using `Codex` and
`OpenAIBot` using `OpenAI`. The GUI’s existing default-configuration bootstrap
will create the second bot’s complete deployment binding before the fail-fast
catalog is loaded. Actual XMPP and OpenAI secrets remain environment variables.
The existing controller can then launch the new bot into the current room with
`invite OpenAIBot` without provider-specific controller behavior.

## Verified Findings

- `TNXBotProvider` already supplies the required lifecycle, prompt ownership,
  cancellation, state, diagnostic, final-answer, failure, and optional
  bot-control event contract. No common provider method is missing for basic
  OpenAI conversation.
- `TNXBotProviderRegistry` is typed and case-sensitive. Concrete providers
  self-register during unit initialization, and `NexusBotHost.lpr` explicitly
  links the Codex unit to guarantee its registration.
- `TNXBotHost` owns only `TNXBotProvider`, constructs it by configured name,
  and routes final answers to NexusXMPP without knowing the provider type.
- `TNXBotController.CreateConfiguredHost` copies catalog `Model` and
  `Provider` into a private `TNXBotHostConfig`, while deployment-only values
  come from `TNXBotDeploymentBinding`. This is the correct path for the new
  API-key environment-variable name.
- `TNXBotCatalog.Load` performs atomic publication. It validates common XMPP
  deployment fields, resolves the exact registered provider class, and calls
  that class’s `ValidateDeployment` hook before publishing any entry.
- `Bot.Language.nxscript` currently permits only `Codex`.
  `BotsUnsupportedProvider.Bot.nxscript` deliberately uses `OpenAI` as its
  dialect-invalid value, so that fixture and assertion must change when
  `OpenAI` becomes legal.
- `Bots.nxscript` currently contains only `NexusBot`. The GUI unconditionally
  selects this file and bootstraps only the `NexusBot` deployment binding
  before loading it. Adding a second definition without bootstrapping a second
  binding would reject the complete default catalog.
- The current default deployment already assumes the local Openfire setup:
  `test1@nexus.local`, the permanent `nexus-test@conference.nexus.local` room,
  and the checked-in Openfire CA certificate. A separate `test2@nexus.local`
  identity is available for the OpenAI bot; its password must remain outside
  persisted configuration.
- BotHost already depends on Synapse, and `THTTPSend` can perform blocking
  HTTPS. Its selected OpenSSL 3 implementation enables peer/hostname checking
  only after the caller supplies trust configuration, and it loads roots only
  from `CertCAFile`. BotHost’s current `CAFile` is the Openfire/XMPP private
  trust file, not a public web-PKI bundle. Reusing it for the OpenAI endpoint
  would not satisfy the HTTPS contract.
- Windows WinHTTP provides a smaller correct transport for the current target:
  synchronous request calls, phase timeouts, status/header access, response
  reads, default Windows system trust, and hostname validation. It requires no
  new third-party dependency or public-CA deployment field.
- The raw Responses API result is not an SDK `output_text` convenience value.
  Its `output` array can contain multiple item kinds. Assistant messages contain
  an ordered `content` array whose relevant initial kinds are `output_text` and
  `refusal`.
- The official conversation-state documentation supports chaining with
  `previous_response_id`. It also makes OpenAI-side retention relevant; a
  provider-local ID is not the same as a stateless API interaction.
- The current Codex provider owns a worker because child-process I/O blocks.
  The OpenAI provider has an independently valid blocking boundary: a network
  request must not block NexusXMPP processing, other bot providers, or the GUI.
  No existing legitimate thread can own that separate HTTP conversation.
- Provider events are already invoked directly by the concrete provider and
  consumed by BotHost. NexusUI does not need a new message type, queue, or pump.

## Architecture Problem

The host can now select providers correctly, but no registered class translates
the common prompt contract into an OpenAI Responses request. There is also no
typed RTTI model for the raw request/result objects, no secure direct HTTP
transport, and no OpenAI deployment credential reference.

The implementation must isolate one blocking HTTP operation without converting
the provider abstraction into an execution framework. It must also preserve
fail-fast catalog publication: making `OpenAI` legal in NexusScript requires a
linked provider implementation and a complete binding before the production
catalog can load.

Conversation continuity creates a narrower ownership issue. A single provider
instance may retain one response ID for the current conversational path, but
that cannot silently become a permanent, cross-room, or cross-process
conversation architecture. The ID must advance only when a response is
completed, accepted, and delivered as usable assistant text.

## Target Contract

### Provider ownership and registration

- Add `TNXOpenAIProvider = class(TNXBotProvider)` with exact provider name
  `OpenAI`.
- Register it with `TNXBotProviderRegistry` in the unit’s initialization.
- Link the unit explicitly from `NexusBotHost.lpr` and from the registered test
  module path so initialization cannot be removed as apparently unused.
- `TNXBotHost`, `TNXBotController`, `TNXBotCatalog`, XMPP control code, and GUI
  lifecycle handlers remain provider-neutral. None may branch on `OpenAI`.
- `TNXBotHost` continues to own the provider; the OpenAI provider owns its HTTP
  executor, prompt queue, active prompt, worker, wake event, API credential in
  memory, and previous response ID.

### Typed Responses API contract

- Add `NexusTools/BotHost/src/protocol/obNXOpenAIResponses.pas` using
  `TNXJSONObject`, `TNXJSONValue`, `TNXJSONArray`, and published RTTI
  properties.
- Model only the fields required by this milestone:
  - `TNXOpenAIResponseRequest`: `model`, `instructions`, `input`, optional
    `previous_response_id`, explicit `store`, and explicit non-streaming
    `stream`;
  - `TNXOpenAIResponse`: `id`, `status`, optional/null `error`, optional/null
    `incomplete_details`, and `output`;
  - `TNXOpenAIResponseError`: `message`, `type`, and the string/null fields
    needed for useful bounded diagnostics;
  - `TNXOpenAIIncompleteDetails`: `reason`;
  - an output-item base carrying `type`, plus a message descendant carrying
    `id`, `status`, `role`, and `content`;
  - a content-item base carrying `type`, plus `output_text` and `refusal`
    descendants carrying `text` and `refusal` respectively;
  - typed output/content arrays that select descendants from each item’s
    documented `type` discriminator.
- Unknown output or content kinds remain represented by their typed base
  objects and are ignored by this milestone. Do not retain arbitrary raw JSON
  as a substitute for the RTTI model and do not model unused annotations,
  logprobs, tools, usage, or modality structures.
- Request construction assigns every required wrapper’s value/assigned state.
  The initial request omits `previous_response_id`; later requests include the
  retained ID. `instructions` is assigned on every request.
- Send `store: true` deliberately so `previous_response_id` continuity uses
  the documented retained-response path. This accepts current OpenAI-side
  response retention while adding no local disk persistence. If the owner does
  not accept that service-side retention, this plan must be revised to remove
  chaining or carry history locally; it must not claim that `store: false` and
  response-ID chaining are equivalent without current documentation proving it.
- A response is successful only when the top-level status is `completed`, no
  response error is present, the ID is nonempty, and at least one nonempty
  `output_text` fragment occurs inside completed assistant message output.
- Extract text by traversing output items and message content in source order
  and concatenating `output_text.text` values without reordering or inventing
  an SDK-only field. Preserve UTF-8 and apply the existing configured answer
  byte limit before raising `FinalAnswer`.
- Record refusal content only to produce a bounded failure reason. A
  refusal-only result, incomplete result, missing text, wrong role/status, or
  structurally malformed result calls `PromptFailed`; it is never reported as
  a successful empty answer.
- Parse non-success HTTP bodies through a typed OpenAI error envelope when
  possible. Fall back to the HTTP status and a bounded non-secret diagnostic;
  never log an entire unexpected response body.

### Conversation continuity

- `FPreviousResponseID` belongs to one `TNXOpenAIProvider` instance and exists
  only in memory.
- The provider serializes requests, so at most one response lineage update can
  occur at a time.
- Advance the ID only after a completed response has yielded usable assistant
  text and the active prompt has not been cancelled.
- Do not advance it for transport/API errors, authentication failure,
  incomplete or malformed responses, refusal-only responses, missing text, or
  a late response discarded after cancellation.
- Clear the ID when the provider reaches stopped state and during final
  shutdown. Restart begins a new API conversation.
- This contract deliberately mirrors the current single-provider-instance
  conversation path. It does not define future room-specific threads,
  persistent history, conversation recovery, or multiple independent
  conversations per provider.

### OpenAI-specific HTTP executor

- Keep the production executor in `obNXOpenAIProvider.pas` unless separating it
  demonstrably reduces the compiled unit and test seam. It remains named and
  typed for OpenAI and exposes no general HTTP abstraction.
- For Win64, call the Windows WinHTTP API synchronously from the provider
  worker against the fixed endpoint
  `https://api.openai.com/v1/responses`.
- Set `Content-Type: application/json`, a NexusBotHost user agent, and
  `Authorization: Bearer <key>`. The bearer value is constructed only at the
  transport boundary and is never added to request JSON, state detail, test
  output, or diagnostics.
- Use WinHTTP’s default certificate-chain and hostname validation. Do not set
  any option that ignores unknown CAs, wrong usage, dates, or common-name/
  hostname mismatches.
- Apply `RequestTimeoutMS` to WinHTTP resolution, connection, send, and receive
  phases. Limit the accumulated HTTP response body to an independent, fixed,
  generously sized protocol-safety bound that accommodates the complete
  Responses API JSON envelope; reject an oversized body rather than growing
  without limit. Apply `AnswerMaximumBytes` separately to the extracted
  assistant text. Neither limit is derived from the other.
- Return a small OpenAI-specific result consisting of transport success/error,
  HTTP status, and response bytes. The provider, not the transport, owns API
  response interpretation and provider state.
- On non-Windows targets, compile the provider but reject Start with a clear
  unsupported-platform failure for this milestone. Do not add an unverified
  second TLS stack. Cross-platform direct HTTP is a later explicit decision.
- Provide an owned OpenAI-specific executor injection constructor or equally
  small protected virtual execution seam so registered tests can return known
  status/body values and coordinate a blocked request. The default registry
  constructor always creates the real executor. The seam may not escape the
  OpenAI unit or become a shared transport interface.

### Worker, handoff, and lifecycle

- Add exactly one `TNXOpenAIProviderThread`, owned by its provider, with
  `FreeOnTerminate = False`.
- The blocking operation is the synchronous WinHTTP call. NexusXMPP, other bot
  providers, and the GUI must continue while it waits; this is the complete
  justification for the thread.
- Use one bounded owned prompt list, one provider-local wake event, and one
  small critical section. The critical section protects only list membership,
  acceptance/shutdown flags, the active-prompt cancellation marker/reason, and
  transfer of the active prompt pointer. It is never held across HTTP, JSON
  processing, callbacks, state events, waits, or thread joining.
- `SubmitPrompt` preserves the accepted provider contract: a non-nil prompt’s
  ownership transfers to the provider whether it is accepted or rejected. It
  appends within `PromptCapacity`, signals the worker, and frees rejected work.
- The worker waits on its wake event instead of polling or sleeping. It extracts
  one prompt under the guard, releases the guard, changes state to `working`,
  constructs/executes/parses the request, then invokes `FinalAnswer` or
  `PromptFailed` directly outside the guard.
- No result queue, application pump, controller poller, deadline service,
  scheduler, or general task system is introduced.
- `Start` accepts only a stopped/failed provider, changes state to `starting`,
  and starts the owned worker. The worker reads the API key from the configured
  environment-variable name, never persists it, and reports `ready` or
  `failed`. Restart after failure joins/releases the already-finished worker
  before creating a replacement.
- `Stop` is nonblocking with respect to an active HTTP call. It closes prompt
  admission, cancels queued work, marks active work cancelled, signals the
  worker, and reports `stopping`. The worker exits after any bounded active
  HTTP call returns, clears credential/continuity state, and reports `stopped`.
  The provider retains the finished thread object until restart or Shutdown
  joins and frees it.
- `Shutdown` closes admission once, extracts/fails queued prompts, marks an
  active prompt cancelled, terminates and signals the worker, waits for the
  owned thread, frees it, clears the credential and response ID, and only then
  destroys the queue/event/guard. No callback may occur after Shutdown returns.

### Cancellation

- `CancelPrompts` and `CancelRoomPrompts` remove matching queued prompts under
  the small guard, then invoke `PromptFailed` and free them outside it.
- If the active prompt matches, store only its cancellation marker and reason.
  When HTTP returns, the worker discards response data, does not advance
  continuity, emits exactly one prompt failure, and frees the prompt.
- Do not close a WinHTTP request handle from an unrelated thread unless direct
  implementation testing proves that exact handle lifetime safe. The approved
  baseline does not require in-flight abort; Stop and Shutdown may wait for the
  locally configured WinHTTP phase timeouts.
- Cancellation is not a new framework and has no token registry, polling loop,
  sleeper thread, or external deadline owner.

### Provider state and failures

- Use only `bpsStopped`, `bpsStarting`, `bpsReady`, `bpsWorking`,
  `bpsStopping`, and `bpsFailed`.
- Missing API-key environment-variable name is a catalog validation error.
  A named variable with no value is a Start-time configuration failure.
- Missing key, HTTP 400/401/403/404 configuration/authentication failures,
  certificate/hostname validation failure, unsupported platform, and a
  structurally incompatible response place the provider in `failed`, fail the
  active and queued prompts, and require stop/restart after correction.
- Timeouts, connection loss, HTTP 408/409/429, and HTTP 5xx fail only the active
  prompt and return an otherwise usable provider to `ready`.
- A valid completed refusal, incomplete response, or completed response with no
  usable text is prompt-local and returns the provider to `ready`.
- Diagnostics are bounded and may include HTTP status, OpenAI error type/code,
  and request ID when available. They may not include the key, Authorization
  header, or raw unbounded response.

### Configuration, catalog, and default deployment

- Add the published RTTI property
  `OpenAIAPIKeyEnvironmentVariable` to `TNXBotDeploymentBinding` and
  `TNXBotHostConfig`. Do not add an API-key value property.
- `TNXBotController.CreateConfiguredHost` and `UpdateDeployment` copy that one
  field alongside existing deployment values. `Model` continues to come only
  from `TNXBotCatalogEntry`; room continues to come from INVITE/lifecycle.
- `TNXOpenAIProvider.ValidateDeployment` rejects a blank environment-variable
  name and names containing `=`. It does not read the variable or contact the
  network during catalog loading.
- Add `OpenAI` beside `Codex` in `Bot.Language.nxscript`.
- Add `OpenAIBot` to `Bots.nxscript`, using `Provider: OpenAI`, a concrete
  catalog model (initially the currently selected `gpt-5.6-luna`, subject to
  the owner’s API account availability), and concise bot instructions.
- Choose the real-default-binding strategy rather than an opt-in catalog. In
  `TNXBotHostUI.Create`, ensure a persisted `OpenAIBot` binding exists before
  catalog load, using:
  - `test2@nexus.local` as the separate local XMPP identity;
  - nickname `OpenAIBot` and resource `NexusOpenAIBotHost`;
  - `NEXUS_OPENAI_BOT_XMPP_PASSWORD` as the XMPP secret variable name;
  - `OPENAI_API_KEY` as the API secret variable name;
  - the same current Openfire endpoint, TLS mode, and XMPP CA file as the
    distinguished host.
- Persist only those environment-variable names. The operator supplies values,
  for the current local server for example:

  ```powershell
  $env:NEXUS_OPENAI_BOT_XMPP_PASSWORD = 'winston'
  $env:OPENAI_API_KEY = '<OpenAI API key>'
  ```

- The GUI remains the distinguished Codex host UI; do not add provider
  switching or OpenAI request controls. The second binding is controller-owned
  deployment configuration and the existing controller command
  `invite OpenAIBot` launches it into the requested room.
- Change `BotsUnsupportedProvider.Bot.nxscript` to a name still excluded by
  the production dialect and update its diagnostic assertion. Preserve the
  separate dialect-valid-but-unregistered `Unregistered` fixture and test.

### Concrete abstraction pressure

- The second provider proves that one additional persisted deployment value is
  necessary, but does not justify a provider configuration hierarchy or bag.
  Add the one explicit published property to the existing binding/config.
- No `TNXBotProvider` public operation needs to change.
- Both providers enforce the same configured answer byte limit. During
  implementation, prefer moving the existing UTF-8-safe answer-bound operation
  to one provider-neutral owner only if doing so removes the Codex-local copy
  and produces a smaller final implementation. Do not add a utility/forwarding
  unit merely for that helper.
- Direct OpenAI HTTPS reveals a platform trust distinction, not a generic HTTP
  abstraction requirement. Keep WinHTTP inside the OpenAI implementation and
  leave NexusXMPP/Synapse unchanged.

## Scope

- New `NexusTools/BotHost/src/protocol/obNXOpenAIResponses.pas`
  - minimal typed request, response, error, incomplete-detail, heterogeneous
    output-message, and output-content RTTI objects.
- New `NexusTools/BotHost/src/obNXOpenAIProvider.pas`
  - concrete provider, registration, WinHTTP executor/test seam, one blocking
    worker, bounded prompt ownership, continuity, cancellation, and shutdown.
- `NexusTools/BotHost/src/obNXBotHostConfig.pas`
  - one persisted OpenAI API-key environment-variable-name property on binding
    and host configuration.
- `NexusTools/BotHost/src/obNXBotController.pas`
  - copy/update that deployment value; no provider branch.
- `NexusTools/BotHost/catalog/Bot.Language.nxscript`
  - allow exact `OpenAI`.
- `NexusTools/BotHost/catalog/Bots.nxscript`
  - add the real `OpenAIBot` definition.
- `NexusTools/BotHost/catalog/BotsUnsupportedProvider.Bot.nxscript`
  - retain an actually illegal provider fixture after `OpenAI` becomes legal.
- `NexusTools/BotHost/NexusBotHost.lpr`
  - explicitly link the OpenAI registration unit.
- `NexusTools/BotHost/uiNXBotHostMain.pas`
  - seed the complete default OpenAIBot deployment binding before fail-fast
    catalog loading; no provider-selection UI.
- New `NexusTools/BotHost/tests/tsNXOpenAIProviderTests.pas`
  - registered deterministic protocol/provider/worker tests using the narrow
    injected executor.
- `NexusTools/BotHost/tests/NexusBotHostTestModule.lpr` and
  `NexusBotHostTestModule.lpi`
  - register/include the OpenAI test unit.
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`
  - update provider-registry and combined default-catalog expectations and
    shared complete-binding setup.
- `NexusTools/BotHost/tests/tsNXBotHostLiveTests.pas`
  - retain the Codex test and add an explicitly enabled Openfire/OpenAI live
    test using environment-provided API/XMPP credentials.
- `NexusTools/BotHost/NexusBotHost.lpi` only if Lazarus requires the new units
  listed for project navigation; unit linkage remains source-driven.
- `NexusTools/BotHost/README.md`
  - document provider setup, OpenAI-side retained-response continuity, secret
    variables, controller invite flow, current Win64 transport scope, and live
    verification.

## Out Of Scope

- Streaming Responses output or SSE parsing.
- OpenAI function calling, `bot_control` tool parity, built-in tools, structured
  output, images/audio/files, or reasoning configuration.
- A generic OpenAI SDK, shared HTTP client, transport registry, provider
  capabilities, configuration hierarchy/bag, worker pool, scheduler, task
  framework, deadline service, retry/backoff system, or cross-provider queue.
- Persistent local conversation state, conversation recovery, multi-room
  context separation, or redesign of Codex thread ownership.
- Non-Windows OpenAI HTTP implementation in this milestone.
- XMPP architecture, control-plane semantics, live provider switching, or
  unrelated cleanup.
- Standalone test applications, HTTP test servers, or external test harnesses.

## Staged Implementation Plan

### Stage 1: Typed protocol model

1. Add the minimal RTTI request/result graph in
   `obNXOpenAIResponses.pas` with constructors only where nested JSON values
   require deliberate creation beyond `TNXJSONObject` auto-creation.
2. Implement typed discriminator selection for output messages and content
   parts. Unknown types become typed base values and remain ignored.
3. Add small response methods only if they directly centralize completed-state,
   ordered text extraction, refusal, or diagnostic behavior. Do not add an SDK
   facade.
4. Register deterministic protocol tests for initial/chained serialization,
   instructions on both, explicit `store`/non-streaming values, multi-fragment
   extraction, ignored unknown output items, refusal, incomplete results,
   missing text, null error fields, and malformed shapes.

### Stage 2: Configuration and registration prerequisites

1. Add `OpenAIAPIKeyEnvironmentVariable` as a real published RTTI property on
   deployment and host configuration.
2. Copy it in controller host construction and deployment updates without
   adding provider-name dispatch.
3. Implement OpenAI class validation for the nonblank/legal variable name only.
4. Add the OpenAI provider unit with exact registration and link it explicitly
   from the application/test composition roots.
5. Extend provider registry tests for exact `OpenAI`, case sensitivity, and
   creation of `TNXOpenAIProvider`.

### Stage 3: Narrow WinHTTP execution

1. Implement the OpenAI-specific synchronous executor and its test injection
   seam inside the provider unit.
2. Construct the fixed HTTPS request, UTF-8 JSON body, content type, user agent,
   and bearer header; set phase timeouts and a response-size bound.
3. Leave all WinHTTP certificate/hostname checks enabled and return distinct
   information for HTTP status, certificate failure, timeout/transport failure,
   and response bytes without exposing the key.
4. Add deterministic executor-boundary tests with a dummy key proving the key
   reaches only the execution boundary, is absent from JSON/diagnostics, and
   that status/body/error classifications reach the provider correctly. Do not
   make deterministic tests contact OpenAI.

### Stage 4: Provider worker and conversation flow

1. Add the single provider-owned thread, prompt list, wake event, active prompt,
   and minimal guarded state described by the target contract.
2. Implement Start/Stop/Submit/cancel/Shutdown while preserving transferred
   prompt ownership and keeping every blocking wait outside the guard.
3. Execute requests serially, send instructions every time, include the prior
   response ID only when owned, and update it only after accepted success.
4. Invoke direct provider events outside the guard. Apply the answer byte limit
   once and remove any duplicate bounding helper if a smaller common location
   is proven.
5. Implement the exact fatal versus prompt-local classifications and ensure a
   failed provider drains/fails queued prompts rather than leaving work pending.

### Stage 5: Cancellation and synchronous ownership tests

1. Test queue capacity and prompt transfer on accepted and rejected submission.
2. Test cancel-all and cancel-by-room for queued prompts, exact-once failure,
   and preservation of unrelated room work.
3. Use the injected executor to hold one request in flight, cancel it, release
   it, and prove the late result is discarded and the previous response ID is
   unchanged.
4. Test Stop while idle and active, restart with cleared continuity, Shutdown
   with queued/active work, joining of the one owned worker, and absence of
   callbacks after Shutdown returns.
5. Prove the worker blocks on its wake event rather than polling and that no
   lock is held across executor calls or callbacks by making the test callback
   re-enter safe provider observations/cancellation.

### Stage 6: Default catalog and deployment

1. Add `OpenAI` to the Bot language and `OpenAIBot` to the default catalog.
2. Seed the complete separate OpenAIBot binding before GUI catalog loading,
   using the settled JID/nick/resource and environment-variable names.
3. Update all deterministic and live-test setup that loads `Bots.nxscript` so
   both required bindings exist. Centralize repeated test binding construction
   locally rather than copying long property lists.
4. Change the former OpenAI-as-unsupported fixture to a genuinely illegal
   provider, while retaining the dialect-valid/unregistered registry test.
5. Verify catalog failure remains atomic when the OpenAI binding or its API-key
   variable name is missing and that successful publication exposes both bots.

### Stage 7: Registered live and GUI verification

1. Add `NexusBotHostLive.OpenfireOpenAI`, disabled unless its explicit live-test
   switch and all named environment inputs are present. It remains inside
   `NexusBotHostTestModule` and uses ordinary provider/XMPP APIs.
2. Start the OpenAI provider, connect its separate XMPP identity, join the
   permanent room, send an addressed prompt from an observer, confirm a bounded
   answer, then leave and synchronously shut down.
3. Preserve the existing Openfire/Codex test. Do not require the OpenAI key for
   ordinary deterministic or Codex-only tests.
4. Launch the GUI manually with both XMPP password variables and
   `OPENAI_API_KEY`, start/join NexusBot, issue `invite OpenAIBot`, observe both
   independent occupants, address each bot, then dismiss OpenAIBot and close
   the application.

### Stage 8: Subtraction and documentation pass

1. Remove superseded OpenAI-as-illegal fixture wording and duplicate test
   binding setup.
2. Inspect the provider for forwarding methods, duplicated state, duplicate
   serialization, speculative HTTP options, and copied Codex mechanics that the
   simpler request/response provider does not need.
3. Record production and test LOC added/removed. The expected production
   increase is roughly 400–600 lines: typed wire objects, one secure native
   request executor, and one blocking worker are irreducible capabilities. If
   it materially exceeds that range, simplify before accepting the result.
4. Update README setup and limitations without presenting deferred tools,
   streaming, cross-platform transport, or conversation routing as implemented.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan does not authorize
spawning, resuming, messaging, or delegating to sub-agents. Plan approval and
implementation approval do not grant sub-agent permission; the human owner
must explicitly request sub-agent use in the current conversation.

## Verification Plan

- Build the GUI and registered BotHost test module:

  ```powershell
  lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
  lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
  ```

- Preserve/build the existing fake Codex App Server fixture, then run every
  deterministic BotHost and OpenAI suite through `NexusTestHost`:

  ```powershell
  fpc -B -MObjFPC -Sh `
    -FUoutput\NexusBotHostTests\fake-units `
    -FEoutput\NexusBotHostTests\bin `
    NexusTools\BotHost\tests\FakeCodexAppServer.lpr
  $env:NEXUS_BOTHOST_FAKE_APP_SERVER = `
    (Resolve-Path output\NexusBotHostTests\bin\FakeCodexAppServer.exe)
  output\NexusTestHost\nxtest_host.exe `
    output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
    run-suite NexusBotHost
  output\NexusTestHost\nxtest_host.exe `
    output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
    run-suite NexusBotHost.OpenAI
  ```

- Run the existing registered Openfire/Codex test when configured, then the new
  registered Openfire/OpenAI test with explicit live credentials. Record the
  exact OpenAI model used and do not print the API key.
- Perform the GUI/two-occupant room flow from Stage 7 and confirm provider state,
  XMPP presence, ordinary addressed conversation, dismissal, and clean close.
- Focused structural inspection must show:
  - no `OpenAI` provider-name branch in host, controller, catalog, XMPP control,
    or GUI lifecycle code;
  - no API key value in catalog, persisted JSON, diagnostics, test output, or
    source;
  - no raw/manual JSON request construction outside typed RTTI serialization;
  - no SDK-only top-level `output_text` assumption;
  - one OpenAI worker only, with no polling `Sleep`, worker pool, controller
    thread, scheduler, timer/deadline service, or result queue;
  - WinHTTP certificate-ignore flags are absent;
  - the provider guard is not held across HTTP, callbacks, waits, or join;
  - `TNXBotProvider` has no OpenAI-specific public operation;
  - the global `TNXClassFactory` remains uninvolved in provider registration;
  - OpenAI registration is explicitly linked in application and tests;
  - the illegal-provider and legal-but-unregistered tests remain distinct.
- Run `git diff --check`, inspect the full diff and LOC balance, and create the
  required fresh source archive after approved implementation.

## Risks And Questions

- `store: true` and `previous_response_id` intentionally use OpenAI-retained
  response state. The current official documentation says response objects are
  saved for 30 days by default. Approval of this plan accepts that service-side
  behavior for the initial bot; there will still be no local persisted history.
- `gpt-5.6-luna` matches the current NexusBot catalog choice, but direct OpenAI
  API availability depends on the owner’s account/project. Before the live
  test, replace the OpenAIBot catalog model if that exact name is unavailable;
  no code may silently substitute another model.
- The secure HTTP implementation in this plan is WinHTTP-specific because the
  immediate deployed target is Win64 and the existing Synapse OpenSSL path has
  no configured public trust bundle. Supporting Linux/macOS requires a later
  explicit transport/trust decision, not an abstraction added preemptively.
- Stop is intentionally nonblocking, while final Shutdown is synchronous. When
  an active WinHTTP call cannot be safely interrupted, Shutdown latency is
  bounded by the configured WinHTTP phase timeouts rather than by an invented
  cancellation subsystem.
- The default `test2@nexus.local` identity is also useful as an observer in
  existing local live testing. Simultaneous manual two-bot testing therefore
  needs another observer identity or the normal Gajim `kcollins@nexus.local`
  occupant; credentials are never committed.

## Approval Gate

This plan creates no implementation authorization. No code edit, build, test,
live API/XMPP request, GUI launch, archive, or implementation commit begins
until the human owner explicitly authorizes implementation. Implementation
remains local and uses no sub-agents unless the human owner separately and
explicitly requests them.
