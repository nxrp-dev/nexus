# Work Plan: BotHost Threading and Application-Message Communication

## Inputs

- Source request: `C:\Users\kcollins\Downloads\bothost-threading-event-communication-redesign-request.md`.
- Human-owner discussion clarifying the intended threading model:
  - Long-lived threads already own execution loops; do not add an application idle/update cycle merely to poll worker queues.
  - Register-sized current-state values may be observed through benign races when either the old or new value is valid, delayed observation is harmless, and the application loop will observe again.
  - Complex or discrete data crosses into the application by transferring an owned message through the application message queue.
  - Commands directed to worker loops, current observable state, retained application messages, and coordinated shutdown are different contracts and must not be implemented as one generic event pattern.
  - The original Codex/Luna XMPP GUI Bot Host implementation is deferred while this prerequisite architecture is corrected.
- Existing work plan being unblocked: `work/plans/codex-luna-xmpp-gui-bot-host.md`. Its proposed application-cycle callback and periodic draining are rejected by this plan; its remaining BotHost behavior is not part of this implementation.
- Existing constraints:
  - `TNXApplication` remains the owner of NexusUI application execution and `ProcessMessages` remains the application message-processing seam.
  - The NexusXMPP connection thread remains the exclusive owner of its socket, framing, negotiation, request correlation, stream management, and protocol loop.
  - Network code must not depend on NexusUI.
  - Queued complex payloads own their data, and application callbacks must not execute on the XMPP connection thread.
  - No sub-agent use has been authorized.

## Summary

Add a real, general application-message path to Nexus application execution and use it as an optional NexusXMPP result-delivery path. A worker posts one owned application message; the existing NexusUI message loop receives and dispatches it on the application thread. The implementation does not add an idle callback, timer, update phase, protocol pump, or second application-polled queue.

NexusXMPP keeps its command queue because those commands are discrete work for the connection loop. Its current-state observation remains state rather than queued work. Stanzas, IQ completions, errors, unrecoverable-stanza reports, and lifecycle deliveries remain owned discrete data, but a NexusUI consumer may route them directly into application messages rather than periodically calling `PumpEvents`. Explicit pumping remains available for non-NexusUI consumers such as the console example and live-test harness.

This is a prerequisite enhancement only. It proves the execution, delivery, ownership, overflow, and shutdown contracts needed later by BotHost and its App Server readers without implementing any BotHost or App Server feature.

## Verified Findings

### NexusUI application execution

- `TNXApplication.Run` owns one application-thread loop that calls `ProcessMessages` and then `Render`.
- `TNXApplication.ProcessMessages` drains `TNXPlatform.PollEvent` and dispatches each returned `TNXEvent` through `HandleEvent`.
- `TNXEvent` currently represents quit, window, keyboard, mouse, wheel, and text-input messages. It has no application-message payload.
- `TNXPlatform` exposes `PollEvent` but no operation for a worker to post an application-owned message into that same stream.
- `TNXSDL2.PollEvent` currently translates only SDL window and input events.
- SDL2 provides the missing backend operation directly: `SDL_PushEvent` is thread-safe, copies the SDL event structure into the existing event queue, reports queue-full/failure, and recommends `SDL_RegisterEvents` for application-specific event types. An SDL user event can carry an owned object pointer through `data1`.
- The NexusUI test module currently contains persistence tests only; there is no application-message lifecycle or cross-thread delivery coverage.

### NexusXMPP communication

