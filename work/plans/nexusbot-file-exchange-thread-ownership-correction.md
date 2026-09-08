# Work Plan: NexusBot File Exchange Thread Ownership Correction

## Inputs

- Source request: the human owner's conversation request to correct the current
  per-transfer file-exchange implementation.
- Related implementation plan:
  `work/plans/nexusbot-per-transfer-thread-workplan-request-v3.md`.
- Related review: the verified discussion of cancellation/commit arbitration,
  callback event handoff, critical-section purpose, transfer-object lifetime,
  and the absence of a sole exchange execution thread.
- Existing constraints: one accepted transfer remains one `TThread` because its
  blocking HTTP operation must not stop XMPP, provider, or other transfer
  progress; no exchange-owner thread, dispatcher, worker pool, lifecycle
  service, polling loop, or standalone test harness; no sub-agent use is
  authorized.

## Summary

Correct the concurrency and ownership defects in the completed thread-per-
transfer implementation without changing its fundamental execution model.

The correction will:

- arbitrate cancellation and commitment through one fixed-width `LongInt`
  atomic terminal state;
- publish the cancellation reason through protection dedicated solely to that
  complex string value;
- use the existing callback event as the outbound callback-result handoff;
- limit critical sections to the singular complex-memory collections they
  protect;
- retain the transfer object explicitly while it is used outside the live
  collection, so cancellation and startup cannot race object destruction and
  no critical section becomes a lifetime mechanism;
- remove HTTP abort, filesystem work, callbacks, joins, destruction, and
  avoidable construction from collection critical sections; and
- rename the obsolete transfer `Queue*` terminology.

This is a correction of the current implementation, not a redesign of
NexusXMPP, BotHost, or application event routing.

## Verified Findings

- `TNXBotFileTransferThread` derives directly from `TThread`; every accepted
  inbound or outbound transfer has its own thread and executor.
- `TNXBotHost` is entered directly from several legitimate threads:
  - XMPP message/state callbacks execute on `TNXXMPPConnection`;
  - provider callbacks execute on the provider's worker path;
  - file prompt completion executes on the individual transfer thread; and
  - startup/shutdown execute on the main application thread.
- The console main thread currently waits for shutdown and is not an exchange
  dispatcher. There is no existing sole "exchange owner" execution context.
- `TNXBotFileExchange.FCriticalSection` currently protects the live-transfer
  collection, artifact collection, staging reservations, admission state,
  lookup, cancellation enumeration, reaping, and shutdown cleanup.
- `SignalProvider`, `SignalRoom`, and `SignalXMPP` retain that exchange-wide
  critical section while cancellation reaches `THTTPSend.Abort`.
- `Shutdown` calls `FileExists` and `DeleteFile` while retaining the same
  critical section.
- accepted transfer construction currently occurs while the exchange-wide
  critical section is held.
- `Commit` blindly assigns `FCommitted := True`. Cancellation can be recorded
  after the transfer's final cancellation check but before that assignment,
  after which `Execute` discards the earlier cancellation.
- The inbound path mutates the artifact registry and prompt before calling
  `Commit`; the outbound path separately checks cancellation and then commits
  before `SendFileShare`. Neither check/assignment pair is atomic arbitration.
- The outbound callback writes its discovery/slot result before setting
  `FResultEvent`, and the transfer reads the result after waiting. Only one
  discovery or slot callback is outstanding at a time.
- `FCallbackPending` and the repeat/critical-section logic duplicate the
  synchronization already provided by that event.
- The executor's critical section has a distinct, concrete purpose: it protects
  the active `THTTPSend` reference while the transfer thread may clear/free it
  and another thread may call `Abort`.
- `QueueInbound`, `QueueOutbound`, and "transfer queue full" describe an
  execution queue that no longer exists.

## Architecture Problem

The implementation achieved one blocking thread per transfer but retained
coordination structures from the former queued-worker model.

The exchange-wide critical section is being used as subsystem serialization
and as an implicit transfer-lifetime guarantee. A critical section may only
protect one singular block of complex shared memory against concurrent
corruption. It is not a lifecycle, policy, routing, cancellation, or
convenience mechanism. Holding it through unrelated operations blocks other
threads for no memory-safety reason.

Cancellation is also represented by a protected string plus an unrelated
Boolean commitment flag. Those values do not perform one indivisible decision,
so both cancellation and commitment can appear to win.

