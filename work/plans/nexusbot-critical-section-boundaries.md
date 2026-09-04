# Work Plan: NexusBot Critical-Section Boundaries

## Inputs

- Source request: the owner's conversation request to correct the newly added
  BotHost control plane after identifying that critical sections are being used
  as execution and routing boundaries rather than narrowly as memory guards.
- Related discussion: critical sections are a last resort; when required, they
  protect one small, autonomous shared-memory operation and are exited
  immediately. They do not own policy, routing, lifecycle work, protocol work,
  callbacks, or object behavior.
- Existing constraints: preserve the approved NexusBot catalog and IQ control
  contract; keep implementation local with no sub-agents; retain event-driven
  XMPP and App Server integration; do not redesign NexusUI or add a general
  concurrency framework.

## Summary

Correct the BotHost control plane so every critical section has one explicit
shared-memory invariant and encloses only the smallest operation needed to
preserve it. In particular, remove the controller lock from authorization,
catalog lookup, status construction, host creation, host lifecycle calls,
state snapshots, completion callbacks, destruction, and shutdown behavior.

The controller will briefly claim or mutate owned records under its lock, then
perform the resulting work after releasing it. Exactly-once completion will be
preserved by atomically extracting the pending record; the thread that extracts
it becomes the sole owner responsible for invoking the callback and freeing the
record outside the critical section.

## Verified Findings

- Production BotHost critical sections occur in four units:
  `obNXBotController.pas`, `obNXXMPPBotControl.pas`,
  `obNXCodexAppServer.pas`, and `obNXBotHostState.pas`.
- `TNXBotController.Execute` currently holds `FCriticalSection` across almost
  the entire operation. While held, it performs authorization and JID work,
  resolves catalog entries, builds status snapshots, creates and destroys host
  objects, changes event handlers, invokes host lifecycle methods, advances
  pending operations, and invokes result callbacks.
- `HostChanged` calls `AdvancePending` while holding the controller lock.
  `AdvancePending` obtains host snapshots, starts App Server processes, connects
  XMPP, joins/leaves rooms, removes records, and completes callbacks.
- `Cancel`, `CheckDeadlines`, and `Shutdown` invoke completion callbacks while
  holding the controller lock. `Shutdown` additionally calls every host's
  shutdown behavior while holding it.
- `CompletePending` extracts a pending record but also removes a newly created
  active host through an owning list and invokes the external completion
  callback. In its current callers, both destruction and callback delivery can
  occur inside the controller critical section.
- `TNXBotController.Host` returns a borrowed host pointer after releasing its
  lock. The lock therefore does not establish a usable lifetime guarantee. The
  method currently has no production caller.
- `TNXXMPPBotControlModule` generally uses its lock narrowly around the incoming
  transport-correlation list and transport-availability flag, and invokes
  controller cancellation and module submission after releasing it.
- The IQ request handoff has one real timing hole: transport loss can extract a
  retained request before `OnRequest` returns its controller token. The current
  post-callback code notices that the correlation record disappeared but does
  not cancel the accepted controller operation after learning its token.
- `TNXCodexAppServer` uses `FCommandLock` only to count, add, or extract owned
  queue entries. Command execution and rejected-command destruction occur after
  release. This is already the intended pattern.
- `TNXBotHostState` protects strings, room/journal lists, and coherent copied
  snapshots. It performs no event callback or host/protocol operation while
  locked. Timestamp formatting can nevertheless be moved before entry so the
  journal lock contains only the list mutation and revision update.
- Critical sections in the standalone and live tests protect small recorder
  values and copied results. They are test synchronization, not control-plane
  routing.
- Controller configuration is exposed as a mutable owned object. The GUI edits
  deployment strings directly while controller entry points can run on other
  threads; the controller lock does not protect those direct writes.

## Architecture Problem

The controller lock currently acts as a substitute for an execution model. It
serializes whole control operations instead of protecting a concrete memory
invariant. This creates three defects:

1. External or potentially slow work runs while unrelated threads are denied
   access to controller memory.
2. Callbacks and host events can re-enter the controller from inside a locked
   operation, making correctness depend on recursive-lock behavior and call
   ordering.
3. The lock appears to guarantee object lifetime and configuration safety where
   it actually cannot, because raw references and mutable configuration escape
   the protected region.

The correction is not to remove synchronization blindly. `FActive` and
`FPending` are owned object collections entered from the application, XMPP,
App Server, host-event, and deadline paths. Their structural mutations require
a small memory guard. The mistake is allowing that guard to govern everything
performed because of those mutations.

## Target Contract

### Critical-section rule

- Every production critical section must name one concrete shared-memory
  invariant in the owning unit.
- A locked region may inspect, add, claim, extract, or replace the memory that
  constitutes that invariant.
- A locked region must not:
  - invoke an event or completion callback;
  - call a host, App Server, XMPP, module submitter, or other owned object's
    behavioral method;
  - parse or serialize protocol data;
  - normalize JIDs or apply authorization/routing policy;
  - obtain another object's synchronized snapshot;
  - create or destroy a host or another substantial owned object;
  - wait, sleep, start/stop a thread or process, or perform I/O.