- `TNXXMPPConnection.OnlineLoop` already performs command processing, bounded socket receiving, frame parsing, incoming-stanza handling, and IQ timeout collection.
- Application-to-connection work crosses through a bounded `TNXXMPPObjectQueue` as raw XML, IQ, module-operation, or disconnect commands. This queue is justified because each command is retained work for the connection thread.
- The connection exposes current connection state separately through `State`. Disconnect is coordinated through the disconnect-request state and transport interruption.
- `TNXXMPPConnection.FCriticalSection` protects only `FState` and `FDisconnectRequested`. The connection thread is the state writer and the application is an observer; the application requests disconnect and the connection loop observes it. Both values are register-sized, either observed value is valid for that iteration, and the loops observe again. The critical section is therefore not protecting retained data or a compound invariant.
- Connection-to-application data currently crosses through a second bounded `TNXXMPPObjectQueue` as:
  - connection-state transition;
  - parsed stanza;
  - error details;
  - IQ completion;
  - unrecoverable-stanza report;
  - module lifecycle transition.
- `TNXXMPPClient.PumpEvents` is the only consumer of that queue. It updates the client state, pumps stanzas and lifecycle into modules, and invokes completion/application callbacks on the calling thread.
- The console example, deterministic callback-thread test, and live Openfire test explicitly call `PumpEvents`. These are current non-NexusUI consumers and provide a real reason to retain explicit-pump delivery as an option.
- NexusXMPP modules are fixed while connected. Application-side module state and callbacks are advanced when the client processes a delivered stanza, IQ completion, or lifecycle item.
- `NexusLib/net/src/xmpp/AGENTS.md` currently states that application callbacks run only through caller-thread event pumping. That repository rule must be corrected to permit either explicit caller-thread pumping or application-message dispatch while still prohibiting connection-thread application callbacks.

### BotHost and App Server boundary

- No BotHost or App Server transport implementation exists yet.
- The deferred BotHost plan proposed separate stdout/stderr readers, a bounded transport-event queue, and an application-cycle callback that periodically drained that queue and called `TNXXMPPClient.PumpEvents`.
- Routing mentions, serializing admitted room requests, selecting final answers, coordinator transitions, GUI journaling, and GUI projection are application-thread work. They do not require cross-thread queues.
- Complete App Server responses, notifications, server requests, and retained diagnostics will later be suitable application-message payloads. Current process/session phase and similar latest-value observations will later be suitable shared state. This plan establishes the receiving path but does not implement those producers.

## Architecture Problem

The existing XMPP implementation correctly prevents its connection thread from executing arbitrary application callbacks and correctly retains complex data until another thread consumes it. It then makes periodic caller polling fundamental to delivery. The deferred BotHost plan copied that shape for App Server readers and proposed a new NexusUI application-cycle callback whose main purpose was to poll both subsystems.

That treats all cross-thread communication as queued events and adds an execution cycle to discover work even though the producing threads know when work is ready and the application already owns `ProcessMessages`.

The missing architectural room is a general application message: a worker must be able to transfer ownership of one complete message into the existing application message stream. NexusUI should dispatch that message on the application thread exactly as it dispatches its other application/platform messages. Protocol libraries must be able to target that capability without acquiring a dependency on NexusUI.

Observable state remains distinct. A current register-sized value may be observed as old or new when no intermediate transition is required and the application naturally observes it again. A dirty indication may suppress unnecessary application projection work. It is not a substitute for discrete data that must be retained.

## Target Contract

### Shared application-message contract

- Define the minimal shared application-message and message-target contract under `NexusLib/core`, in units named according to the repository's `ob...`/`tp...` ownership convention.
- An application message is an owned object with application-thread dispatch behavior. Concrete subsystems define concrete message types; the shared contract does not contain XMPP, App Server, GUI, or protocol-specific fields.
- A message target accepts an application message from any producer thread and reports whether the post succeeded.
- Ownership is explicit:
  - before posting, the producer owns the message;
  - a successful post transfers ownership to the target/application message queue;
  - a failed post leaves ownership with the producer, which must handle or free it;
  - after application-thread dispatch, the application frees the message even if dispatch raises.
- Posting does not execute the message, its destination, or arbitrary application callbacks on the producer thread.
- The shared contract is only the cross-library boundary. It does not introduce a general actor system, task scheduler, future/promise API, broadcast bus, subscription framework, or generic worker-thread framework.