Introducing a new exchange-owner thread would only replace the bad lock with a
central dispatcher. The existing event sources already have legitimate
execution threads. The correction must instead give each transfer local
ownership and protect only the actual shared collections that remain.

## Target Contract

### Execution model

- One accepted transfer remains one transfer object derived from `TThread`.
- The transfer thread exists solely because Synapse HTTP download/upload is a
  blocking operation and XMPP, providers, and other transfers must continue
  progressing independently.
- No additional thread is introduced for admission, dispatch, callbacks,
  cancellation, reaping, shutdown, or ownership transfer.
- Existing Pascal events continue to invoke BotHost on their originating
  threads. This correction does not marshal all BotHost work to the main
  thread or require a new pump.

### Transfer-local ownership

- A transfer owns its immutable request context, protocol progression,
  callback result storage, temporary files, unfinished result, and completion
  callback until each is explicitly handed off.
- The exchange never advances a transfer and never writes its protocol result.
- The callback result is written once by the XMPP callback, followed by
  `FResultEvent.SetEvent`; the transfer waits once and then reads it.
- Retain the current auto-reset event because the same event is used
  sequentially for discovery and slot completion. A callback that occurs
  before `WaitFor` remains signalled for that wait.
- Remove `FCallbackPending` and the callback-result use of the transfer
  critical section. Do not add another readiness flag, callback lock, or wait
  loop.
- Cancellation while an XMPP request is outstanding still drains that one raw
  callback before the transfer exits; this preserves the existing callback
  receiver lifetime without new callback-validity machinery.
- Transfer cancellation never signals `FResultEvent`. Only the genuine XMPP
  response, IQ timeout, or XMPP cancellation callback writes the callback
  result and signals that event. A cancelled transfer waiting for discovery or
  slot completion remains alive until that registered callback has fired; it
  then observes `cancelled`, ignores the callback result, and exits.

### Atomic cancellation and commitment

- Replace `FCommitted` and string-presence-as-state with exactly
  `FTerminalState: LongInt` and `LongInt` constants for:
  - `active`;
  - `cancelled`; or
  - `committed`.