- Any object removed from an owning collection is extracted under the lock and
  destroyed after release.
- Collection capacity should be established during construction from the
  configured operation capacity and catalog size so the normal locked add path
  does not grow backing storage.

### Controller memory invariants

- The controller lock protects only:
  - structural membership of `FActive` and `FPending`;
  - pending-operation phase/claim flags needed to prevent duplicate actions;
  - token allocation;
  - the shutdown admission flag;
  - atomic replacement/copying of controller-owned deployment configuration,
    if live configuration updates remain supported.
- The catalog is immutable after successful loading and requires no controller
  lock for lookup.
- Authorization inputs are copied values. Authorization and name/JID resolution
  execute without the controller lock.
- A pending operation has an explicit phase sufficient to claim one next action
  under the lock. Claiming changes memory only and returns a local action
  description. The caller executes that action after release.
- Host state is read through `TNXBotHostState.Snapshot` outside the controller
  lock. A snapshot may become stale immediately; lifecycle commands are already
  idempotent, and the pending phase/claim made under the controller lock prevents
  duplicate command dispatch. Later host events or the deadline check advance
  the operation again.
- Active hosts referenced by pending records remain alive until those records
  are completed or cancelled. Failed newly created hosts are detached under the
  controller lock and shut down/freed after release.
- Remove the unused raw `Host()` accessor unless a verified caller appears.
  The controller lock must not be presented as a lifetime guarantee for a
  borrowed pointer.

### Completion and cancellation

- Exactly-once completion is a memory-ownership decision:
  - locate and extract the pending record under the controller lock;
  - release the lock;
  - perform any failed-host cleanup;
  - invoke the saved completion callback;
  - free the extracted record.
- If extraction fails, another path already owns completion and the caller does
  nothing.
- Immediate LIST/STATUS/error/no-op results are fully constructed without the
  lock and delivered without the lock. Token allocation remains one brief
  locked operation.
- Deadline checking collects or extracts expired records under the lock and
  completes them afterward. The deadline thread never executes callbacks or
  host behavior while holding controller memory.
- Shutdown briefly closes admission and detaches pending/active ownership under
  the lock. It then cancels callbacks, removes event handlers, shuts down hosts,
  and destroys detached records after release.

### Configuration ownership

- Stop exposing controller-owned mutable deployment data as an unsynchronized
  object graph used concurrently by the GUI and controller.
- The GUI retains the persisted editable configuration. The controller receives
  its own copied configuration at construction.
- If `ApplySettings` must update a running controller, it submits one complete
  deployment value through an explicit controller method. That method performs
  only the minimal protected replacement/copy; it does not persist, reconnect,
  create a host, or invoke callbacks while locked.

### Existing valid guards

- Retain the App Server command-queue lock. Its invariant is ownership and FIFO
  structure of `FCommands`; enqueue/dequeue/count remain its only locked work.
- Retain the host-state lock for coherent mutation/copying of managed strings
  and lists. Precompute journal timestamp text before entry, and keep callbacks
  outside the state object as they are now.
- Retain the IQ module lock for its bounded transport-correlation list and
  transport-availability flag. Controller callbacks, cancellations, XML work,
  and module submissions remain outside it.
- Correct the IQ token-publication timing hole: after `OnRequest` returns, either
  attach the token to a still-retained correlation record under the IQ lock, or,
  if transport loss already extracted the record, cancel the newly accepted
  controller token after releasing the IQ lock.
- Test recorder locks remain small memory guards and require no architectural
  change.

## Scope