### NexusUI application-message path

- `TNXApplication` implements the shared message-target contract and exposes the narrow post operation.
- Add an application-message case to the existing `TNXEvent`/`ProcessMessages` path. Application messages are processed in the same ordered stream as other application/platform messages, on the thread executing `ProcessMessages`.
- Extend `TNXPlatform` with the minimum backend operation required to post an owned application message into its native application event queue.
- `TNXSDL2` registers a unique SDL user-event type and uses `SDL_PushEvent` to transfer the message pointer into SDL's existing thread-safe event queue. Do not add a parallel Nexus-owned queue behind an SDL wake event.
- `TNXSDL2.PollEvent` recognizes only its registered application-event type, returns the owned application message through `TNXEvent`, and leaves unrelated SDL user events alone.
- Backend post failure is visible to the producer. NexusUI does not silently drop or free a message that it did not accept.
- `ProcessMessages` dispatches accepted messages and frees them in a `finally` path. One failing message must not leak its payload or cause later owned messages to be abandoned silently.
- Application termination stops the run loop but does not make successfully posted messages ownerless. Finalization drains and frees any Nexus-owned application messages that remain in the backend queue without dispatching application behavior after teardown has begun.
- The application and all registered producer threads obey a coordinated lifetime contract: producers stop and are joined before the application/platform message target is destroyed. No attempt is made to make destruction itself a benign race.

### Observable-state contract

- Do not route a current value through an allocated application message merely so code can ask for the latest value.
- A benign-race observation is permitted only when the communicated value fits one ordinary register-sized value on every supported target, has no compound invariant, either the prior or subsequent value is valid, delayed observation is harmless, and no intermediate transition must be retained.
- Where a dirty indication is useful, the producer updates the state and then marks it dirty. The application observes dirty during its normal loop, clears the indication before inspecting the current state, and naturally observes again if the producer marks it dirty during or after that inspection.
- Dirty state is an optimization for observing latest state, not a notification record. Anything that must occur once per item or preserve order remains an application message.
- Strings, object graphs, stanzas, protocol responses, diagnostics that must be retained, and multi-field snapshots are transferred as owned messages rather than exposed as benign-race values.

### NexusXMPP delivery contract

- Preserve the existing bounded application-to-connection command queue and the connection thread's ownership of all transport/protocol work.
- Add an optional application-message target to `TNXXMPPClient`. It is configured while disconnected and remains stable for the connection lifetime.
- When no application-message target is assigned, retain the current bounded event queue and `PumpEvents` behavior for console, tests, and other explicit-pump consumers.
- When a target is assigned, each retained connection-to-application item is wrapped as an owned NexusXMPP application message and posted immediately by the connection thread. Do not also enqueue the item into the pump queue.
- Dispatch of that message on the application thread performs the same client/module work currently centralized in `PumpEvents`: stanza pumping, module lifecycle pumping, IQ completion, and application callback invocation.
- Extract that single-item handling into one client-owned method used by both `PumpEvents` and application-message dispatch. There must not be two implementations of XMPP event semantics.
- The connection thread may invoke only the target's ownership-transfer post operation. It must never dispatch the message or call the application/module callbacks directly.
- A failed post has the same severity as current event-queue exhaustion when the item cannot be discarded safely: the connection retains/frees the rejected message according to the ownership contract, enters a visible failure path, interrupts blocking transport work, and does not pretend delivery succeeded.
- Current connection state remains directly observable through `State`. State-transition callback delivery may still be represented by an application message when the callback contract requires the transition; the current value itself is not derived by draining messages.
- Treat `TNXXMPPConnection.FState` and `FDisconnectRequested` as the concrete benign-race state crossings in this pass. Remove the connection critical section that exists solely around those values. `State` performs an ordinary observation; `RequestDisconnect` sets the request before interrupting the blocking transport; the connection loop naturally checks the request again. Do not replace this lock with an atomic wrapper, semaphore, event, callback, or command solely because the values cross threads.
- Retain synchronization inside the command and retained-event queues because their list mutation, bounds, item ordering, and ownership are compound operations. Removing the state lock does not authorize unsynchronized collection access.
- Module lifecycle items that drive module behavior, parsed stanzas, IQ completions, error records, and unrecoverable-stanza reports remain discrete deliveries. They are not collapsed into dirty flags.
- Update the XMPP architecture instructions to state the real invariant: application/module callbacks execute only on the consumer thread, reached either through explicit `PumpEvents` or through application-message dispatch; they never execute on the connection thread.

