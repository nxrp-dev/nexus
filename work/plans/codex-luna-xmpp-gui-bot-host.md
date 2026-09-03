# Work Plan: Codex/Luna XMPP GUI Bot Host

## Inputs

- Human-owner request: replace the existing BotHost plan with a new plan for creating the Codex bot.
- Original work-plan request: `C:\Users\kcollins\Downloads\codex-luna-xmpp-gui-bot-host-workplan-request (1).md`.
- Superseded plan: this file before the current revision.
- Related discussion and corrections:
  - NexusXMPP raises normal Pascal events directly on its connection thread.
  - `TNXXMPPClient` retains a bounded command queue for work submitted to that thread; it no longer has an application-facing event queue or `PumpEvents` path.
  - A Pascal event is the correct direct notification mechanism. Raising one does not imply dispatch to the GUI thread.
  - BotHost may use shared observable state for GUI display. Register-sized dirty/revision observations may race benignly because the GUI needs a current view, not every intermediate transition.
  - Retained structured state read concurrently by the GUI requires explicit ownership and a consistent snapshot operation.
  - No current requirement justifies changing NexusUI or adding an application-cycle, idle, timer, generalized application-message, or protocol-pump facility.
  - RTTI classes and their published properties are the App Server JSON-RPC data contract. Free-form JSON is not an alternate protocol model.
- External protocol reference: current official Codex App Server documentation describes bidirectional headerless JSON-RPC 2.0 over newline-delimited stdio and provides schema-generation commands.
- Repository constraints:
  - Follow repository and folder `AGENTS.md`, `.ai/standards/pascal.md`, and `.ai/protocols/architecture-change.md`.
  - Preserve the owner's uncommitted NexusXMPP work.
  - Keep the first bot deliberately narrow, local, visible, and non-writing.
  - No sub-agent use is authorized.

## Summary

Create `NexusTools/BotHost` as a visible Windows NexusUI application that owns one NexusXMPP client and one local `codex app-server` child process. It joins one configured MUC room, accepts only exact leading mentions of its current nickname, serializes admitted prompts into one Codex thread with one active turn, and sends only the selected completed final answer back to the room.

The application thread will not mediate XMPP and App Server traffic. NexusXMPP raises events directly on the connection thread. The App Server owner raises Pascal events directly on its worker thread. BotHost event handlers copy borrowed data when retention is required and submit work through the destination subsystem's bounded command API.

NexusUI displays BotHost-owned observable state and accepts operator commands. It does not pump either protocol, parse JSON, route stanzas, or require a new framework callback. This replaces the incorrect application-cycle and cross-thread result-queue architecture in the prior plan.

## Verified Findings

### NexusXMPP

- `TNXXMPPClient` owns one bounded command queue and the connection object. There is no retained application event queue in the current implementation.
- `TNXXMPPClient.DoOnStanza` gives modules the stanza and then calls `OnStanza` directly on the connection thread.
- `TNXXMPPMUCModule` creates a typed `TNXXMPPMessage`, calls `OnRoomMessage` directly, and frees the message after the callback. A consumer must copy fields it retains.
- `TNXXMPPMUCModule.SendGroupMessage` verifies joined-room state and submits owned XML through the module/client command path. It does not itself write the socket.
- Existing MUC APIs cover join, leave, room state, occupant state, received room messages, and group-message transmission. BotHost needs no raw stanza construction.
- History is identified by `TNXXMPPMessage.DeliveryContext`, allowing the router to accept only live messages.

### Nexus JSON-RPC and RTTI/Props

- `TNXJSONRPCMessage` and descendants model envelopes through RTTI-visible properties.
- `TNXJSONObject` serialization omits unassigned properties, so an unassigned `jsonrpc` can produce the App Server envelope without a parallel JSON implementation.
- `TNXJSONRPC.ValidateMessage` currently requires `jsonrpc = "2.0"`, and success/error helpers emit it. A narrow explicit envelope policy is required.
- Existing LSP users must retain current strict behavior by default.
- Existing class registration, typed arrays, nullable values, and typed variants are the intended App Server building blocks.

### NexusUI