- `NexusTools/BotHost/src/obNXBotController.pas`
- `NexusTools/BotHost/src/obNXXMPPBotControl.pas`
- `NexusTools/BotHost/src/obNXBotHostState.pas`
- `NexusTools/BotHost/src/obNXBotHostConfig.pas` and
  `NexusTools/BotHost/uiNXBotHostMain.pas` only for copied configuration
  ownership and an explicit update boundary
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`
- `NexusTools/BotHost/tests/NexusBotHostTests.lpr` and live tests only where
  existing call sites or focused concurrency verification require adjustment
- BotHost documentation describing the controller ownership boundary

## Out Of Scope

- Removing all critical sections merely because they exist.
- Changing NexusUI or adding an application-message facility.
- Replacing Pascal events with a generalized event bus, dispatcher, actor
  framework, task system, or synchronization abstraction.
- Redesigning NexusXMPP threading, App Server transport, the bot catalog, IQ
  wire format, authorization rules, or lifecycle semantics.
- Adding new commands, providers, GUI management features, or persistent data.
- Reworking test-recorder synchronization that already protects only small
  copied memory values.
- Opportunistic synchronization cleanup outside BotHost.

## Staged Implementation Plan

1. **Encode the critical-section contract in focused tests.**
   Add deterministic probes that demonstrate completion callbacks and host
   lifecycle calls can synchronously wait on another thread entering a
   controller read/execute path. The probe must use bounded waits and fail
   normally rather than hanging the test process. Add an IQ test for transport
   loss during the request/token handoff.

2. **Separate controller decisions from memory claims.**
   Split the current monolithic `Execute`, `AdvancePending`, and
   `CompletePending` flow into small helpers that either perform pure
   policy/status work without the controller lock or make one brief collection
   transition under it. Introduce only the minimal pending phase/action data
   required to claim work once.

3. **Move immediate execution outside the lock.**
   Perform authorization, catalog resolution, room-JID validation, status
   snapshots, host construction, and immediate callback delivery without the
   controller lock. Use short reserve/adopt operations to publish a newly
   constructed host and resolve a competing creation deterministically.

4. **Move lifecycle advancement outside the lock.**
   Have host notifications and explicit execution request an advancement pass.
   Each pass reads host state outside the controller lock, briefly claims the
   next transition, releases the lock, and then calls `StartAppServer`,
   `ConnectXMPP`, `JoinRoom`, or `LeaveRoom`. Feed rejection/failure back through
   the same claim-and-complete path.

5. **Correct completion, deadline, failure cleanup, and shutdown.**
   Make pending extraction the sole exactly-once arbitration point. Complete
   callbacks and free/stop hosts only after release. Make deadline and shutdown
   paths detach their work first and perform behavior second. Remove the unused
   unsafe `Host()` accessor.

6. **Correct deployment configuration ownership.**
   Give the GUI its persisted editable configuration and the controller its own
   copy. Replace direct mutation of controller-owned bindings with one explicit
   whole-binding update method if live edits must remain visible to future bot
   creation.

7. **Close the IQ token-publication race.**
   Preserve the IQ adapter's narrow correlation lock, but make the outcome of
   `OnRequest` publication explicit: retained-and-tokenized, synchronously
   completed, or transport-lost-and-cancelled. Invoke `OnCancel` only after
   releasing the IQ lock and prove duplicate lifecycle notification still
   cancels exactly once.

8. **Audit every remaining BotHost locked region.**
   Review all four production units against the target rule. Leave the valid
   queue/state/correlation locks in place, with method structure making their
   limited invariant apparent. Do not broaden the pass beyond BotHost.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan does not authorize
spawning, resuming, messaging, or delegating to sub-agents. Plan approval and
implementation approval do not grant sub-agent permission; the human owner must
request sub-agent use explicitly in the current conversation.

## Verification Plan

- Build and run the focused BotHost module:

  ```powershell
  lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
  output\NexusTestHost\nxtest_host.exe `
    output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
    run-all
  ```

- Focused tests must prove:
  - immediate and deferred completion callbacks execute without the controller
    lock held;
  - host start/connect/join/leave/shutdown calls execute without it held;
  - callback or host-event re-entry from another thread completes within a
    bounded interval;
  - racing lifecycle, deadline, cancellation, and shutdown paths still complete
    one operation exactly once;
  - a newly created failed host is detached once and destroyed outside the
    controller critical section;
  - concurrent creation for one catalog bot publishes one owned active host;
  - IQ transport loss during token publication cancels the accepted controller
    operation exactly once;
  - LIST/STATUS/INVITE/DISMISS authorization, idempotency, and result contracts
    remain unchanged.

- Rebuild and run the standalone fake-App-Server process test.
- Rebuild the NexusBotHost GUI application.
- Rebuild and run the deterministic NexusXMPP suite because the IQ adapter is
  part of an XMPP module, even though the generic XMPP threading model is not
  being changed.
- Run the existing Openfire BotHost live test when external model access is
  available; verify LIST, STATUS, DISMISS, INVITE, addressed room messaging, and
  orderly shutdown remain functional.
- Focused searches must show that no controller critical-section region
  contains calls to:
  - `ACompletion` or any event property;
  - `StartAppServer`, `ConnectXMPP`, `JoinRoom`, `LeaveRoom`, or `Shutdown`;
  - `State.Snapshot`;
  - `CreateConfiguredHost`;
  - owning-list deletion that destroys a host.
- Inventory every remaining production `EnterCriticalSection`/`Acquire` region
  in BotHost and record the single memory invariant it protects.
- Run `git diff --check`, inspect the final diff for scope, and create the fresh
  source archive required for an approved architecture implementation.

## Risks And Questions

- Moving behavior outside the controller lock exposes places where the lock was
  accidentally supplying sequencing. Explicit pending phases and atomic claim
  flags must replace that accidental sequencing before calls are moved.
- A host pointer cannot safely outlive its owning active record by virtue of a
  lock that has already been released. Pending records must retain a valid host
  lifetime, and public borrowed access should be removed rather than cosmetically
  relocked.
- Completion and host event callbacks may run synchronously. All state required
  before those callbacks must therefore be published before invoking behavior,
  without holding the critical section while the callback occurs.
- Configuration strings are managed memory, not benign register-sized state.
  Direct cross-thread mutation must be replaced by a copied-value ownership
  boundary.
- No unresolved design decision is required. The existing control-plane
  behavior remains the contract; this pass changes only synchronization,
  ownership publication, and execution boundaries.

## Approval Gate

This plan is a planning artifact only. No implementation, build, test, launch,
archive, or source change begins until the human owner explicitly authorizes
implementation. Approval to implement does not authorize sub-agent use.
