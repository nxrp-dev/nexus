# Work Plan: NexusBot Controller Deadline Removal

## Inputs

- Source request: the human owner's request to remove the NexusBot controller
  deadline machinery after reviewing why the controller owns a dedicated
  polling thread.
- Related discussion: a legitimate component may time out work that it owns,
  but the existence of a pending controller operation does not justify a
  controller-wide timer service or polling architecture.
- Existing constraints: preserve the BotHost control contract, explicit token
  cancellation, exactly-once completion, narrow critical-section boundaries,
  and existing component-local network/process timeouts. Do not add another
  thread, timer service, UI pump, or generalized scheduling abstraction.

## Summary

Remove the controller's generic operation-deadline subsystem in full. A
`TNXBotController` will no longer create a background thread, wake every 25 ms,
scan pending operations, or manufacture a timeout solely because an INVITE or
DISMISS has remained pending for a configured interval.

Pending control operations will continue to complete from the state they are
actually observing: successful host lifecycle transitions, explicit host or
transport failure, explicit cancellation by the request owner, or controller
shutdown. Real timeouts already owned by the App Server and NexusXMPP remain in
their respective execution loops. The controller's token-based `Cancel` method
remains the boundary through which a caller reports that it no longer owns or
cares about a pending operation.

## Verified Findings

- `TNXBotControllerThread` exists only to sleep for 25 ms and call
  `TNXBotController.CheckDeadlines`.
- Every controller constructs and starts that thread, then terminates and joins
  it during destruction.
- Every pending controller operation stores a `Deadline` computed from
  `TNXBotControllerConfig.OperationTimeoutMS`.
- `CheckDeadlines` repeatedly scans the pending collection and routes expiration
  through the same completion arbitration used by explicit cancellation.
- The configured controller timeout defaults to 60 seconds and is persisted as
  `OperationTimeoutMS`. The RTTI persistence reader ignores properties that no
  longer exist on the target class, so an older local JSON file containing that
  property will continue loading after the property is removed; subsequent
  saves will omit it.
- The controller timeout is not the mechanism that times App Server JSON-RPC
  requests. `TNXCodexAppServer` owns `RequestTimeoutMS` and checks those requests
  in its existing process loop.
- It is not the mechanism that times XMPP connection establishment or outbound
  IQ calls. `TNXXMPPConnection` owns connection timing, and
  `TNXXMPPRequestManager` stores and collects outbound IQ deadlines from the
  existing XMPP connection loop.
- `TNXXMPPBotControlModule.Call` correctly exposes an outbound IQ timeout and
  maps an elapsed request to `bceTimeout`. The bot-control result enum and IQ
  `remote-server-timeout` serialization therefore remain valid independently
  of the controller deadline.
- Incoming IQ work already invokes `TNXBotController.Cancel` when its transport
  is permanently lost. Controller shutdown also explicitly cancels retained
  pending operations.
- Human MUC control requests and model-tool control requests complete from the
  same controller lifecycle result. They do not currently own an independent
  response deadline to transfer into the controller.
- MUC join state does not presently have a general join deadline. The generic
  controller timer merely abandons the control request; it does not repair the
  MUC room's lifecycle state. Using the controller timeout to conceal a missing
  terminal transition in another component is therefore not a correct
  ownership boundary.
- Test-program deadlines used to bound a test wait are local test mechanics and
  are unrelated to the production controller thread.

## Architecture Problem

The current design conflates two different facts:

1. Some concrete network or process operations require timeouts.
2. A controller record is waiting to observe several independently owned
   lifecycle transitions.

The first fact does not make the controller the owner of elapsed-time policy.
The controller does not perform the App Server request, XMPP connection, IQ
exchange, or MUC protocol operation. Its deadline can only discard its own
pending record after an arbitrary interval. It cannot determine which
underlying operation expired, correct that component's state, or know whether
the original requester still considers the work useful.

Giving every controller a permanent polling thread adds lifecycle,
synchronization, wakeup, scan, and destruction machinery without establishing
correct timeout ownership. It also duplicates timing already present in the
subsystems that perform timed work.

## Target Contract

### Controller ownership

- Owner: `TNXBotController` owns control-operation admission, active/pending
  record membership, phase claims, explicit token cancellation, exactly-once
  completion, and orderly shutdown.
- The controller owns no clock, deadline, timer, sleeping thread, or polling
  interval.
- A pending record contains only the operation, authorization/completion data,
  active-host ownership, and lifecycle phase/claim state required to advance
  it.
- INVITE and DISMISS complete when observed host state reaches success or an
  explicit terminal failure.
- `Cancel(AToken, AReason)` atomically transfers completion ownership out of the
  pending collection and delivers cancellation outside the controller lock.
- `Shutdown` rejects new admission and explicitly cancels every retained
  operation before releasing active hosts.

### Timeout ownership

- App Server request timeouts remain owned and checked by
  `TNXCodexAppServer`'s existing process loop.
- XMPP connection and outbound IQ timeouts remain owned and checked by the
  existing NexusXMPP connection/request machinery.
- An outbound bot-control caller may continue selecting `ATimeoutMS`; that
  caller receives `bceTimeout` from the XMPP request it owns.
- An incoming transport cancels an accepted controller token when that
  transport is permanently lost, as the IQ adapter already does.
- No replacement timer, delayed callback, application-loop poll, per-operation
  sleeper thread, or shared deadline manager is introduced.
- If a lifecycle component is later demonstrated to lack a required terminal
  timeout, that component must define and own the timeout and surface a normal
  failed lifecycle state. Such a correction is separate from controller
  record lifetime and is not predesigned here.