- `TNXApplication.Run` owns platform processing and rendering and has no application-cycle callback.
- No such callback is needed. Protocol work remains on the two protocol-owner threads.
- Existing retained controls are sufficient for configuration, buttons, status, and diagnostic display.
- The application renders continuously. BotHost display controls can compare an observable revision and obtain a synchronized snapshot during ordinary rendering without changing NexusUI.

### App Server and process integration

- No typed Codex App Server binding or long-lived child-process owner currently exists in the repository.
- App Server is bidirectional: the host sends requests/notifications, receives responses/notifications, and answers supported server-initiated requests.
- Its default stdio transport is JSONL, not LSP `Content-Length` framing.
- Free Pascal pipe streams expose available-byte queries used by existing Lazarus/FPC process code. Implementation must verify the installed Windows behavior before fixing the process loop.
- The installed Codex schema and executable version have not been captured. That is the first implementation gate.

### Working-tree boundary

- The working tree contains uncommitted NexusXMPP Phase 2 work, including the MUC and direct-event implementation consumed by this plan.
- BotHost work must not reset, overwrite, or accidentally sweep those changes into a BotHost commit.

## Architecture Problem

The prior plan treated protocol results as data that had to be queued to and dispatched by the application thread. That duplicated event delivery, forced NexusUI to become a protocol pump, and obscured the ownership already present in both protocols.

There are two protocol owners:

1. The NexusXMPP connection thread owns XMPP transport and protocol state.
2. One App Server worker thread owns the child process, JSONL streams, JSON-RPC correlation, Codex thread state, turn state, and pending prompt FIFO.

Each raises ordinary Pascal events on its own thread. BotHost wires them together:

- An XMPP room-message event copies required fields, applies routing, and submits an owned prompt command to the App Server owner.
- An App Server final-answer event submits the answer through `TNXXMPPMUCModule.SendGroupMessage`, which queues it to the XMPP owner.

The GUI is an observer and command source, not the bridge. It reads current BotHost state and invokes start, stop, connect, join, and leave operations. Complex display data is retained by a small BotHost-owned synchronized state object; a register-sized revision tells the GUI when a new snapshot may be useful.

## Target Contract

### Thread and event contract

- The NexusUI application thread owns controls and operator input.
- The NexusXMPP connection thread remains the sole owner of its socket, parser, protocol state, and modules.
- One App Server worker thread owns `TProcess`, stdin/stdout/stderr handling, JSONL framing, typed protocol objects while dispatched, request IDs, response correlation, the Codex thread, active turn, and pending prompt FIFO.
- NexusXMPP events execute synchronously on the XMPP connection thread.
- App Server events execute synchronously on the App Server worker thread.
- Event handlers must be short and may copy data, update BotHost observable state, or submit a command to the other subsystem. They do not wait for the destination subsystem.
- Callback-owned XMPP and App Server objects are borrowed for the callback duration. Retained prompt, answer, identifier, sender, room, error, or diagnostic data is copied before callback return.
- There is no XMPP result queue, App Server result queue, UI protocol pump, application-cycle callback, idle callback, or generalized cross-thread message layer.

### App Server worker and command flow

- Add one bounded App Server command queue for discrete work submitted from other threads. Commands own all managed data they carry.
- Minimum commands are start, stop, submit prompt, and interrupt active turn. Configuration requiring restart is applied before start rather than mutating a live session.
- The worker loop checks commands, available stdout bytes, available stderr bytes, child exit, request deadlines, and active-turn state. It never performs an unbounded blocking read from one pipe while the other can fill.
- Stdout is exclusively protocol JSONL. Stderr is drained independently by the same loop and is exclusively diagnostic text.
- If implementation proves the target `TProcess` cannot safely drain both streams this way, stop and report that concrete conflict before adding another reader thread or queue architecture.
- All stdin writes occur on the App Server owner thread. No write lock or writer thread is required.
- Complete stdout lines are decoded, bound to the registered RTTI message class, validated, and dispatched immediately on the owner thread.
- Malformed UTF-8, oversized frames, malformed JSON, invalid known-method payloads, correlation failures, and unexpected EOF fail the session visibly.
- Unknown notifications are logged and ignored. Unknown server requests receive a typed headerless method-not-found response and never remain pending.

### Typed App Server protocol