### App Server readiness contract

- Add one focused synthetic application-message test type proving that a future pipe reader can post a complete owned object from a worker thread and have it dispatched by `ProcessMessages`.
- Do not add Codex protocol types, stdout/stderr readers, `TProcess`, JSONL framing, transport queues, process state, or BotHost coordinator code in this pass.
- The later App Server implementation will define its own concrete application-message types and post complete typed protocol/diagnostic items directly. It will not add the deferred bounded transport-event queue or require an application-cycle drain.

### Shutdown and destruction contract

- Normal message transfer and current-state observation do not acquire a global application lock.
- Shutdown is coordinated because object and backend lifetime are involved:
  1. stop accepting new application work at the subsystem level;
  2. request worker termination and interrupt blocking I/O where necessary;
  3. wait for worker loops to finish posting;
  4. process or explicitly discard remaining owned application messages;
  5. destroy clients, modules, message target, platform, and application state in owner order.
- NexusXMPP disconnect/destruction must finish the connection thread before releasing its application-message target or objects referenced by pending XMPP application messages.
- Tests must prove that accepted messages are dispatched or freed exactly once and that failed posts leave no ambiguous owner.

## Scope

- Shared minimal application-message/target contract under `NexusLib/core/src`.
- `NexusLib/ui/src/tpNXEvents.pas` for the application-message event representation.
- `NexusLib/ui/src/obNXPlatform.pas` for the abstract post operation.
- `NexusLib/ui/src/obNXSDL2.pas` for registered SDL user-event posting and polling.
- `NexusLib/ui/src/obNXApplication.pas` for target implementation, dispatch, ownership, and teardown handling.
- `NexusLib/ui/tests` and its project file for deterministic message ownership, ordering, thread, failure, and shutdown coverage.
- NexusXMPP event/client/connection units needed to add optional application-message delivery and centralize single-item handling.
- Existing NexusXMPP deterministic tests, live-test harness, and console example only where required to prove or demonstrate the two supported delivery modes.
- `NexusLib/net/src/xmpp/AGENTS.md` and narrowly relevant architecture documentation to replace the pump-only rule with the approved consumer-thread delivery contract.
- The communication section of `work/plans/codex-luna-xmpp-gui-bot-host.md` only after implementation, to record that its application-cycle/polled-transport design has been superseded. Do not otherwise revise or begin that plan.

## Out Of Scope

- Creating `NexusTools/BotHost` or any BotHost source, tests, configuration, GUI, router, coordinator, FIFO, journal, or project files.
- Launching or binding Codex App Server, generating its schema, defining its RTTI/Props protocol objects, reading stdout/stderr, or implementing JSONL/JSON-RPC transport.
- The JSON-RPC headerless-envelope enhancement from the deferred BotHost plan.
- Changing XMPP wire behavior, reconnection, stream management, MUC behavior, message semantics, or command submission architecture.
- Removing `PumpEvents` or forcing NexusUI/application-message ownership on console and non-UI consumers.
- Replacing command queues with shared flags or executing XMPP commands on the application thread.
- Adding an idle callback, update callback, timer, render hook, BotHost-specific NexusUI callback, protocol-specific NexusUI event, or separately polled application queue.
- General thread pools, schedulers, actors, futures, promises, cancellation frameworks, observer buses, or asynchronous runtime abstractions.
- Broad NexusUI event/render-loop redesign, frame pacing, or SDL backend replacement.
- Treating every state change as retained history or eliminating synchronization from genuine ownership/destruction coordination.