- Use FPC's `InterlockedCompareExchange(var Target: LongInt; NewValue:
  LongInt; Comperand: LongInt): LongInt` operation on that exact storage. Do
  not depend on compiler-selected enum sizing or pointer/register width.
- External cancellation enters the cancellation-reason protection and attempts
  exactly one interlocked transition from `active` to `cancelled`.
- If and only if that transition succeeds, cancellation publishes the reason
  before releasing the reason protection. If commitment already won, it does
  not write cancellation metadata.
- The transfer thread attempts exactly one interlocked transition from
  `active` to `committed` at its irreversible handoff boundary.
- Whichever transition succeeds is authoritative. Cancellation after
  commitment cannot undo a submitted provider prompt or XMPP stanza;
  commitment after cancellation fails and the transfer unwinds.
- The cancellation reason is metadata, not the arbitration state. Because it
  is a managed complex string, protect its publication and retrieval with a
  critical section dedicated only to that string.
- A transfer that observes `cancelled` obtains the reason through the same
  protection. If it observes the state after the cancellation CAS but before
  the reason assignment, it waits on that exact protection until publication
  is complete and cannot observe a partially published managed string.
- Do not protect the ordinal terminal state with that critical section; the
  interlocked transition is the decision.

### Stable transfer reference

- Give the transfer object a narrow interlocked retain/release count. Do not
  add a second control object, interface hierarchy, or generalized operation,
  cancellation, future, task, or lifecycle framework.
- The live-transfer collection owns one retained reference to every admitted
  transfer. The accepting call retains its candidate through the return from
  `Start`, and reaping/shutdown take over the collection's reference when they
  extract a transfer.
- Cancellation enumeration retains matching transfer references while the
  live collection is protected, releases that collection protection, and only
  then calls cancellation/HTTP abort and releases those temporary references.
- A concurrent reaper may remove the completed transfer from the collection,
  but it cannot destroy the object, executor, or cancellation state while a
  signalling or startup reference remains outstanding.
- Retain/release governs only object memory lifetime. It does not decide
  cancellation, commitment, protocol progression, completion, or shutdown
  policy.
- A running transfer's collection reference is not released until reaping or
  shutdown has extracted the transfer and `WaitFor` has completed. Temporary
  startup or cancellation references may delay destruction beyond that point.
  The final release may destroy the `TThread` object only after execution has
  been joined/completed, or when construction succeeded but the candidate was
  never admitted and therefore never started.
- The executor's existing critical section remains limited to the concrete
  active-`THTTPSend` publication/clear/abort relationship. Its necessity must
  not be generalized into protection for other transfer state.

### Live-transfer collection

- Give the live `TObjectList` its own critical section. That critical section
  protects only structural access to that collection: add, extract, enumerate,
  and snapshot of retained transfer references.
- Immutable matching data such as room ownership and provider/XMPP dependency
  may be read while locating transfers, but no cancellation, callback, HTTP,
  filesystem, thread start, join, destruction, or completion work occurs while
  the collection is protected.
- Candidate transfer construction occurs before collection admission. A
  constructor exception therefore leaves no live-collection entry, and the
  accepting path retains responsibility for its unadmitted inputs.
- Admission adds an accepted suspended transfer under collection protection,
  releases the protection, and starts that exact transfer immediately.
- FPC 3.2.2 `TThread.Start` is a procedure that delegates to `Resume`; it has
  no Boolean result and exposes no defined startup-failure exception. Do not
  invent a startup-failure state machine around a failure the RTL does not
  report. The recoverable construction boundary is the suspended-thread
  constructor before admission.
- Reaping extracts finished transfer objects under collection protection, then
  joins and frees them after releasing it.
- Shutdown closes admission through a separate interlocked `LongInt` state. It
  extracts retained thread objects under collection protection, then cancels,
  joins, and frees them after releasing it.
- Admission rechecks the closed state as part of the add attempt. An admission
  that wins collection insertion is visible to shutdown; one that loses
  releases its unstarted candidate. The accepting call's retained reference
  keeps a just-admitted object alive through `Start`, even when shutdown has
  already extracted and signalled it. Shutdown waits outside the collection
  protection; after startup the transfer observes cancellation and exits.

### Artifact and staging registry

- Treat the artifact list and the counts describing that list's current and
  reserved capacity as one staging-registry memory block with its own critical
  section.
- That protection covers only short in-memory registry operations:
  reservation, reservation release, artifact insertion, artifact lookup/copy,
  artifact extraction, and maintained byte/file accounting.
- Maintain the registry's used-byte accounting directly rather than repeatedly
  scanning the collection under protection.
- Never acquire the live-transfer collection protection while holding the
  staging-registry protection, or vice versa. Inbound admission reserves
  staging capacity first, releases it, then attempts transfer admission; a
  rejected transfer admission immediately releases its staging reservation.
- Partial files and verified-but-uncommitted attachments remain exclusively
  transfer-owned.
- Prepare the complete inbound handoff before attempting commitment. Only a
  successful `active` to `committed` transition permits artifact registration
  and prompt attachment handoff.
- Artifact shutdown extracts the owned artifact objects under registry
  protection, releases it, and only then performs `FileExists`, `DeleteFile`,
  and destruction.

### Completion and reporting

- Every transfer continues to report exactly once from its own execution path.
- Reservation release is one staging-registry memory operation and occurs
  exactly once on every inbound terminal path.
- Provider prompt submission, outbound completion, activity reporting, and
  `SendFileShare` occur without either collection critical section held.
- After a successful commit, later lifecycle cancellation is ignored because
  ownership has already crossed the documented boundary. A failure returned by
  the handoff operation itself is still reported truthfully.

### Terminology

- Rename `QueueInbound` and `QueueOutbound` to `AcceptInbound` and
  `AcceptOutbound` because acceptance starts a dedicated transfer immediately.
- Replace "transfer queue full" with a transfer-capacity rejection message.
- Do not rename messages about XMPP commands or IQ requests being queued when
  those operations genuinely enter the existing XMPP command queue.
- Update every BotHost call site and registered test directly. Do not keep
  compatibility aliases for the obsolete names.

## Scope

Expected changes:

- `NexusTools/BotHost/src/obNXBotFileExchange.pas`
- `NexusTools/BotHost/src/obNXBotHost.pas`
- `NexusTools/BotHost/tests/tsNXBotFileExchangeTests.pas`
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`

