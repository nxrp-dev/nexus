# Work Plan: Codex/Luna XMPP GUI Bot Host

## Inputs

- Source request: `C:\Users\kcollins\Downloads\codex-luna-xmpp-gui-bot-host-workplan-request (1).md`.
- Related discussion/review notes:
  - The first host is a visible Windows NexusUI application, not a service or daemon.
  - The host launches and owns `codex app-server` over its default stdio JSONL transport; attaching and WebSocket transport are excluded.
  - Every supported App Server request, response, notification, parameter, result, event, and tagged union is modeled by Pascal RTTI/Props classes. Published properties are the wire contract. Production code does not construct or interpret App Server messages through free-form JSON.
  - The existing Nexus JSON-RPC implementation must gain an explicit headerless-envelope policy because App Server omits the `jsonrpc` member. Existing standards-compliant consumers must retain their current behavior.
  - The initial bot is non-writing, cannot accept authority from XMPP text, and does not autonomously approve commands, changes, network access, permissions, or user-input requests.
  - The initial routing rule is an exact, case-sensitive leading `@BotNick` followed by whitespace or end-of-message. The prefix and separating whitespace are removed, and empty remaining input is rejected.
  - A successful turn prefers the last completed `agentMessage` marked `final_answer`. If the installed schema permits an absent phase and no agent message in the turn supplies a phase, the last completed agent message is used. Messages explicitly marked `commentary` are never sent to XMPP.
  - Unknown App Server notifications are logged and ignored. Unknown server-initiated requests receive a typed error response. Known methods with invalid typed payloads are protocol failures.
- Existing constraints:
  - Follow repository `AGENTS.md`, `NexusTools/AGENTS.md`, `NexusLib/net/AGENTS.md`, `NexusLib/net/src/xmpp/AGENTS.md`, `NexusLib/ui/AGENTS.md`, `.ai/standards/pascal.md`, `.ai/protocols/architecture-change.md`, and `.ai/protocols/subagents.md`.
  - Preserve NexusXMPP connection-thread ownership, bounded queues, retained event ownership, and caller-thread callbacks through `TNXXMPPClient.PumpEvents`.
  - Preserve RTTI/Props as the protocol data-contract mechanism.
  - Keep the implementation narrow and local to one Codex/Luna-backed bot. No sub-agent use has been authorized.

## Summary

Create `NexusTools/BotHost` as a focused NexusUI application that owns one NexusXMPP client, one MUC participation session, and one local Codex App Server child process. The application accepts only explicitly addressed live room messages, serializes them through one bounded FIFO into one Codex thread, and posts only an eligible completed final answer back to the room. Its GUI presents connection, room, process, thread, turn, queue, routing, approval, and failure state without becoming a human chat client.

The implementation reuses NexusLib's RTTI/Props JSON and JSON-RPC message model but does not reuse the LSP transport or server machinery. App Server uses JSONL rather than LSP `Content-Length` framing, acts as the server while the host is the bidirectional client, and omits the JSON-RPC version member. A small explicit JSON-RPC envelope policy will address the one shared incompatibility. The Codex-specific request correlation, process ownership, schema-derived RTTI types, and JSONL framing remain owned by the BotHost tool.

The implementation also adds one narrow NexusUI application-cycle callback. `TNXApplication.Run` currently provides no place for an application to pump NexusXMPP or drain background process events on the GUI thread. The callback will expose that lifecycle point without putting protocol work in rendering or adding a timer framework.

## Verified Findings

### Nexus JSON-RPC and RTTI/Props

- `TNXJSONRPCMessage` is a `TNXJSONObject` with RTTI-published `jsonrpc` and `id` properties. Commands add published `method` and `params`; responses add published `result` and `error`.
- `TNXJSONObject.ToJSONData` enumerates RTTI-published JSON-value properties and omits unassigned properties. Headerless serialization is therefore already mechanically possible when `jsonrpc` remains unassigned.
- `TNXJSONObject.FromJSONData` populates known RTTI properties and ignores fields that have no modeled property. Host behavior must never retrieve those ignored fields through a dynamic side channel.
- `TNXJSONRPCVariant` and typed array classes provide the existing mechanism for schema unions and collections. App Server tagged unions can select a concrete RTTI class by their schema discriminator while all modeled data remains published properties.
- `TNXJSONRPC.ValidateMessage` currently rejects a missing `jsonrpc = "2.0"` member. `CreateSuccessResponse` and `CreateErrorResponse` always add that member.
- `TNXLSOutboundDispatcher` also assigns `jsonrpc = "2.0"` before every request and notification. It is LSP-specific and must remain unchanged for standard JSON-RPC.
- NexusLib's LSP transports implement `Content-Length` framing and server hosting. They are not App Server JSONL child-process transports and should not be imported into BotHost merely to reuse their names or lifecycle.
- The current JSON-RPC class factory already maps registered method names to concrete RTTI message classes. This is the appropriate dispatch basis for modeled App Server methods.