- At implementation start, generate the stable schema from the installed `codex app-server`, record the version/fingerprint, and retain a reviewable baseline under BotHost.
- Model every supported request, response, notification, parameter, result, nested object, array, nullable field, and discriminator alternative as a Pascal RTTI/Props class with published properties.
- Published properties and registered external names are the wire contract.
- Schema discriminators choose concrete typed variant classes during binding. BotHost receives typed instances, not generic JSON objects.
- Production BotHost code must not use `GetJSON`, `TJSONObject.Find`, `ValueByName`, dictionaries of JSON values, hand-built JSON, or a second JSON-RPC hierarchy to interpret App Server payloads.
- Raw JSON strings are permitted only as test fixtures proving the typed contract.
- Supported outbound lifecycle is the stable installed equivalent of `initialize`, `initialized`, `model/list`, `thread/start`, `turn/start`, `turn/interrupt`, and thread release/unsubscribe when available.
- Supported inbound lifecycle includes corresponding responses; thread, turn, item, and error notifications; completed agent messages; and every server-initiated approval, permission, network, file-change, command, or user-input request the restricted bot must decline.
- Provide a schema comparison command so Codex upgrades expose drift rather than falling back to dynamic interpretation.

### JSON-RPC envelope policy

- Extend the existing JSON-RPC owner with one explicit standard/headerless envelope policy.
- Existing overloads and users remain strict standard JSON-RPC by default.
- Standard mode requires and emits `jsonrpc = "2.0"`.
- Headerless mode accepts an omitted `jsonrpc`, rejects a present value other than `"2.0"`, and omits it from requests, notifications, success responses, and error responses.
- App Server selects headerless mode explicitly. Do not infer it from method names or duplicate the parser/dispatcher.

### Room routing and turn ownership

- The XMPP room-message handler runs on the connection thread.
- Accept only a valid live groupchat message with a nonempty body.
- Suppress messages from the bot's current room occupant identity.
- Require an exact, case-sensitive leading `@BotNick` followed by whitespace or end-of-message.
- Remove the prefix and immediately following whitespace; reject an empty remainder.
- Enforce configured maximum admitted UTF-8 bytes before copying prompt work.
- Copy room JID, sender occupant JID, message identity, admitted text, and local sequence into an owned prompt command. Never retain message or stanza objects.
- The App Server owner maintains one active turn and a bounded FIFO, default capacity 16. When idle it starts the oldest prompt; when full it rejects the new prompt visibly without displacing older work.
- Each admitted prompt becomes one `turn/start` on the same Codex thread. Do not use steering.
- Terminal XMPP loss, deliberate room leave, App Server death, or shutdown fails queued prompts and interrupts the active turn where supported. Temporary XMPP recovery is not terminal loss.

### Final answer and XMPP transmission

- The App Server owner retains authoritative completed agent-message items for the active turn.
- On successful completion, select the last completed agent message marked `final_answer`.
- If phase may be absent and no agent message in the turn supplies any phase, select the last completed agent message.
- Never send an item explicitly marked `commentary`. Mixed phased commentary and unphased candidates are ambiguous and fail visibly.
- Failed/interrupted turns, missing final answers, empty text, invalid typed items, and ambiguous selection produce no fabricated reply.
- Bound output by configured UTF-8 bytes, default 16 KiB. Truncate only at a UTF-8 boundary and append one explicit marker.
- Raise the final-answer event on the App Server thread. The BotHost handler calls `TNXXMPPMUCModule.SendGroupMessage`, submitting an owned command to the XMPP thread.
- A rejected XMPP command submission is visible and does not repeat the Codex turn.

### Authority contract

- Use a dedicated configured runtime directory, not the Nexus repository or user home.
- Reuse installed Codex authentication. Never store an OpenAI API key.
- Resolve requested Luna identity through typed `model/list`; do not guess or substitute another model.
- Use installed stable restricted/read-only sandbox settings, restricted roots, no tool network, and `approvalPolicy = never`.
- Disable command, file-write, external-network, connector, MCP, and equivalent utility capabilities where stable schema controls exist.
- Version 1 has no approval button. Every server request for command execution, file changes, permission, network escalation, MCP elicitation, or user input receives the typed decline/cancel result and is recorded.
- XMPP text is untrusted conversation. It never grants authority, supplies a local path, changes configuration, or approves a request.

