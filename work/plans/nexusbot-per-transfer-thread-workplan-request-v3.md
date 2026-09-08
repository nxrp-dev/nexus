# Work Plan: NexusBot Deterministic Thread-Per-Transfer File Exchange

## Inputs

- Source request:
  `C:\Users\kcollins\Downloads\nexusbot-per-transfer-thread-workplan-request-v3.md`
- Related discussion: one accepted transfer is one transfer object/thread with
  one deterministic lifetime; use `TThread.Yield` rather than platform-specific
  `Sleep(0)` when an explicit cooperative yield is useful.
- Superseded plan:
  `work/plans/nexusbot-file-operation-ownership-correction.md`. That plan's
  shared exchange-operation model is not the implementation direction.
- Existing constraints: no generalized scheduler, worker pool, task/future,
  cancellation, callback-validity, or lifecycle framework; no standalone test
  harness; no sub-agent use is authorized.

## Summary

Replace the centralized file-transfer worker and its queue/active/cancellation
machinery with a direct model:

> One accepted transfer is one transfer object derived from `TThread`.

That object owns its inbound or outbound context, its own transfer executor,
its own cancellation signal, every sequential transfer phase, its terminal
result, and its cleanup. It starts once, performs one transfer, reports once,
and exits.

`TNXBotFileExchange` remains only as the shared boundary for admission limits,
artifact registration, locating matching live transfers for cancellation, and
joining transfer threads during shutdown. It does not advance transfers or
decide their results.

## Verified Findings

- `TNXBotFileExchange` currently constructs one
  `TNXBotFileExchangeThread`, owns `FQueue` and `FActiveOperation`, and moves
  every inbound download and outbound upload through that single worker.
- `TNXBotFileOperation` currently carries shared-worker cancellation state;
  `OperationCancelled` samples it repeatedly before and after I/O.
- The exchange owns one `TNXBotFileTransferExecutor`. Its `Abort`,
  `ResetAbort`, `FAbortRequested`, and `FHTTP` therefore apply to whichever
  operation currently occupies the shared worker.
- `TNXBotHost` separately owns `FFileOperationGeneration`,
  `FFileOperationsBlocked`, and `CancelFileOperations`.
- Outbound discovery and slot negotiation currently belong to the
  host-created, self-freeing `TNXBotOutboundFileOperation`; only the upload
  phase is transferred into the exchange worker.
- `TNXXMPPFileSharingModule.DiscoverUploadService` and
  `RequestUploadSlot` submit commands through the thread-safe XMPP command
  queue, then complete through method callbacks on the XMPP connection thread.
- Those callbacks are raw `of object` method pointers. The current IQ API
  returns only acceptance, exposes no per-request cancellation handle, and
  completes pending requests by response, timeout, or XMPP-wide cancellation.
- `TNXXMPPFileSharingModule.SendFileShare` is a non-blocking command
  submission. Its current success contract means the final message was queued
  for XMPP delivery.
- OpenAI and Codex provider prompt submission already enters protected provider
  command queues. The existing file worker already calls the host's prompt
  completion path from a non-host thread.
- `TNXBotHostState` protects journal/state mutation with its own critical
  section and invokes activity notification after releasing it.
- The existing configuration requires positive limits and defaults
  `FileTransferCapacity` to 8, `FileMaximumBytes` to 16 MiB,
  `StagedFileCapacity` to 32, and `StagedMaximumBytes` to 64 MiB.
- The existing file-exchange thread is justified only by blocking HTTP I/O.
  Under the target model, that justification belongs independently to each
  admitted transfer thread.

## Architecture Problem

The centralized worker makes unrelated transfers share progression and
cancellation state. Outbound work is additionally split between a self-owned
host callback object and an exchange-owned upload record. Generation checks,
blocked state, cancel flags, active-operation tracking, and executor reset logic
then compensate for that divided ownership.