### NexusXMPP

- `TNXXMPPClient` owns configuration, the connection thread, modules, and bounded command/event queues. Modules are fixed while connected.
- `TNXXMPPClient.PumpEvents` drains retained events and invokes application/module callbacks on the caller thread.
- `TNXXMPPClientConfig` already carries JID, password, endpoint override, CA file, reconnect limits, and bounded XMPP capacities. The bot host should populate this object rather than duplicate XMPP transport settings.
- `TNXXMPPMUCModule` exposes typed `Join`, `Leave`, `SendGroupMessage`, `SendGroupReply`, room-state, occupant, and room-message APIs. It owns current room nickname/state and classifies delayed messages as `xmdcMUCHistory`.
- `TNXXMPPMessage` exposes the typed body, sender JID, message type, delivery context, identifiers, reply metadata, and validation result needed by the initial router.
- The current MUC API is sufficient for the first host loop. No raw XMPP stanza construction or NexusXMPP extension is planned.
- Current live-test conventions use environment variables for credentials and an explicit CA file. Secrets are not embedded in source.

### NexusUI

- `TNXApplication` owns the SDL-backed platform, canvas, root window, windows, popups, fonts, event handling, rendering, and main run loop.
- `TNXApplication.Run` currently performs `ProcessMessages` followed immediately by `Render` in a tight loop. It has no application-owned cycle/idle callback.
- Protocol pumping from control rendering would violate the GUI/state boundary. A small application-cycle event invoked by `Run` is the required NexusUI seam.
- NexusUI already provides buttons, labels, edit boxes with password masking, panels, split panels, memos, lists/grids, status bars, windows, and retained layout behavior sufficient for the proposed control and observability surface.

### Process hosting and installed App Server

- The installed `codex` command resolves through `C:\Users\kcollins\AppData\Roaming\npm\codex.ps1` in the current environment.
- No generated Codex App Server schema snapshot or typed App Server protocol units currently exist in the repository.
- Existing `TProcess` uses in NexusTools are synchronous command runners. None provides the owned asynchronous stdin/stdout/stderr lifecycle needed here.
- Repository planning rules prohibit launching programs while preparing this plan. The exact installed Codex version, generated schema, invocation through the resolved PowerShell shim, stable method set, and Windows pipe behavior therefore become the first implementation gate and must be recorded before protocol code is written.

### Working-tree boundary

- The repository currently contains uncommitted NexusXMPP Phase 2 work, including the MUC and typed message units used by this plan. Implementation must preserve that work and must not reset, rewrite, or accidentally omit it from project search paths.

## Architecture Problem

The required components exist independently but there is no owner for the end-to-end state machine. NexusXMPP can join and exchange typed room messages, NexusUI can present a native control surface, and Nexus JSON-RPC can map typed Pascal objects to JSON. None currently owns a child App Server process, headerless JSON-RPC dialect, version-specific App Server contracts, turn correlation, message admission policy, or serialized room-to-model workflow.

Putting those responsibilities directly in a NexusUI window would mix process pipes, protocol correlation, XMPP policy, queueing, and rendering. Running blocking pipe reads on the UI thread would freeze the application. Calling NexusXMPP from a process-reader thread would violate its caller-thread callback contract. Reusing LSP transport code would import the wrong framing and server/client assumptions. Using free-form JSON would discard the project's RTTI contract and make schema drift invisible until runtime.

The correction is one application-level coordinator with focused subordinate owners: a Codex App Server process/session adapter, a room-message router, a bounded pending-message queue, an XMPP-facing session, an application event journal, and a NexusUI view. The coordinator is the only component allowed to move a message from one subsystem to another. Background readers retain and enqueue data; the NexusUI application cycle drains it and performs all coordinator, XMPP-pump, and GUI work on the application thread.