### GUI and observable state

- Provide Start/Stop App Server, Connect/Disconnect XMPP, Join/Leave Room, and Clear View controls.
- Display process/App Server, model, Codex thread/turn, prompt queue, XMPP, room/nickname, routing decisions, authority declines, stderr, and failures.
- Worker event handlers update a BotHost-owned state object. Compound state and retained strings/journal entries are protected only for the short update/copy needed for a consistent snapshot.
- A register-sized revision or dirty indication may be observed without coordination. Missing an intermediate revision is harmless because GUI rendering wants current state, not transition delivery.
- The bounded retained journal preserves discrete diagnostics until eviction or Clear View.
- BotHost display controls compare the revision and obtain a snapshot during normal rendering. They do not advance protocols or call pumps.
- GUI controls invoke public BotHost/XMPP/App Server operations. They never parse JSON, retain stanzas, access pipes, or decide correlation.
- Clearing the view affects display history only.
- No source under `NexusLib/ui` changes.

### Configuration and ownership

- Model non-secret settings as a `TNXPersistObject` with published properties in a user-local BotHost file.
- Persist XMPP identity/endpoint, CA file, resource, room, nickname, Codex executable, model identity, runtime directory, capacities, limits, and timeouts.
- Never persist the XMPP password. Read it from a named environment variable or masked runtime field and retain it only for the connection lifetime.
- The top-level BotHost owns configuration, observable state, router, XMPP client/modules, and App Server owner. Destruction follows termination of both protocol owners.
- Shutdown stops admission, requests turn interruption, fails queued prompts, leaves/disconnects XMPP, closes App Server stdin or uses supported shutdown, waits for bounded worker termination, and force-terminates the child only after the orderly bound.

## Scope

- `NexusLib/core/src/obNXJSONRPCMessages.pas` and focused tests for the headerless policy.
- New `NexusTools/BotHost/` project:
  - `NexusBotHost.lpr` and `.lpi`.
  - `src/obNXBotHostConfig.pas` for published configuration.
  - `src/obNXBotHostState.pas` for current snapshot and bounded journal.
  - `src/obNXBotHostRouter.pas` for pure admission.
  - `src/obNXCodexAppServer.pas` for worker/process/session ownership and command path. Split process mechanics once only if implementation size requires it; ownership remains with the same worker.
  - `src/protocol/` units for schema-derived RTTI types and registered methods.
  - `src/obNXBotHost.pas` for ownership and direct cross-subsystem handlers.
  - `src/uiNXBotHostMain.pas` and BotHost-specific observable display controls.
  - `tests/` with BotHost tests, fake App Server, typed fixtures, and schema baseline/check.
- BotHost documentation for configuration, authority, schema refresh, builds, and live acceptance.
- Existing XMPP APIs as consumers only unless a concrete blocking defect is proved.

## Out Of Scope

- NexusUI framework changes, application-cycle/idle hooks, timer frameworks, application-message abstractions, or UI-owned protocol pumps.
- XMPP/App Server result queues, generic event dispatchers, or generalized cross-thread messaging.
- Free-form JSON, dynamic field dictionaries, parallel JSON-RPC objects, or LSP transport reuse.
- Multiple rooms or simultaneous turns, persistent Codex resume, durable prompts, long-term memory, bot registries, delegation, or bot orchestration.
- Provider abstraction or anything besides local Codex App Server with configured Luna.
- WebSocket/remote App Server, attach, terminal scraping, or pseudo-console automation.
- Command, write, git, build, external-network, MCP/app, connector, or utility authority for room users.
- Chat-client, roster, room-administration, invitation, voice, mobile, daemon, or service features.
- Broad XMPP, process, queue, logging, configuration, JSON-RPC, or schema-generation frameworks.

## Staged Implementation Plan

### Stage 0: Capture the installed contract

1. Resolve the installed executable and record its version.
2. Generate stable App Server schema to a temporary directory.
3. Record lifecycle methods, model identity, types, phase rules, server-request replies, sandbox/approval controls, release/shutdown behavior, and fingerprint.
4. Verify `TProcess` launch and nonblocking availability behavior for separate stdout/stderr on target Windows/FPC.
5. Add approved schema baseline/fingerprint and reproduction command.
6. Report any material contradiction instead of inventing a substitute.