Possible narrow type placement if the terminal enum or retained transfer
contract must be visible outside the implementation section:

- `NexusTools/BotHost/src/tpNXBotFileTypes.pas`

The implementation should prefer keeping private correction details inside
`obNXBotFileExchange.pas`. Any required change outside these files is a plan
conflict to report before widening scope.

## Out Of Scope

- Changing one-thread-per-transfer execution.
- Adding a sole exchange-owner thread, application dispatcher, main-thread
  pump, worker pool, scheduler, task/future abstraction, polling reaper, timer,
  deadline mechanism, or generic cancellation framework.
- Redesigning BotHost's direct Pascal event communication.
- Changing XMPP file-sharing wire formats, HTTP policy, hashing, provider media
  mapping, provider APIs, or supported XEPs.
- Reworking provider, XMPP, BotHost state, or controller threading.
- Replacing Synapse, changing TLS policy, or redesigning
  `TNXBotSynapseFileTransferExecutor` beyond the narrow ownership needed by the
  retained transfer reference.
- Opportunistic cleanup, compatibility wrappers, NexusUI work, live-server
  configuration, or standalone test applications.

## Staged Implementation Plan

### Stage 1: Establish terminal arbitration and retained transfer lifetime

1. Add the private `LongInt` terminal state, fixed `LongInt` state constants,
   and narrow interlocked transfer retain/release count.
2. Make collection, admission/startup, cancellation snapshots, reaping, and
   shutdown hold explicit transfer references for exactly as long as they use
   the object.
3. Implement both terminal transitions with FPC's exact `LongInt`
   `InterlockedCompareExchange` overload and publish a winning cancellation
   reason in the required order.
4. Limit the remaining transfer-local critical section to cancellation-reason
   publication/retrieval and rename it accordingly.
5. Replace every sampled-cancellation-plus-blind-commit sequence with the
   terminal-state contract.

### Stage 2: Simplify outbound callback handoff

1. Remove `FCallbackPending` and callback-result critical-section operations.
2. Prepare result storage, submit one XMPP request, wait once on the existing
   auto-reset event, and consume the completed result.
3. Preserve callback drainage after cancellation and prove both
   callback-before-wait and callback-after-wait behavior.
4. Ensure cancellation never sets the callback result event and only the
   actual registered callback discharges the wait.

### Stage 3: Separate the actual shared memory blocks

1. Replace the exchange-wide critical section with one live-transfer-
   collection protection and one staging-registry protection.
2. Move candidate construction outside both protections.
3. Snapshot retained transfer references under the transfer collection
   protection and perform cancellation/abort afterward.
4. Extract finished threads under collection protection and join/free them
   afterward.
5. Reserve/release staging capacity and register/find/extract artifacts only
   through the staging-registry memory operation.
6. Extract shutdown artifacts before performing filesystem cleanup.
7. Verify that the two collection protections are never nested.

### Stage 4: Correct commitment boundaries and terminology

1. Prepare the complete inbound result locally, win commitment, and only then
   register artifacts and hand attachments to the prompt.
2. Win outbound commitment immediately before `SendFileShare`.
3. Rename the public transfer acceptance methods and stale capacity messages,
   updating all call sites without compatibility shims.
4. Remove the obsolete Boolean, pending flag, broad critical section, repeated
   artifact scan, and supporting code made unnecessary by the correction.

### Stage 5: Integrate and review

1. Compile after each structural stage.
2. Run the registered deterministic BotHost suite, including repeated
   concurrency cases.
3. Review every remaining critical section and document the singular complex
   memory block it protects.
4. Confirm the correction reduces compensating state and code rather than
   replacing it with another lifecycle abstraction.

## Sub-Agent Delegation

No sub-agent use is authorized. Implementation remains local to the primary
Codex process unless the human owner explicitly authorizes sub-agent use in a
later message. Plan approval and implementation approval do not grant
delegation authority.

## Verification Plan

### Focused deterministic tests

- Force cancellation to win immediately before inbound commitment and prove no
  artifact or prompt ownership crosses the boundary.
- Force inbound commitment to win first and prove later cancellation cannot
  reverse the completed handoff.
- Cover the same two orderings immediately before outbound
  `SendFileShare`.