## Target Contract

### Project and unit ownership

- Add `NexusTools/BotHost/NexusBotHost.lpr` and `.lpi` as the Windows NexusUI executable.
- Keep BotHost-specific code below `NexusTools/BotHost/src`:
  - `obNXBotHostConfig.pas`: persisted non-secret configuration, runtime secret acquisition, validation, and defaults.
  - `obNXBotHostRouter.pas`: pure live-message admission and mention removal.
  - `obNXBotHostQueue.pas`: bounded FIFO of owned admitted room requests.
  - `obNXBotHostEvent.pas`: immutable sequence/timestamp/category/state event records used by the GUI journal.
  - `obNXCodexAppServerTransport.pas`: child process, stdin writer, stdout JSONL reader, stderr reader, bounded cross-thread event transfer, exit detection, and termination.
  - `obNXCodexAppServer.pas`: initialization, request IDs, pending request ownership, model discovery, thread/turn lifecycle, final-answer selection, cancellation, server-request decisions, and typed protocol dispatch.
  - `protocol/obNXCodexAppServerTypes.pas`, `obNXCodexAppServerRequests.pas`, and `obNXCodexAppServerEvents.pas`: schema-derived RTTI/Props contracts and method registration. Split further only if the installed schema makes one of these units unreasonably large.
  - `obNXBotHost.pas`: the single coordinator joining XMPP, routing, queue, App Server, and application events.
  - `uiNXBotHostMain.pas`: NexusUI construction, layout, control handlers, and projection of coordinator state.
- Add `NexusTools/BotHost/tests` with its own Nexus test module and a small fake App Server child executable for deterministic pipe/lifecycle tests.
- Modify NexusLib only for the explicit JSON-RPC envelope policy and the narrow NexusUI application-cycle hook.

### JSON-RPC envelope policy

- Introduce an explicit enum or equivalent typed value with two modes: standard JSON-RPC and App Server headerless JSON-RPC.
- Existing methods and consumers default to standard behavior with no source changes required at their call sites.
- Standard parsing continues to require exactly `jsonrpc = "2.0"`; standard response creation continues to emit it.
- Headerless parsing accepts an omitted member, rejects any present value other than `"2.0"`, and otherwise applies the same request/notification/response shape validation.
- Headerless serialization leaves the RTTI `jsonrpc` property unassigned and omits it. Headerless success/error response helpers likewise omit it.
- The policy is supplied explicitly by the App Server adapter. It is never inferred from method spelling or message contents.
- Focused tests prove both policies, including that existing LSP behavior remains standard.

### Typed App Server protocol

- At implementation start, generate the JSON Schema from the installed `codex app-server`, record the Codex version and schema fingerprint, and retain a reviewable schema snapshot or reproducible schema-baseline artifact under BotHost. This artifact documents the external version; the Pascal RTTI classes remain the runtime data contract.
- Model only the stable App Server surface the first host sends, consumes, or must answer, plus the complete nested types reachable from those messages. Do not opt into experimental APIs.
- The minimum outbound method set includes `initialize`, `initialized`, `model/list`, `thread/start`, `turn/start`, `turn/interrupt`, and the installed stable thread-release operation such as `thread/unsubscribe` when present.
- The minimum inbound set includes the corresponding typed responses; thread, turn, item, error, and server-request lifecycle notifications; completed `agentMessage` items and their phase; and command, file-change, permission/network, and user-input requests that must be declined or cancelled.
- Schema unions use typed `TNXJSONRPCVariant` descendants and concrete RTTI classes selected by the schema discriminator. Discriminator selection is protocol binding, not a free-form data channel; host logic receives only the selected typed class.
- Known methods with invalid required fields, unsupported union tags within a supported method, or mismatched result shapes fail the session visibly.
- Unknown notifications retain only the typed base envelope information needed to log the unsupported method and are ignored. Unknown server requests receive a headerless typed `MethodNotFound` error immediately. They never remain pending.
- Request IDs are monotonically allocated with wrap protection. Pending requests own their typed outbound command/result expectation and are completed exactly once by response, timeout, process failure, or shutdown.
- A schema-verification command regenerates the installed schema to a temporary directory and compares its version/fingerprint with the recorded baseline. Drift fails visibly and requires the RTTI contract to be reviewed; it never falls back to dynamic parsing.