Completion: external/version-dependent assumptions are explicit and reproducible.

### Stage 1: Add headerless JSON-RPC policy

1. Add typed standard/headerless policy to existing JSON-RPC owner.
2. Make validation and response/request creation policy-aware while existing entry points stay standard.
3. Test headerless behavior and rerun strict JSON-RPC/LSP tests.

Completion: App Server can omit `jsonrpc` without changing standard consumers or creating a second stack.

### Stage 2: Bind App Server through RTTI/Props

1. Implement typed classes for supported methods and their complete reachable type graph.
2. Register external method/discriminator names through existing mechanisms.
3. Round-trip fixtures for initialization, models, thread/turn lifecycle, completed messages, failures, authority requests, input, and unknown methods.
4. Add schema drift verification.

Completion: supported messages round-trip through published properties with no free-form production interpretation.

### Stage 3: Implement single-owner App Server worker

1. Implement bounded owned command queue and worker lifecycle.
2. Own `TProcess` and separate stdin/stdout/stderr without merging stderr.
3. Implement nonblocking command/output/timeout/exit loop.
4. Implement bounded UTF-8 JSONL framing, typed dispatch, correlation, direct events, and deterministic shutdown.
5. Implement initialization, model resolution, thread lifecycle, turn lifecycle, final selection, and typed declines.
6. Test with a fake child producing split/combined frames, stderr bursts, delays, invalid messages, unknown messages, and unexpected exit.

Completion: a non-GUI test completes the typed lifecycle through one worker with direct events and no transport-result queue.

### Stage 4: Implement routing, state, and protocol wiring

1. Implement configuration validation and runtime secret acquisition.
2. Implement exact-mention routing and owned prompt copy.
3. Implement bounded pending FIFO and one active turn inside App Server owner.
4. Wire XMPP room event to router to App Server command, and App Server final event to MUC send command.
5. Wire state/error/diagnostic events into synchronized current state and bounded journal.
6. Verify shutdown and borrowed-object lifetimes.

Completion: deterministic tests prove accepted prompts, queued work, response sends, rejections, and snapshots without UI mediation.

### Stage 5: Build GUI without changing NexusUI

1. Build window, inputs, controls, status, journal, and detail view from existing controls.
2. Bind controls to BotHost operations.
3. Add BotHost display controls that render latest snapshot when revision changes.
4. Implement bounded close/shutdown before destruction.
5. Verify rendering only reads state and performs no protocol work.

Completion: GUI remains responsive and accurate with no NexusUI source change or application-thread protocol pump.

### Stage 6: Verify installed App Server

1. Launch it through the GUI using the verified executable/arguments.
2. Confirm typed initialization, auth reuse, model discovery, Luna resolution, thread creation, one turn, answer selection, interruption, and shutdown.
3. Confirm a controlled disallowed request is declined with no authority escape.
4. Confirm process/protocol failures cannot leave false ready state.

Completion: the visible host completes a real restricted local Luna turn without XMPP.

### Stage 7: Complete Openfire room loop

1. Configure bot identity, trusted CA, endpoint, permanent room, nickname, and runtime password without committing credentials.
2. Connect and join through existing NexusXMPP APIs.
3. Exercise unaddressed/history/self/exact/empty/oversized input plus FIFO and overflow.
4. Confirm intermediate items remain local and exactly one final answer uses `SendGroupMessage`.
5. Exercise credentials/room/server/process failures, active-turn shutdown, and restart.

Completion: one live room message traverses typed Codex App Server and one final response returns.

### Stage 8: Document and verify

1. Document setup, secrets, CA trust, authority, GUI, schema refresh, builds, and live test.
2. Review ownership, bounds, borrowed data, snapshots, completion, and shutdown.
3. Remove temporary schema/log/credential/process artifacts.
4. Run complete verification and create the required fresh source archive.

Completion: result is bounded, credential-free in source control, reproducible, and observable in the permanent room.

## Sub-Agent Delegation