- Publish and retrieve a non-empty managed-string cancellation reason while
  terminal-state contention is forced by barriers rather than timing sleeps.
- Force commitment to win while a cancellation caller is waiting to enter the
  reason protection and prove the losing caller writes no cancellation
  metadata.
- Complete discovery/slot callbacks both before and after the transfer begins
  waiting; prove one wake and one result for each request.
- Cancel while one discovery/slot callback is outstanding and prove the
  cancellation path does not signal the result event and the genuine callback
  is drained before transfer destruction.
- Block one executor's `Abort` deterministically while unrelated artifact
  lookup, staging accounting, and transfer admission continue; this proves no
  collection critical section is retained through abort.
- Race cancellation snapshotting with finished-thread reaping and prove the
  retained transfer remains valid and completion occurs exactly once.
- Exercise concurrent inbound staging reservations at their exact file/byte
  bounds without over-admission or negative release accounting.
- Exercise shutdown against a just-accepted transfer and prove it is cancelled,
  started, joined, and freed without polling, forced termination, or a dangling
  transfer reference.
- Force constructor failure before admission and prove no live-transfer entry
  or retained reference is created. Do not simulate an unsupported
  `TThread.Start` failure contract.
- Retain a transfer temporarily across reaping and prove its final release can
  destroy it only after `WaitFor` has completed.
- Verify artifact files are deleted after registry extraction and without the
  staging-registry protection held.
- Preserve the existing proof that cancelling one transfer does not abort a
  second transfer's executor.
- Update naming assertions to describe admission/capacity rather than a
  transfer queue.

All tests remain registered in `NexusBotHostTestModule`; no standalone harness
or executable is added.

### Builds and suites

From the repository root:

```powershell
lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
fpc -B -MObjFPC -Sh -FUoutput\NexusBotHostTests\fake-units -FEoutput\NexusBotHostTests\bin NexusTools\BotHost\tests\FakeCodexAppServer.lpr
$env:NEXUS_BOTHOST_FAKE_APP_SERVER = (Resolve-Path output\NexusBotHostTests\bin\FakeCodexAppServer.exe)
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost
```

Run the focused concurrency cases repeatedly after the full registered suite.
No live XMPP or HTTP-upload test is required because this correction changes
local ownership and synchronization, not wire behavior.

### Focused source checks

- Confirm `FCommitted`, `FCallbackPending`, `QueueInbound`, `QueueOutbound`,
  and the exchange-wide `FCriticalSection` are absent.
- Confirm no `Abort`, callback invocation, `WaitFor`, `Start`, `Free`,
  `FileExists`, `DeleteFile`, or executor/transfer construction occurs while a
  collection critical section is held.
- Confirm the live-transfer and staging-registry critical sections are never
  nested.
- Confirm only one `TThread` subclass remains responsible for each accepted
  transfer and no new product thread was introduced.
- Confirm no polling or timing sleeps were added for correctness.
- Run `git diff --check` and review the complete diff for ownership, critical-
  section boundaries, naming, and unrelated changes.

After approved implementation and successful verification, create the normal
architecture checkpoint with `scripts\New-NexusSourceArchive.ps1`.

## Risks And Questions

- Transfer retain/release must remain a private file-transfer lifetime
  mechanism. Expanding it into a general operation/lifecycle abstraction would
  violate this plan.
- The cancellation reason is managed memory and must not be treated as though
  terminal-state CAS also publishes it safely. Its dedicated publication rule
  is required.
- Callback drainage remains required because the existing XMPP IQ completion
  API retains raw method callbacks and exposes no per-request cancellation
  handle.
- Shutdown may observe a transfer after collection admission but before its
  immediate `Start`. It must wait outside the collection protection; the
  accepting call remains responsible for starting the accepted thread.
- FPC 3.2.2 provides no result or defined exception contract from
  `TThread.Start`. Construction failure is handled before admission; no
  speculative startup-failure lifecycle machinery is permitted.
- No unresolved product choice blocks implementation. If the narrow retained
  transfer reference cannot provide stable cancellation/startup without
  broader lifecycle machinery, stop and return the concrete conflict rather
  than improvising another framework.

## Approval Gate

This plan authorizes no implementation. No source edit, build, test execution,
program launch, archive creation, or implementation work begins until the
human owner explicitly authorizes it. A later implementation approval still
does not authorize sub-agent use.