### App Server process and session

- `TNXCodexAppServerTransport` exclusively owns `TProcess`, its three pipes, reader threads, and transport-event queue.
- Launch the resolved Codex command in App Server stdio mode without shell text composition. Resolve the Windows shim/executable explicitly and supply arguments as an argument list.
- Keep stdout and stderr separate. Stdout accepts UTF-8 JSONL protocol frames only; stderr produces diagnostic events only.
- Apply an explicit maximum stdout frame size. An overlong, malformed, or invalid UTF-8 frame fails the App Server session; protocol frames are never truncated or skipped.
- Because Windows pipe reads can block independently, stdout protocol reading and stderr draining have separate owned readers. Neither mutates GUI, coordinator, XMPP, or session state directly.
- Cross-thread events own their payloads and enter a bounded queue. Protocol-event overflow is fatal and visible because dropping a response or lifecycle event would corrupt correlation. Stderr overflow may coalesce dropped-line counts but may not block protocol progress indefinitely.
- The application thread is the sole consumer of transport events and the sole caller of `TNXCodexAppServer` state transitions.
- Startup proceeds through process launch, `initialize`, `initialized`, typed `model/list`, exact configured-model resolution, and `thread/start`. Failure at any step stops progression and remains visible.
- Reuse installed Codex authentication. Inspect typed account state if required by the generated stable schema; an unauthenticated state is a visible startup failure rather than a request to store a new API key.
- One newly created Codex thread belongs to one active configured room session for the lifetime of the child process. Changing rooms or restarting App Server creates a new thread. Persistent thread resume is out of scope.
- Shutdown stops admission, cancels the active turn with the supported typed method, fails queued room work, releases/unsubscribes the thread when supported, closes stdin or otherwise requests orderly process exit, waits for the configured bound, and only then force-terminates. Every pending request completes with an explicit shutdown/process-loss result.

### Authority contract

- Use a dedicated configured runtime working directory rather than the repository root or user home.
- Start the thread/turn with the installed stable equivalent of a restricted read-only sandbox, restricted readable roots, no tool network access, and `approvalPolicy = never`.
- Where the stable installed schema supports disabling tools, disable command, file-change, external network, dynamic-tool, and connector capability for this first bot. Otherwise combine the isolated working directory, restrictive sandbox, no tool network, explicit developer instruction, and approval policy; record the residual behavior visibly.
- Version 1 has no operator approval button. Command-execution, file-change, permission, network-escalation, MCP elicitation, and user-input requests are answered with the appropriate typed decline/cancel result and logged.
- XMPP content is always untrusted conversational input and is never interpreted as authorization, configuration, a local path, a command, or an approval decision.

### Room routing and bounded turn flow

- Route only valid `xmdcLive` room messages with a nonempty body.
- Suppress self messages by exact comparison with the current room occupant JID derived from the room JID and current `TNXXMPPRoom.Nick`; nickname changes update the comparison source automatically.
- Match an exact, case-sensitive leading `@` plus the current nickname, followed by whitespace or end-of-message.
- Remove the mention and all immediately separating whitespace. Reject and log an empty remainder without queueing a turn.
- Enforce the configured maximum admitted UTF-8 byte length before allocating queue work. Oversized input is rejected visibly and never partially submitted.
- Maintain one active turn and a bounded owned FIFO, default capacity 16. When idle, the oldest request starts immediately. When full, reject the new request and add a visible overflow event; do not displace older work.
- Do not use `turn/steer`. Each admitted room message becomes one `turn/start` on the same thread.
- Retain source room, sender occupant JID, message ID metadata, admitted text, and local sequence number until the turn completes or fails. Do not retain the callback-owned `TNXXMPPMessage` object.
- A deliberate stop, room leave, XMPP terminal failure, App Server death, or host shutdown interrupts the active turn and explicitly fails all queued items. Temporary XMPP recovery state is shown accurately; the plan implementation must use the actual NexusXMPP state/lifecycle distinction rather than treating every intermediate reconnect state as a terminal stop.

### Final-answer selection and XMPP output