The target model removes the source of the problem. A transfer does not move
between owners or through a shared active slot. Its thread is the transfer and
remains its sole progression and terminal-result authority.

## Target Contract

### Transfer object/thread

- Add one transfer-thread base containing only common immutable context,
  transfer-local cancellation, terminal reporting support, and the executor it
  exclusively owns.
- Add narrow inbound and outbound transfer-thread implementations for their
  different sequential protocols.
- `FreeOnTerminate` remains `False`. The exchange owns every accepted thread
  object until it has exited and the exchange safely reaps it.
- The transfer thread does not free itself and no callback frees it.
- Each transfer constructs its own Synapse executor. Cancelling transfer A can
  therefore address only A's HTTP object/socket and cannot affect transfer B.

### Exchange

- The exchange owns a small protected collection of admitted transfer threads.
- Before accepting work, it removes and frees previously finished thread
  objects, checks the existing simultaneous-transfer and staged capacity
  limits, and reserves the required counts/bytes.
- On acceptance, it registers the new suspended transfer thread before starting
  it. On rejection, ownership of the offered prompt/attachment remains with
  the caller.
- The collection exists only to enforce limits, locate matching live transfers,
  retain thread objects until safe destruction, and join them during shutdown.
- The exchange never records queued/active transfer phases and never decides
  whether a transfer succeeded, failed, or was cancelled.
- A completed thread may remain retained until the next exchange entry or
  shutdown. This is bounded by `FileTransferCapacity`; no reaper thread or
  polling mechanism is added.

### Inbound sequence

One inbound transfer thread performs:

1. source and declared-size validation;
2. DNS, destination, and URL validation;
3. blocking HTTP download into transfer-owned partial files;
4. actual size and hash verification;
5. final staging of every attachment into a transfer-local completed set;
6. one ownership handoff of the completely verified set to the artifact
   registry and neutral prompt;
7. provider prompt submission or one failure report;
8. rollback of anything still owned by the transfer;
9. reservation release, terminal reporting, and thread exit.

Provider-specific media mapping remains in the provider. The transfer produces
only neutral `TNXBotAttachment` objects and submits the neutral prompt.

### Outbound sequence

One outbound transfer thread performs:

1. request validation and artifact resolution;
2. upload-service discovery;
3. upload-slot negotiation;
4. blocking HTTP upload through its own executor;
5. final SFS/OOB message construction/submission;
6. one success or failure callback;
7. cleanup and thread exit.

The host no longer creates `TNXBotOutboundFileOperation`. Discovery, slot,
upload, and final send remain phases of the same transfer thread.

### Callback-based XMPP phases

- The outbound transfer submits the existing discovery or slot request and
  waits on transfer-local result/wake state.
- The XMPP callback copies its result into that transfer's context and wakes
  that transfer only. The transfer thread then resumes its sequential method.
- Because the existing IQ API has no per-request cancellation handle, a
  cancellation that wakes a discovery/slot wait does not destroy the transfer
  while its raw callback remains registered. The transfer records its local
  cancellation result and drains that one outstanding callback through its
  normal response, timeout, or XMPP cancellation before exiting.
- XMPP disconnect already cancels all request-manager entries and invokes their
  terminal callbacks. No new callback registry or XMPP-wide lifecycle layer is
  introduced.
- Only one discovery or slot callback is outstanding for a transfer at a time.
  The transfer object therefore remains a valid callback receiver until that
  callback has returned.

### Cancellation and commitment

- Each transfer owns one transfer-local cancellation signal and reason.
- Room, provider, XMPP, prompt/request, and shutdown events ask the exchange to
  enumerate its live threads and signal only matching transfer contexts.
- Signaling never reports or frees the transfer from the signaling thread.
  The transfer thread observes its own signal and produces its own result.
- Room ownership and delivery target are separate fields. Room loss matches the
  explicit bare room owner, including occupant-targeted private replies, and
  does not affect unrelated direct messages or other rooms.