## Staged Implementation Plan

### Stage 1: Establish the shared ownership contract

1. Add the minimal shared application-message base and target contract under NexusLib core.
2. Encode successful-post ownership transfer and failed-post retained ownership directly in the API and focused tests.
3. Keep dispatch polymorphic and application-thread-owned so shared code needs no protocol registry or free-form payload inspection.

Completion: a producer and target can exchange one owned application message without importing NexusUI or a protocol dependency.

### Stage 2: Integrate application messages into NexusUI

1. Add application messages to `TNXEvent` and the `TNXApplication.ProcessMessages` dispatch path.
2. Add the abstract platform post operation.
3. Register a unique SDL user-event type and implement thread-safe posting through `SDL_PushEvent`.
4. Translate the registered event back into the owned Nexus application message during `PollEvent`.
5. Implement failure, dispatch-exception, termination, and finalization ownership behavior.

Completion: a worker can post a message directly into the existing NexusUI/SDL application message stream, and it executes exactly once on the `ProcessMessages` thread without an idle callback or auxiliary polled queue.

### Stage 3: Add deterministic NexusUI communication tests

1. Add a focused UI test unit and register it in `NexusUITestModule`.
2. Prove same-thread and worker-thread posting, FIFO order, exact dispatch thread, successful ownership transfer, post failure ownership, dispatch-exception cleanup, and pending-message finalization.
3. Prove ordinary input/window event handling remains unchanged around application messages.
4. Use a controlled test message with construction/destruction counters so leaks and double frees are observable.

Completion: the generic application-message room is independently proven before any protocol uses it.

### Stage 4: Give NexusXMPP optional application-message delivery

1. Add a disconnected-only application-message-target setting to `TNXXMPPClient`.
2. Extract one-event application-side processing from `PumpEvents` without changing its semantics.
3. Add the concrete owned XMPP application-message wrapper and route connection results either to the configured application target or to the existing pump queue, never both.
4. Preserve command delivery, current-state observation, connection-thread ownership, module processing, callback thread, event ordering, capacity failure, and disconnect behavior.
5. Remove the connection critical section used only by `FState` and `FDisconnectRequested`, retaining the established write/read order around transport interruption and loop observation.
6. Update the XMPP folder instructions and the console/live-test commentary to describe benign state observation plus explicit-pump and application-message modes accurately.

Completion: NexusUI consumers no longer need to poll `PumpEvents`, while current non-UI consumers continue using the explicit pump.

### Stage 5: Verify lifecycle and supersede the blocked plan section

1. Exercise shutdown with messages queued before disconnect, during disconnect, after worker exit, and during application finalization.
2. Prove worker termination precedes target/client destruction and every accepted payload reaches one terminal ownership state.
3. Run the complete UI and XMPP deterministic suites and the existing XMPP live test only if its required local configuration remains available.
4. Replace only the obsolete application-cycle/polled-delivery statements in the deferred BotHost plan with a reference to the implemented application-message architecture. Leave all BotHost implementation stages deferred.
5. Update narrow architecture/dependency documentation with the core contract and permitted dependency direction.

Completion: the threading roadblock is resolved, documented, and ready for the separately approved BotHost implementation to consume later.

## Sub-Agent Delegation

Implementation remains local to Main Codex. The human owner has not authorized sub-agent use. This plan, plan approval, and any later implementation approval do not authorize spawning, resuming, messaging, or delegating work to sub-agents.

## Verification Plan

### Deterministic builds and tests

- Rebuild the NexusUI test module:
  - `lazbuild -B NexusLib\ui\tests\NexusUITestModule.lpi`