- Collect authoritative completed `agentMessage` items for the active turn; streamed deltas may update GUI diagnostics but are not the source of the room response.
- After successful `turn/completed`, select the last completed agent message with `phase = final_answer`.
- If the installed schema permits absent phase and no agent message in that turn supplies any phase, select the last completed agent message.
- Never select a message explicitly marked `commentary`. A mixture containing phased commentary and only unphased messages is treated as ambiguous and fails visibly rather than guessing.
- A failed/interrupted turn, missing final answer, empty final text, invalid typed item, or ambiguous phase produces no fabricated room response.
- Enforce the configured maximum outbound UTF-8 size, default 16 KiB. Truncate only at a valid UTF-8 boundary, reserve space for an explicit `\n[response truncated by NexusBotHost]` marker, and emit one groupchat message. Do not split one answer into an unbounded message burst.
- Send through `TNXXMPPMUCModule.SendGroupMessage`. A failed enqueue/transmission request is visible and does not cause automatic model retry.

### GUI and application-thread state flow

- Add one NexusUI application-cycle/idle callback invoked by `TNXApplication.Run` after platform event processing and before rendering. It runs on the application thread and contains no protocol-specific behavior.
- The BotHost cycle handler drains a bounded number of App Server transport events, calls `TNXXMPPClient.PumpEvents` with a bound, advances coordinator state, updates dirty GUI projections, and returns promptly.
- All GUI controls read coordinator/application-event state. Controls do not parse JSON, own XMPP modules, read process pipes, or decide routing/approval policy.
- Use a compact top status/control area for App Server, model/thread/turn, XMPP, room/nickname, and queue state.
- Use a structured event grid/list for timestamp, sequence, subsystem, direction/category, and summary. Use a separate read-only memo/detail pane for the selected event, final response, stderr, or error detail.
- Provide Start/Stop App Server, Connect/Disconnect XMPP, Join/Leave room, and Clear View controls with enablement derived from state. Do not expose approval controls in version 1.
- Bound the retained GUI journal independently from the transport queues. Clearing the view affects presentation history only, not protocol state or pending work.

### Configuration and secrets

- Model non-secret settings as a `TNXPersistObject` with published properties and store them in a user-local BotHost JSON file, not beside the executable or in the repository.
- Persist XMPP JID, endpoint override, CA file, resource, room JID, nickname, Codex command path, desired model identity/display selector, runtime working directory, queue capacity, frame/input/output limits, timeouts, and GUI journal capacity.
- Never persist the XMPP password in the configuration object. Acquire it from a named environment variable or a masked runtime NexusUI edit control and keep it only in memory for the connection lifetime.
- Never store an OpenAI API key. App Server uses the installed Codex authentication state.
- Validate all capacities, timeouts, paths, JIDs, room/nickname values, and required CA material before starting their respective subsystem. Invalid configuration produces a specific GUI event and no partial transition.

## Scope

- `NexusLib/core/src/obNXJSONRPCMessages.pas` and focused JSON-RPC tests for the explicit headerless envelope policy.
- `NexusLib/ui/src/obNXApplication.pas` and focused NexusUI lifecycle verification for the application-cycle callback.
- New `NexusTools/BotHost/` project, protocol contracts, process/session adapter, router, queue, coordinator, UI, configuration, tests, fake App Server, fixtures, and schema-baseline metadata.
- Documentation describing configuration, authority limits, build/test commands, schema-drift verification, and the live Openfire/Gajim acceptance procedure.
- Existing NexusXMPP public APIs and current Phase 2 units as consumers only, unless implementation inspection proves a concrete defect in the required existing behavior.

## Out Of Scope

- Coordinator bots, catalogs, registries, invitations, slash commands, multi-bot orchestration, delegation, or autonomous bot-to-bot coordination.
- Multiple rooms, multiple simultaneous Codex threads, persistent session resume, durable queueing, long-term memory, artifact databases, or NexusScript bot definitions.
- Provider abstraction or support for a provider/process other than Codex App Server with the configured Luna model.
- App Server WebSocket, remote App Server, process attach, terminal scraping, or pseudo-console automation.
- Enabling command, file-write, git, build, external network, MCP/app, or other utility authority for the room bot.
- A human-facing chat client, roster UI, room administration, voice, mobile, daemon, or Windows service mode.
- Broad NexusXMPP, JSON-RPC, NexusUI, process, queue, logging, or configuration frameworks.
- Automatic generation of arbitrary Pascal contracts from arbitrary JSON Schema unless inspection proves a small existing generator can be reused. The first binding may be authored from the generated schema and verified by fixtures.