Implementation remains local to Main Codex. The human owner has not authorized sub-agent use. This plan, its approval, and later implementation approval do not authorize any sub-agent operation.

## Verification Plan

### Deterministic builds and tests

- Build/run existing JSON-RPC/LSP regression tests after shared policy changes.
- Build/run existing NexusXMPP deterministic suite using its documented isolated FPC command.
- Build/run new fake App Server and BotHost test module.
- Build Windows NexusUI BotHost.
- Run existing NexusUI tests unchanged; no NexusUI production file may differ.

### Focused coverage

- Strict/headerless JSON-RPC requests, notifications, results, errors, invalid shapes/versions, and unchanged LSP output.
- RTTI/Props round trips for every supported App Server method and union alternative.
- Schema match and deliberate drift.
- JSONL split/multiple frames, verified newline forms, UTF-8, limits, malformed lines, EOF, stderr independence, timeouts, and child exit.
- Command capacity/ownership and direct App Server event invocation on worker thread.
- Unknown notification/request, invalid known payload, lifecycle order, missing model, and shutdown completion.
- Typed decline/cancel for every supported authority request.
- Router live/history/self/case/delimiter/empty/size behavior.
- FIFO order/capacity, one active turn, overflow, cancellation, and failure.
- Final/commentary/unphased/mixed/empty/failed/interrupted answer handling and UTF-8 truncation.
- Observable revision, consistent snapshots, bounded journal, concurrent producer/read behavior, and no retained borrowed objects.

### Focused greps

- No BotHost `PumpEvents`, `OnIdle`, application-cycle callback, result queue, UI message queue, or protocol work in rendering.
- No file under `NexusLib/ui` changed.
- No production `GetJSON`, `TJSONObject.Find`, `ValueByName`, generic JSON dictionary, hand-built JSON frame, `poStderrToOutput`, or LSP transport/dispatcher use.
- Only App Server selects headerless JSON-RPC.
- No raw XMPP XML in BotHost; output uses `TNXXMPPMUCModule.SendGroupMessage`.
- No XMPP password, OpenAI key, test password, room credential, or temporary generated schema tracked.

### Manual and live acceptance

1. Repeatedly start/stop App Server and connect/disconnect/join/leave while observing state and responsiveness.
2. Close during initialization, active turn, and queued work; verify bounded exit and no orphan process.
3. Start BotHost, initialize installed App Server, reuse installed auth, resolve exact Luna, and create Codex thread.
4. Connect dedicated XMPP identity and join permanent room.
5. Verify unaddressed input and `@BotNick` alone start no turn.
6. Send exact `@BotNick <question>` and confirm the XMPP-thread event submits one owned App Server prompt command.
7. Confirm intermediate App Server activity remains local.
8. Confirm successful completion selects one eligible answer and the App Server-thread event submits one MUC send command.
9. Confirm another room client observes exactly one response and reflected self message starts no turn.
10. Stop host and confirm leave, disconnect, interruption/release, worker/child exit, and explicit queued-prompt failure.

## Risks And Questions

- Installed Codex version/schema is an implementation-time gate; official examples do not override the generated local stable contract.
- Installed Codex may resolve through a PowerShell shim. Stage 0 must obtain a fixed executable/argument vector without shell-string composition.
- Bind the complete type graph reachable from supported methods without creating a general schema compiler.
- The single App Server worker depends on verified nonblocking availability checks for both child output pipes. A concrete toolchain failure must be reported, not used to silently recreate the old reader/result-queue design.
- State snapshots synchronize retained managed/compound data. The revision does not promise every transition; the retained journal provides history where history matters.
- NexusXMPP MUC/direct-event work is currently uncommitted and must be preserved with narrow BotHost staging.
- Initial configurable defaults are pending prompt capacity 16 and answer limit 16 KiB UTF-8. Stage 0 establishes the App Server frame limit.

No additional human design decision is known before implementation. Report a material Stage 0 contradiction rather than guessing.

## Approval Gate

This plan does not authorize implementation. No code edits, builds, tests, App Server launch, GUI launch, archive creation, or implementation repository operations begin until the human owner explicitly authorizes implementation. Committing and pushing this plan is the planning handoff only and does not authorize implementation or sub-agent use.