- Run the NexusUI test module through the established NexusTest host and require zero failures.
- Rebuild and run the existing deterministic NexusXMPP suite using the command/output isolation documented in `NexusLib/net/tests/NexusNetXMPPTests.md`.
- Rebuild the XMPP console example to prove explicit-pump consumers remain supported.
- Rebuild any NexusUI application project already used by the repository as a regression target for `TNXApplication` and `TNXPlatform` interface changes.

### Required focused coverage

- Posting from a real worker thread and dispatch on the application/`ProcessMessages` thread.
- FIFO ordering relative to other posted Nexus application messages.
- Success transfers ownership; failure retains ownership; dispatch frees exactly once even on exception.
- SDL registration and post failure are visible and do not leak payloads.
- Application finalization frees accepted but undispatched Nexus application messages.
- Producer shutdown/join completes before target teardown.
- NexusXMPP explicit-pump mode preserves existing event order, module pumping, callbacks, and callback thread.
- NexusXMPP application-message mode performs those same semantics on the application thread without calling `PumpEvents`.
- Application-message mode does not duplicate an item into the pump queue.
- Target-post overflow/failure produces a visible connection failure rather than silent loss.
- Direct `State` observation does not require draining either delivery mechanism.
- Connection state and disconnect-request observation remain correct without their former critical section, including disconnect interrupting a blocked receive and terminal failure remaining observable.

### Focused greps

- Prove NexusUI has no application-cycle, idle, update, timer, BotHost, XMPP, or App Server hook.
- Prove application messages use the platform/SDL event stream and no second NexusUI queue was introduced.
- Prove NexusXMPP does not depend on `NexusLib/ui` or SDL units.
- Prove the connection thread has no direct application/module callback invocation in either delivery mode.
- Prove the removed connection critical section was not replaced by new synchronization around register-sized `FState` or `FDisconnectRequested`; prove queue synchronization remains.
- Prove retained XMPP results select exactly one delivery path.
- Prove no BotHost or App Server implementation files were added by this work.

### Manual checks

- Run a minimal NexusUI test application that posts visibly identifiable messages from a worker while ordinary keyboard, mouse, resize, and quit processing remains responsive.
- Close the application while the worker is active and verify the coordinated stop/join order and absence of a late dispatch into destroyed state.
- If the local Openfire environment is still configured, run the existing live XMPP scenario once in explicit-pump mode. A future BotHost acceptance run will exercise application-message mode after the original plan resumes.

## Risks And Questions

- The installed Pascal SDL2 binding location was not available as source during planning. Implementation must verify the exact declarations and layout for `SDL_RegisterEvents`, `SDL_PushEvent`, `TSDL_Event.user`, and `data1` before coding; do not guess or recreate incompatible declarations.
- SDL event queues are bounded and `SDL_PushEvent` can fail. The failure result is part of the application-message contract and must be exercised rather than treated as impossible.
- An application message may reference a destination object. The destination must outlive every accepted message that can dispatch to it; this is enforced through shutdown ordering, not hidden reference-counting or a global lock.
- Explicit-pump XMPP mode and application-message mode share one single-item handler. If extraction reveals current event processing that assumes queue ownership rather than event ownership, correct that ownership locally rather than duplicating behavior.
- State transitions that drive module behavior are not reducible to a latest-value observation. The implementation must preserve those ordered lifecycle deliveries while allowing simple current state to remain directly observable.
- The working tree contains the human owner's uncommitted NexusXMPP Phase 2 implementation. Planning changes must not include those files in the work-plan commit, and later implementation must preserve them.
- No human design decision is currently required. If exact SDL binding behavior contradicts the verified SDL2 contract or if an existing current consumer requires a single mandatory XMPP delivery model, stop and return that concrete conflict rather than inventing a compatibility layer.

## Approval Gate

This work plan authorizes only its own planning artifact. No source edits, builds, tests, program launches, archive creation, or implementation repository operations begin until the human owner explicitly authorizes this prerequisite implementation. Approval of this plan does not resume or authorize the deferred BotHost work and does not authorize sub-agent use.