## Staged Implementation Plan

### Stage 0: Capture the installed App Server contract

1. Resolve the actual executable behind the installed `codex` shim and record `codex --version`.
2. Generate the stable App Server JSON Schema to a temporary directory using the installed executable. Do not enable experimental API fields.
3. Record the exact invocation, schema file set, schema fingerprint, method names, required initialization order, shutdown/release behavior, model-list shape, thread/turn/item types, phase optionality, sandbox fields, approval request/response shapes, and Windows stdio behavior.
4. Add a reviewable schema baseline/fingerprint and protocol-version note under BotHost, clearly identifying it as the external reference rather than the runtime data model.
5. If the installed contract materially contradicts the approved target—for example, it cannot select Luna, cannot enforce the authority boundary, or lacks a supported cancellation path—stop and report the blocker before implementing an invented substitute.

Completion: the installed external contract and any version-sensitive assumptions used by later stages are explicit and reproducible.

### Stage 1: Add the explicit JSON-RPC envelope policy

1. Add the typed standard/headerless policy to the existing JSON-RPC owner.
2. Add policy-aware parsing/validation and success/error response creation while keeping existing overloads standard by default.
3. Verify headerless request, notification, success, error, invalid-version, invalid-shape, and batch rejection/handling according to the installed App Server contract.
4. Run existing JSON-RPC/LSP hardening tests to prove unchanged standard behavior.

Completion: App Server envelopes can be parsed and emitted without `jsonrpc`, and every pre-existing consumer still uses strict standard JSON-RPC.

### Stage 2: Define and verify the RTTI App Server binding

1. Implement the schema-derived typed objects, arrays, nullable values, discriminated unions, requests, responses, notifications, and server-request decision results needed by the target contract.
2. Register method classes through the existing class factory and keep all external names exactly equal to the installed schema.
3. Implement typed serialization/deserialization round-trip fixtures for initialization, models, thread start, turn start/completion, phased and unphased agent messages, failures, approvals, user input, and unknown methods.
4. Implement the schema drift verification command and document how a Codex upgrade is reviewed.

Completion: every supported wire message round-trips through RTTI/Props, unknown-method behavior is deterministic, and production BotHost code contains no free-form App Server JSON construction or payload lookup.

### Stage 3: Implement the child-process JSONL transport and session

1. Implement owned `TProcess` launch with separate stdin, stdout, and stderr handling; never use `poStderrToOutput`.
2. Add bounded stdout/stderr readers, UTF-8 JSONL framing, frame limits, transport-event ownership, process-exit detection, and deterministic shutdown.
3. Add typed request correlation, response completion, notification dispatch, unknown server-request errors, timeouts, and failure of pending work.
4. Implement initialization, installed authentication reuse, model discovery, exact Luna resolution, thread creation/release, turn start/interrupt, and typed approval declines.
5. Drive this stage against a deterministic fake child process covering partial reads, multiple frames, malformed frames, stderr traffic, delayed responses, unexpected exit, timeout, queue overflow, and shutdown escalation.

Completion: a non-GUI test can start the fake App Server, complete a typed conversation lifecycle, observe stderr independently, and shut it down without leaked readers or pending requests.

### Stage 4: Implement configuration, routing, queueing, and coordinator state

1. Add persisted non-secret configuration, runtime password acquisition, validation, safe defaults, and documented limits.
2. Implement the pure mention router with live/history, self, exact nickname, delimiter, empty-remainder, and UTF-8-size rules.
3. Implement the bounded owned FIFO and explicit overflow/failure results.
4. Implement the coordinator state machine for App Server, XMPP, room, thread, turn, queue, and shutdown ownership.
5. Implement authoritative completed-item collection, phase-aware final-answer selection, output bounding, and groupchat transmission through `TNXXMPPMUCModule`.

Completion: deterministic tests can drive typed synthetic room inputs and App Server events through the coordinator and prove exactly which single XMPP send request, rejection, or failure results.

### Stage 5: Add the NexusUI application-cycle seam and GUI

1. Add the narrow application-cycle/idle callback to `TNXApplication.Run` and verify that it runs on the application thread between input processing and rendering.
2. Build the BotHost NexusUI application with status/control, structured event list, and detail/transcript views.
3. Bind controls to coordinator commands and derive control enablement/status solely from current coordinator state.
4. Pump NexusXMPP and drain App Server events with per-cycle bounds; ensure large diagnostic bursts cannot monopolize the GUI.
5. Implement orderly window-close shutdown and retain visible terminal failure state long enough for diagnosis.