- Rejected lifecycle commands do not signal transfers. `StopProvider` and
  `LeaveRoom` signal dependent transfers only after their existing APIs accept
  the command; authoritative provider/XMPP/room failure-state events also
  signal the applicable transfers.
- Inbound commitment occurs immediately before the fully verified neutral
  attachment set and prompt are handed to the provider path.
- Outbound commitment occurs immediately before the final
  `SendFileShare` command submission after upload succeeds.
- The transfer thread performs the final cancellation observation at that
  boundary. Once it crosses the boundary, later cancellation cannot undo the
  already-committed provider submission or XMPP command.
- Cancellation of active HTTP calls invokes only that transfer's executor
  abort. Forced thread termination is forbidden.

### Artifact ownership

- Partial downloads and verified-but-uncommitted attachments belong only to
  their transfer thread.
- Failure or cancellation before commitment deletes those files and objects.
- The current per-attachment early registry insertion is replaced by a single
  handoff after every attachment in the inbound operation is verified.
- At commitment, the registry and prompt take their intended durable/consumer
  ownership exactly once. The transfer clears its local ownership and cannot
  subsequently delete those artifacts.
- Reservations are released exactly once by the transfer thread on every exit
  path. Shared counters are adjusted in one short exchange operation; they do
  not control transfer progression.

### Thread completion and shutdown

- The transfer thread performs its reporting and cleanup, records that its
  execution is ending, and returns from `Execute`.
- The exchange retains the non-free-on-terminate thread object. A normal later
  exchange entry reaps finished threads by extracting them under the collection
  lock, then calling `WaitFor` and `Free` outside the lock.
- Shutdown first stops admission, snapshots and signals all retained transfers,
  interrupts each transfer's own blocking I/O where necessary, and releases the
  collection lock.
- Shutdown joins every transfer thread before the host destroys the exchange,
  provider, XMPP client/modules, callbacks, or artifact registry.
- Thread joining, callbacks, provider submission, XMPP calls, filesystem work,
  and object destruction never occur while the exchange collection lock is
  held.

### Cooperative yielding

- Blocking network waits already yield execution naturally.
- After a meaningful non-blocking chunk, a transfer may call
  `TThread.Yield` where giving another ready transfer an immediate scheduling
  opportunity is useful.
- Do not use platform-specific `Sleep(0)`/`sched_yield`, scatter yields through
  tiny operations, or use yielding for correctness, timing, polling, or
  synchronization.

## Scope

Expected primary changes:

- `NexusTools/BotHost/src/obNXBotFileExchange.pas`
- `NexusTools/BotHost/src/obNXBotHost.pas`
- `NexusTools/BotHost/tests/tsNXBotFileExchangeTests.pas`
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`

Possible narrow changes required by the verified call paths:

- `NexusTools/BotHost/src/tpNXBotFileTypes.pas`
- `NexusTools/BotHost/src/obNXBotProvider.pas`
- `NexusTools/BotHost/src/obNXCodexAppServer.pas`
- `NexusTools/BotHost/src/obNXOpenAIProvider.pas`
- `NexusLib/net/src/xmpp/obNXXMPPFileSharing.pas`
- existing registered NexusXMPP tests if the file-sharing callback contract
  requires a narrow correction.

## Out Of Scope

- DNS/private-address, TLS, HTTP, redirect, URL, hash, staging-limit, or
  protocol behavior unrelated to transfer ownership.
- XEP-0363, XEP-0446, XEP-0447, SFS/OOB, disco, slot, media-mapping, reply, or
  origin contract changes.
- Provider or XMPP architecture redesign.
- A worker pool, scheduler, task/future framework, dispatcher, callback-validity
  registry, generic cancellation/lifecycle framework, or additional support
  thread.
- A new admission subsystem or speculative scaling work beyond preserving the
  existing configured limits.
- NexusUI work, standalone test harnesses, and unrelated cleanup in the current
  uncommitted feature tree.

## Staged Implementation Plan

### Stage 1: Replace the worker abstraction

1. Reshape the exchange operation types into one transfer-thread base plus
   inbound and outbound transfer-thread implementations.
2. Move executor construction into each transfer so HTTP state and interruption
   are physically transfer-local.
3. Replace `FQueue`, `FActiveOperation`, `FWake`, and `FWorker` with the minimal
   protected collection of admitted thread objects.
4. Preserve `FileTransferCapacity` and staged file/byte reservations at the
   acceptance boundary; register each accepted suspended thread before `Start`.
5. Add finished-thread reaping without `FreeOnTerminate`, a reaper thread, or
   polling.

### Stage 2: Make inbound transfer sequential

1. Move source selection, validation, download, verification, and staging into
   the inbound transfer thread's `Execute` flow.
2. Keep downloaded artifacts transfer-owned until all attachments succeed.
3. Commit the completed attachment set and neutral prompt once immediately
   before provider submission.
4. Make failure/cancellation rollback and reservation release local to the
   transfer's single `try/finally` lifetime.
5. Remove queue/active cancellation tests and replace them with independent
   inbound transfer tests.

### Stage 3: Make outbound transfer sequential

1. Remove the host-owned/self-freeing `TNXBotOutboundFileOperation`.
2. Give the outbound transfer thread the resolved artifact, provider/XMPP/room
   dependencies, delivery/reply context, and completion callback at acceptance.
3. Submit discovery and slot commands, wait for each result locally, perform
   upload with the transfer-owned executor, then submit the final share.
4. Keep the raw callback target alive until each one outstanding IQ callback
   returns; on cancellation, wake the transfer and drain that callback before
   thread exit.
5. Commit immediately before final `SendFileShare`; report exactly one result.

### Stage 4: Remove compensating lifecycle machinery

1. Remove exchange `FQueue`, `FActiveOperation`, `OperationCancelled`, the
   shared worker, and queue-to-active progression.
2. Remove shared-executor `Abort`/`ResetAbort` state and give those mechanics to
   each transfer-owned executor.
3. Remove host `FFileOperationGeneration`, `FFileOperationsBlocked`,
   `CancelFileOperations`, generation snapshots, and `Valid` checks.
4. Replace global cancellation with narrow exchange enumeration that only
   signals matching transfer threads.
5. Move provider-stop and room-leave signaling after successful command
   acceptance. Preserve authoritative state-event signaling for actual failure
   or loss.

### Stage 5: Make shutdown deterministic

1. Stop admission under the exchange collection lock.
2. Snapshot and signal all retained transfers, then release the lock.
3. Let each thread interrupt its own I/O, drain any outstanding XMPP callback,
   report/clean up once, and exit.
4. Join and free all thread objects outside the lock.
5. Only then allow host teardown to destroy provider, XMPP, exchange, callback,
   and artifact owners.

### Stage 6: Integrate and verify

1. Update registered tests around simultaneous independent transfers,
   transfer-local cancellation, local commitment, callback drainage, artifact
   handoff, and shutdown joining.
2. Retain the existing real HTTPS boundary tests without creating an executable
   harness.
3. Remove tests whose assertions exist only for the shared queue/active worker.
4. Run the focused source checks, clean builds, and complete registered suites.

## Sub-Agent Delegation

No sub-agent use is authorized. Implementation remains local to the primary
Codex process unless the human owner explicitly requests sub-agent use in a
later message. Plan approval and implementation approval do not authorize
delegation.

## Verification Plan

### Focused source checks

- Confirm the file exchange contains no single shared worker, `FQueue`,
  `FActiveOperation`, queue-to-active transition, repeated
  `OperationCancelled`, or shared executor abort/reset state.
- Confirm the host contains no file-operation generation, blocked flag,
  generation snapshot, `Valid`, or self-freeing outbound operation.
- Confirm every accepted transfer has exactly one thread object and exactly one
  executor instance.
- Confirm the exchange's shared lock protects only admission/reservations,
  artifact registry, live-thread lookup, and safe thread-object retention.
- Confirm no I/O, callback, event reporting, `WaitFor`, or object destruction
  occurs while that lock is held.
- Confirm no transfer thread is force-terminated or marked `FreeOnTerminate`.
- Confirm no new pool, scheduler, dispatcher, polling loop, generic
  cancellation/lifecycle abstraction, or standalone test executable exists.
- Confirm any explicit cooperative yield is `TThread.Yield` and is not used for
  correctness.

### Deterministic tests

Registered tests must prove:

- two or more transfers enter and progress through independent blocking I/O;
- cancelling transfer A interrupts only A's executor and does not change B;
- room A cancellation leaves room B and unrelated direct-message transfers
  untouched;
- an occupant-targeted private transfer with room A ownership is cancelled with
  room A;
- rejected provider-stop and room-leave commands do not signal transfers;
- provider/XMPP loss signals only transfers declaring that dependency;
- inbound success, failure, cancellation, rollback, and reservation release
  each report once;
- outbound final share submission occurs at most once;
- cancellation before the transfer-local commitment point wins;
- cancellation after commitment does not undo provider/XMPP submission;
- a callback arriving after cancellation still finds its transfer alive,
  cannot resume transfer work, and is drained before destruction;
- temporary files are deleted before handoff on failure, while committed
  registry/prompt artifacts are never deleted by the transfer;
- admission never exceeds the configured transfer/file/byte limits;
- shutdown prevents new admission, signals and joins every thread, and destroys
  no dependency while a transfer can still reference it;
- completed thread objects are joined and freed once;
- existing HTTPS/security/protocol behavior remains covered.

### Build and test commands

From the repository root:

```powershell
fpc -B -FuNexusLib\net\src\xmpp -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetXMPPTests\units -FEoutput\NexusNetXMPPTests\bin NexusLib\net\tests\NexusNetXMPPTests.lpr
$env:Path = 'C:\Program Files\Git\mingw64\bin;' + $env:Path
output\NexusNetXMPPTests\bin\NexusNetXMPPTests.exe

lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
fpc -B -MObjFPC -Sh -FUoutput\NexusBotHostTests\fake-units -FEoutput\NexusBotHostTests\bin NexusTools\BotHost\tests\FakeCodexAppServer.lpr
$env:NEXUS_BOTHOST_FAKE_APP_SERVER = (Resolve-Path output\NexusBotHostTests\bin\FakeCodexAppServer.exe)
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost
```

### Final checks

- Run `git diff --check`.
- Review the lifecycle/threading diff separately from unrelated changes already
  present in the file-exchange feature tree.
- After approved implementation and successful verification, create the normal
  architecture archive checkpoint with
  `scripts\New-NexusSourceArchive.ps1`.

## Risks And Questions

- Verified constraint: XMPP discovery and slot completion currently use raw
  method callbacks and expose no individual request-cancellation handle. The
  selected narrow behavior is to keep the transfer alive and drain its one
  outstanding callback by response, timeout, or XMPP cancellation. Do not add
  broader callback infrastructure. If implementation disproves that this can be
  done locally, stop and report the exact call path.
- A finished non-free-on-terminate transfer may remain retained until another
  exchange entry or shutdown reaps it. Existing transfer capacity bounds that
  retention and the next admission reaps before applying the capacity limit.
- No unresolved product decision blocks implementation. Any discovered need
  for centralized progression, another support thread, a generic scheduler, or
  a global cancellation system contradicts this plan and must be returned for
  human review.

## Approval Gate

This plan authorizes no implementation. No source edit, build, test execution,
program launch, archive creation, or other implementation work begins until
the human owner explicitly authorizes this plan. A later implementation
approval still does not authorize sub-agent use.