### Configuration and protocol

- Remove `OperationTimeoutMS` from `TNXBotControllerConfig`, its default value,
  controller validation, and the controller setter.
- Retain `OperationCapacity`; bounding retained work is independent of elapsed
  time.
- Retain `bceTimeout` and all IQ timeout parsing/serialization because actual
  outbound IQ timeouts still use that result.
- Do not add a compatibility property or silently reinterpret the removed
  setting. Older persisted JSON may contain the now-ignored field and will
  naturally lose it on the next save.

## Scope

- `NexusTools/BotHost/src/obNXBotController.pas`
- `NexusTools/BotHost/src/obNXBotHostConfig.pas`
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`
- `NexusTools/BotHost/README.md`
- Other BotHost call sites only if the focused search finds a direct dependency
  on the removed controller timeout API.

## Out Of Scope

- Removing or changing App Server `RequestTimeoutMS`.
- Removing XMPP connection, request-manager, self-ping, or outbound IQ
  timeouts.
- Removing `bceTimeout` or changing the bot-control IQ wire contract.
- Adding MUC join/leave timeout behavior in this pass.
- Adding a timer service, scheduler, application callback, UI polling hook,
  thread pool, or per-operation timeout thread.
- Changing controller authorization, routing, catalog behavior, lifecycle
  phases, capacity, or result wording except where timeout-only test counts are
  removed.
- Changing NexusUI or the XMPP/App Server threading models.
- Refactoring unrelated test-local bounded waits.

## Staged Implementation Plan

1. **Remove the controller thread and deadline state.**
   Delete `TNXBotControllerThread`, `FThread`, the pending `Deadline` field,
   thread construction/destruction, `CheckDeadlines`, and
   `SetOperationTimeoutMS`. Remove deadline assignment during pending admission.

2. **Remove controller timeout configuration.**
   Delete `FOperationTimeoutMS`, its published RTTI property, its default, and
   constructor validation. Preserve `OperationCapacity` and all unrelated
   controller configuration unchanged.

3. **Adjust focused synchronization tests.**
   Replace the controller-lock probe's use of the timeout setter with an
   existing narrow controller memory operation, without adding a test-only
   production API. Remove the test that sleeps and manually calls
   `CheckDeadlines`; adjust exact completion counts accordingly. Retain the
   bounded waits that detect a lock held across callbacks or host behavior.

4. **Preserve explicit completion paths.**
   Re-run cancellation, transport-loss, lifecycle failure, and shutdown tests
   to prove each retained operation is still completed exactly once. Do not
   replace removed deadline completion with implicit polling elsewhere.

5. **Update the BotHost contract documentation.**
   State that the controller has no timing responsibility, identify the
   component-local timeouts that remain, and document explicit cancellation as
   the request-lifetime boundary.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan does not authorize
spawning, resuming, messaging, or delegating to sub-agents. Plan approval and
implementation approval do not grant sub-agent permission; the human owner
must request sub-agent use explicitly in the current conversation.

## Verification Plan

- Focused searches must show no production BotHost reference to:
  - `TNXBotControllerThread`;
  - `FThread` in `TNXBotController`;
  - pending-operation `Deadline`;
  - `CheckDeadlines`;
  - `SetOperationTimeoutMS`;
  - controller `OperationTimeoutMS`.
- Focused searches must still show the intentionally retained local timeout
  owners:
  - App Server `RequestTimeoutMS` and pending-request checks;
  - NexusXMPP connection and request-manager deadlines;
  - outbound bot-control `ATimeoutMS` and `bceTimeout` mapping.
- Build and run the focused BotHost module:

  ```powershell
  lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
  output\NexusTestHost\nxtest_host.exe `
    output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
    run-all
  ```

- The focused controller tests must continue proving:
  - immediate and deferred callbacks run outside the controller lock;
  - start, connect, join, leave, shutdown, and destruction run outside it;
  - explicit cancellation completes once;
  - transport loss during IQ token publication cancels once;
  - controller shutdown cancels retained work once;
  - capacity remains bounded without relying on time expiration.
- Add a persistence assertion that controller JSON no longer emits
  `OperationTimeoutMS` and that JSON containing the obsolete property still
  loads with the remaining values intact.
- Rebuild the NexusBotHost GUI.
- Rebuild and run the standalone fake-App-Server process test to prove its
  independent request timeout path remains intact.
- Rebuild and run the deterministic NexusXMPP suite to prove the retained
  connection/IQ timeout behavior is unchanged.
- Run `git diff --check`, inspect the final diff for scope, and create the fresh
  source archive required after an approved architecture implementation.

## Risks And Questions

- Removing the controller deadline intentionally means that silence alone does
  not discard a pending controller record. Completion requires a real terminal
  lifecycle event, explicit request-owner cancellation, or shutdown.
- A MUC join that remains forever in `joining` would remain a MUC lifecycle
  defect after this change. The removed controller deadline did not repair that
  state; it only stopped waiting for it. If observed, MUC should receive its own
  focused design correction rather than restoring a controller timer.
- The obsolete persisted property is ignored by the current RTTI loader, so no
  migration shim is needed.
- No unresolved choice blocks this plan. In particular, this plan deliberately
  chooses removal without replacement over relocating the same generic
  deadline machinery.

## Approval Gate

This work plan is for review only. No source implementation, build, test,
launch, or archive work begins until the human owner explicitly authorizes it.
Approval to implement does not authorize sub-agent use.