Completion: the GUI remains responsive while the fake App Server streams events, XMPP callbacks occur only through application-thread pumping, and rendering contains no protocol work.

### Stage 6: Integrate and verify the real local App Server

1. Launch the installed App Server from BotHost using the verified Stage 0 invocation.
2. Confirm typed initialization, authentication-state reuse, model discovery, Luna selection, thread creation, a simple turn, final-answer selection, interruption, and orderly process shutdown.
3. Confirm the restricted authority policy and automatic typed decline behavior using a controlled request that attempts an unavailable operation.
4. Confirm malformed protocol/process failure remains attributable in the GUI and does not leave the host in a false ready state.

Completion: the GUI can conduct a genuine restricted Luna turn locally without XMPP and exposes all required process/session state.

### Stage 7: Complete the Openfire room loop

1. Configure a dedicated bot JID, CA file, endpoint, room JID, nickname, and runtime password without committing credentials.
2. Connect through `TNXXMPPClient`, join through `TNXXMPPMUCModule`, and display current room/occupant state.
3. Exercise rejected ordinary messages, delayed history, self reflections, exact mentions, empty mentions, queueing, and one accepted message.
4. Confirm only the selected completed final answer is sent with `SendGroupMessage` and all intermediate App Server activity remains GUI-only.
5. Exercise invalid credentials, unavailable room/server, missing Luna, process death, queue overflow, approval decline, and shutdown during an active turn.

Completion: the principal live acceptance test passes from Gajim through Openfire, NexusXMPP, the typed App Server boundary, Luna, and back to Gajim.

### Stage 8: Documentation and integration review

1. Document build/run prerequisites, non-secret configuration, secret entry, CA trust, authority restrictions, controls, event categories, schema verification, and live acceptance.
2. Review ownership, reader termination, queue bounds, request completion, callback thread, GUI responsiveness, and shutdown order against the approved contract.
3. Remove temporary schema output, process logs, credentials, and test artifacts from the repository; keep only approved fixtures/baseline metadata.
4. Run the complete verification plan and create the required fresh Nexus source archive after implementation completes.

Completion: the result is reproducible, reviewable, credential-free, bounded, and ready for human behavioral experimentation in the permanent room.

## Sub-Agent Delegation

Implementation remains local to Main Codex. The human owner has not authorized sub-agent use. This plan, its approval, and any later implementation approval do not authorize spawning, resuming, messaging, or delegating work to sub-agents.

## Verification Plan

### Deterministic builds and tests

- Build the shared JSON-RPC regression target:
  - `lazbuild -B NexusTools\LS\NexusLSTestModule\NexusLSTestModule.lpi`
- Build the NexusUI regression target:
  - `lazbuild -B NexusLib\ui\tests\NexusUITestModule.lpi`
- Build the existing XMPP deterministic suite using its established FPC command/output isolation documented in `NexusLib/net/tests/NexusNetXMPPTests.md`.
- Build the new fake child, BotHost test module, and GUI:
  - `lazbuild -B NexusTools\BotHost\tests\NexusBotHostFakeAppServer.lpi`
  - `lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi`
  - `lazbuild -B NexusTools\BotHost\NexusBotHost.lpi`
- Run the three deterministic test executables and require zero failures.

### Required focused coverage

- Standard versus headerless JSON-RPC parsing and serialization, including typed errors and unchanged LSP envelopes.
- RTTI/Props round-trip of all supported App Server messages and reachable union alternatives.
- Schema fingerprint match and a deliberate drift mismatch.
- JSONL split reads, joined reads, CRLF/LF handling if supported by the installed contract, UTF-8, frame limit, malformed line, EOF, stderr isolation, and process exit.
- Request ID/correlation, timeout, unknown notification, unknown request, invalid known payload, initialization ordering, missing model, and shutdown completion.
- Automatic decline/cancel for every supported server-request category.
- Router acceptance plus history, self, nickname case, missing delimiter, empty remainder, and oversized input rejection.
- FIFO order/capacity/ownership, overflow visibility, active-turn cancellation, and queued-work failure.
- Final-answer selection for final/commentary/unphased/mixed/empty/failed/interrupted cases and UTF-8-safe output truncation.
- NexusUI event-cycle integration, bounded per-cycle draining, control-state projection, and orderly close behavior where deterministic testing is practical.

### Focused greps

- Prove BotHost production units do not use `GetJSON`, `TJSONObject.Find`, `ValueByName`, `TNXJSONRPCUnknown`, hand-written JSON strings, `poStderrToOutput`, raw XMPP XML, `SendRaw`, or LSP transports/dispatchers.
- Prove only the App Server adapter requests the headerless JSON-RPC policy.
- Prove no XMPP password, OpenAI key, test password, room credential, or generated temporary schema directory is tracked.
- Prove no protocol pumping occurs from NexusUI rendering methods or process-reader threads.

### Manual GUI checks

- Start/stop/restart App Server repeatedly and verify process IDs, thread IDs, reader exit, status, and stderr display.
- Connect/disconnect and join/leave repeatedly while verifying button enablement and room/nickname state.
- Generate enough diagnostic activity to test scrolling, event selection, view clearing, and responsiveness.
- Close the window during idle, connection, model startup, active turn, and queued work; confirm bounded shutdown with no orphaned `codex app-server` process.

### Principal live acceptance test

1. Start NexusBotHost.
2. Launch the installed `codex app-server` from the GUI.
3. Confirm typed initialization, installed-auth reuse, model discovery, and configured Luna resolution.
4. Connect the dedicated bot identity to the existing local Openfire server.
5. Join the configured permanent MUC room and confirm the bot's current occupant identity.
6. Join the room from Gajim.
7. Send an unaddressed message and confirm the host logs a routing rejection and emits nothing.
8. Send `@BotNick` alone and confirm empty-input rejection without a turn.
9. Send `@BotNick <question>` using the exact current nickname.
10. Confirm the host logs XMPP receipt, mention removal, admission, and immediate turn start or FIFO placement.
11. Confirm intermediate App Server items appear only in the GUI.
12. Confirm `turn/completed` reports success and the eligible completed final answer is selected.
13. Confirm exactly one bounded groupchat response is submitted through `TNXXMPPMUCModule.SendGroupMessage`.
14. Confirm Gajim displays that response from the bot occupant.
15. Confirm the reflected self message is suppressed and does not start another turn.
16. Stop the host and confirm it leaves/disconnects, interrupts/releases App Server state, exits the child process within the bound, and leaves no pending queue work.

## Risks And Questions

- The installed App Server version and generated schema were not launched during planning because repository policy forbids launching programs before implementation approval. Stage 0 is a mandatory gate; its findings override documentation examples where the installed schema differs.
- The installed `codex` entry point is a PowerShell shim. `TProcess` may need to launch the underlying executable or invoke PowerShell with a fixed argument vector. Stage 0 must verify the safe Windows invocation without command-string composition.
- The current App Server schema is broad. The binding must include the complete type graph reachable from supported methods, but must not turn into an arbitrary JSON-Schema-to-Pascal framework.
- App Server may still produce non-privileged item kinds even under restrictive authority. Supported item unions must be sufficient to maintain event correlation, and unsupported known-method payloads must fail rather than being dynamically interpreted.
- NexusUI currently runs an uncapped render loop. The new application-cycle callback must stay bounded; changing frame pacing is not part of this work.
- The NexusXMPP Phase 2 files are currently uncommitted. Implementation must be based on the owner's retained working tree and must avoid commits that accidentally sweep unrelated Phase 2 changes into a BotHost checkpoint.
- Version 1 automatically declines all App Server approval and user-input requests. Adding local operator approval is intentionally deferred because it would expand the authority and interaction contract.
- Default capacities and limits in this plan are initial operational values and remain configurable: room FIFO 16 and outbound answer 16 KiB UTF-8. The installed schema inspection should establish a reasonable App Server frame limit before that default is fixed.

No human decision is required before implementation other than explicit approval of this work plan. Any material Stage 0 contradiction must be returned to the owner rather than guessed around.

## Approval Gate

This work plan does not authorize implementation. No code edits, builds, tests, App Server launch, GUI launch, archive creation, or implementation repository operations begin until the human owner explicitly authorizes implementation. Work-plan commit and push are planning handoff only and do not authorize implementation or sub-agent use.
