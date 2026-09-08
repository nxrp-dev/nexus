# Work Plan: NexusBot File Operation Ownership Correction

## Inputs

- Source request: the human owner's conversation directive to remove the
  compensating file-transfer lifecycle model before correcting individual
  race symptoms.
- Related discussion/review notes: use
  `TNXOpenAIProvider.CompleteActive` as the local ownership model; keep one
  owner from file-operation acceptance through terminal completion; tell that
  owner which provider, XMPP, room, or prompt scope became invalid instead of
  globally invalidating unrelated work.
- Existing constraints: architecture changes require explicit ownership;
  critical sections protect only small memory-state transitions; no new
  deadline, polling, cancellation, task, or thread subsystem; no standalone
  test harness; no sub-agent use is authorized.

## Summary

Replace the host-wide generation/block mechanism and the exchange's
independent cancellation state machine with one file-operation ownership
model. `TNXBotFileExchange` will retain every accepted inbound or outbound
file operation until one terminal completion method removes it, determines
whether its owning scope is still valid, releases its resources, and returns
exactly one result.

The host will remain the source of lifecycle facts, but it will report only
the scope that actually became unavailable. The exchange will match that fact
against the operations it owns. Loss of one room will not invalidate direct
messages, another room's transfers, or otherwise unrelated file work.

## Verified Findings

- `TNXOpenAIProvider` already demonstrates the intended local model:
  `TakePrompt` installs one active prompt, cancellation marks that retained
  prompt, and `CompleteActive` verifies/removes that exact prompt in one short
  protected operation before result reporting continues outside the critical
  section.
- `TNXBotHost` currently owns `FFileOperationGeneration` and
  `FFileOperationsBlocked`. `CancelFileOperations` increments the generation,
  blocks new work, and calls `TNXBotFileExchange.CancelAll`.
- `TNXBotOutboundFileOperation` is currently created by the host, retains a
  snapshot of the host generation, checks `Valid` after discovery, slot, and
  upload callbacks, and frees itself in `Finish`.
- A single outbound operation is therefore split across the self-owned host
  callback object and a separately owned exchange upload operation.
- `TNXBotFileExchange` separately retains `FQueue`, `FActiveOperation`,
  per-operation `Cancelled`/`CancelReason` fields, `CancelAll`, `CancelRoom`,
  `OperationCancelled`, and a resettable executor abort state.
- `ThreadExecute` repeatedly checks cancellation before and after blocking
  transfer work, then independently clears active state, releases accounting,
  invokes completion callbacks, and frees the operation.
- `LeaveRoom`, failed/left room state, provider stop, explicit disconnect,
  failed/disconnected XMPP state, and shutdown currently overlap in how they
  mutate generation state, cancel exchange work, and cancel provider prompts.
- The existing exchange thread isolates blocking HTTP transfer from the host
  and provider/XMPP activity. No additional product thread is justified by
  this correction.

## Architecture Problem

The code has more than one answer to "who owns this file operation now?"

For outbound work, the host-side object owns discovery and slot callbacks,
the exchange owns the HTTP upload, and the host generation decides whether a
late callback remains acceptable. For both inbound and outbound work, the
exchange also carries a parallel cancellation state that is sampled at
multiple points. This makes correctness depend on compensating observations
across several objects rather than on one owner's terminal handoff.

The global generation makes the scope error visible: incrementing it for one
room invalidates every outbound operation created under the previous value,
regardless of its room or direct-message destination. The block flag then adds
a second, host-wide policy state that must be reset by later provider/XMPP
actions.

The correction is not to add more checks around those transitions. It is to
make the operation's retained owner authoritative and give that owner one
place to accept cancellation or completion.

## Target Contract

### Owner

- `TNXBotFileExchange` is the sole container owner of every accepted inbound
  and outbound file operation.
- An operation object owns its prompt or attachment, routing/reply context,
  XMPP discovery and slot state, transfer reservation, staged artifacts, and
  terminal completion callback for its entire lifetime.
- The exchange retains an operation while it is waiting for XMPP negotiation,
  queued for blocking transfer, or active in the transfer worker. No operation
  frees itself from a callback.
- The host does not retain a parallel generation, blocked state, or lifecycle
  record for file work.

### Responsibilities

- The host identifies the actual lifecycle fact: provider unavailable, XMPP
  unavailable, one room unavailable, one prompt/request owner withdrawn, or
  host shutdown.
- The exchange matches that fact only to operations whose explicit context
  depends on that owner. It does not translate a room loss into global file
  invalidation.
- XMPP discovery and slot callbacks return progress to the exchange-owned
  operation. They do not determine lifetime and do not free the operation.
- The existing worker performs only the blocking HTTP portion for the active
  operation. It does not own routing policy or terminal result policy.
- One exchange completion method performs the `CompleteActive`-style terminal
  transition: verify the exact retained operation, capture its final result or
  cancellation reason, remove it from the applicable pending/queued/active
  state, update capacity/reservation accounting, and prevent any second
  completion.
- Callback invocation, provider submission, journal reporting, file deletion,
  and object destruction occur after the small protected ownership transition,
  never while the exchange critical section is held.

### State Flow

1. The host validates and offers an inbound prompt or outbound send request to
   the exchange.
2. The exchange either rejects it without taking ownership or accepts and
   retains one operation object. On acceptance, all prompt/attachment and
   completion ownership transfers with it.
3. An outbound operation advances through discovery and slot negotiation while
   remaining retained by the exchange. An inbound operation can proceed
   directly to the transfer queue.
4. The exchange queues the operation's blocking HTTP work and installs that
   exact operation as active when the worker takes it.
5. A lifecycle notification marks only matching retained operations as no
   longer completable for their original purpose. Queued matching work can be
   removed immediately. If the matching active HTTP call must be interrupted,
   cancellation targets that one active call; ownership remains with the
   exchange until the worker returns.
6. Success, transfer failure, negotiation failure, owner invalidation, and
   shutdown all converge through the same terminal method.
7. The terminal method yields one detached result package for processing
   outside the critical section, then the operation and any rollback artifacts
   are released exactly once.

### Scope Matching

- Provider loss invalidates file work whose eventual completion requires that
  provider; it does not stand in for XMPP or room loss.
- XMPP loss invalidates pending outbound discovery, slot, upload, and send work
  because their delivery owner is unavailable. It does not independently
  corrupt exchange accounting or artifact registry state.
- Room loss invalidates only operations explicitly addressed to that room.
  Direct-message operations and operations for other rooms remain valid.
- Prompt/request withdrawal invalidates only file work owned by that exact
  prompt/request identity.
- Host shutdown stops acceptance and terminally drains all retained operations
  through the same ownership path before exchange destruction.
- Scope representation remains narrow and explicit to BotHost file operations;
  this work must not introduce a generic owner-token, cancellation, or
  lifecycle framework.

### Threading And Synchronization

- Retain the one existing exchange worker solely because Synapse HTTP transfer
  is blocking and the host, XMPP, and provider must continue progressing.
- Add no thread, timer, poller, worker pool, future, or task abstraction.
- Use the exchange critical section only to move operation references between
  retained states, record invalidation on the exact retained operation, and
  update bounded accounting in the same small autonomous transition.
- Do not hold the critical section across DNS, XMPP, HTTP, filesystem work,
  callbacks, provider submission, journaling, or object destruction.
- Do not preserve a resettable exchange-global abort/cancel state. If exact
  interruption of the active Synapse call cannot be expressed without a new
  cross-thread lifecycle mechanism, stop implementation and return that
  concrete constraint to the human owner before designing around it.

## Scope

Expected primary changes:

- `NexusTools/BotHost/src/obNXBotFileExchange.pas`
- `NexusTools/BotHost/src/obNXBotHost.pas`
- `NexusTools/BotHost/tests/tsNXBotFileExchangeTests.pas`
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`

Possible narrow call-site changes, only if required by the ownership handoff:

- `NexusTools/BotHost/src/obNXBotProvider.pas`
- `NexusTools/BotHost/src/obNXCodexAppServer.pas`
- `NexusTools/BotHost/src/obNXOpenAIProvider.pas`
- `NexusTools/BotHost/src/tpNXBotFileTypes.pas`

## Out Of Scope

- Reworking Synapse stream semantics, the current file-read wrapper, DNS
  pinning, TLS policy, HTTP fixtures, URL policy, or protocol limits merely
  because those changes are present in the same uncommitted feature tree.
- Changing XEP-0363, XEP-0446, XEP-0447, SFS/OOB parsing, disco, slot, upload,
  hash, staging, provider media mapping, or reply/origin wire contracts.
- Adding features to file exchange or fixing unrelated static-review findings.
- Redesigning provider prompt ownership, XMPP module ownership, or BotHost
  shutdown beyond the calls required to report invalid file-operation owners.
- Adding generalized cancellation tokens, lifecycle managers, schedulers,
  task/future abstractions, new product threads, or standalone test programs.
- Opportunistic cleanup of the broader uncommitted file-exchange feature.

## Staged Implementation Plan

### Stage 1: Establish one retained operation contract

1. Define the minimal inbound/outbound operation context inside
   `obNXBotFileExchange.pas`, including the exact provider, XMPP, room, and
   prompt/request dependencies needed for matching lifecycle facts.
2. Give the exchange one retained operation collection/state model covering
   XMPP negotiation, queued transfer, and active transfer.
3. Add one terminal method modeled on `CompleteActive` that removes the exact
   operation and updates accounting once, returning detached completion work
   for execution outside the critical section.
4. Preserve current capacity, byte reservation, artifact rollback, and
   exactly-once caller completion behavior through that terminal method.

### Stage 2: Move outbound ownership into the exchange

1. Move the current discovery/slot/upload progression out of the host-owned,
   self-freeing `TNXBotOutboundFileOperation` path and into an
   exchange-retained outbound operation.
2. Have the host perform only initial validation/artifact lookup and transfer
   the complete request to the exchange on acceptance.
3. Route discovery, slot, upload, and final XMPP-send results back to the same
   retained operation; no phase creates an independent lifecycle record.
4. Remove callback-local generation checks and self-destruction.

### Stage 3: Replace global invalidation with exact owner invalidation

1. Remove `FFileOperationGeneration`, `FFileOperationsBlocked`,
   `CancelFileOperations`, and every increment/reset/check of those fields.
2. Replace host lifecycle call sites with narrow notifications describing the
   owner or delivery scope that actually became unavailable.
3. Make provider stop, XMPP disconnect/failure, one-room leave/failure, and
   shutdown affect only operations that declare that dependency.
4. Remove `TNXBotFileOperation.Cancelled`, repeated
   `OperationCancelled` sampling, `CancelAll`/`CancelRoom` as independent
   completion paths, and exchange-global resettable abort state.
5. Preserve physical interruption only for the exact active blocking transfer
   when required, without transferring lifetime or completion ownership away
   from the exchange.

### Stage 4: Converge completion and shutdown

1. Route negotiation error, transfer success/failure, invalidation, queue
   rejection after acceptance, and shutdown through the one terminal method.
2. Ensure inbound rollback, reservation release, outbound callback delivery,
   provider submission, and journal reporting each occur once after ownership
   has been detached.
3. Stop accepting during shutdown, terminally remove queued/pending work,
   interrupt only the exact active blocking transfer if necessary, wake and
   join the existing worker, then release the exchange.
4. Remove obsolete methods, fields, and tests that exist only to support the
   compensating lifecycle model.

### Stage 5: Verify the ownership contract

1. Replace broad cancellation tests with focused owner-invalidation tests.
2. Prove unrelated-room and direct-message operations survive a room loss.
3. Prove queued, negotiating, and active matching operations each complete
   once with the correct reason and never submit or send afterward.
4. Prove late discovery, slot, HTTP, and XMPP callbacks cannot complete an
   already terminal operation a second time.
5. Prove shutdown drains ownership and accounting without a second lifecycle
   subsystem.

## Sub-Agent Delegation

No sub-agent use is authorized. Implementation remains local to the primary
Codex process unless the human owner explicitly requests sub-agent use in a
later message. Plan approval and implementation approval do not authorize
delegation.

## Verification Plan

### Focused source checks

- Confirm `FFileOperationGeneration`, `FFileOperationsBlocked`,
  `CancelFileOperations`, `TNXBotOutboundFileOperation.Valid`, repeated
  `OperationCancelled`, and the exchange-global resettable abort state are
  absent.
- Confirm there is one exchange-owned terminal transition for accepted file
  operations and no callback frees an operation directly.
- Confirm room invalidation matches the room identity and cannot invalidate
  direct-message or other-room operations.
- Confirm critical sections contain only retained-reference, invalidation, and
  accounting transitions and contain no I/O, callbacks, logging, or frees.
- Confirm no new thread, timer, poller, task/future, generic cancellation
  framework, or standalone test executable was introduced.

### Deterministic build and tests

From the repository root:

```powershell
lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
fpc -B -MObjFPC -Sh -FUoutput\NexusBotHostTests\fake-units -FEoutput\NexusBotHostTests\bin NexusTools\BotHost\tests\FakeCodexAppServer.lpr
$env:NEXUS_BOTHOST_FAKE_APP_SERVER = (Resolve-Path output\NexusBotHostTests\bin\FakeCodexAppServer.exe)
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost
```

Focused registered tests must cover:

- acceptance transfers ownership and rejection does not;
- successful inbound and outbound completion occurs once;
- negotiation, transfer, and final-send failure occurs once;
- invalidating room A does not affect room B or direct-message work;
- provider invalidation affects only provider-dependent work;
- XMPP invalidation affects only XMPP-dependent outbound work;
- exact prompt/request invalidation affects only that operation;
- queued, negotiating, and active matching operations do not publish, submit,
  or send after terminal invalidation;
- late callbacks are ignored by retained identity rather than generation;
- capacity and byte/file reservations return to their initial values after
  every terminal path;
- shutdown stops acceptance, drains retained work, and joins the existing
  blocking-I/O worker.

### Final checks

- Run `git diff --check`.
- Review only the lifecycle/ownership diff separately from the broader
  uncommitted file-exchange feature.
- After approved implementation and successful verification, create the
  required architecture archive checkpoint with
  `scripts\New-NexusSourceArchive.ps1`.

## Risks And Questions

- The current XMPP discovery and slot APIs are callback-based. The exchange
  must retain the operation across those callbacks without moving policy into
  the XMPP module. If either API requires callback ownership that contradicts
  this contract, report the concrete conflict before changing that module.
- An active Synapse HTTP call may need a physical interruption for prompt
  withdrawal or shutdown. This plan authorizes targeting the one active call;
  it does not authorize an exchange-global resettable cancellation model. If
  the current executor boundary cannot do that simply, implementation stops
  for human design review.
- The broader file-exchange worktree contains separate HTTP-boundary changes
  and tests. They must not be silently accepted, reverted, or redesigned as
  part of this lifecycle correction.
- No unresolved product decision blocks implementation. A newly discovered
  need for broader ownership infrastructure or another thread is a plan
  conflict, not implied permission to add it.

## Approval Gate

This plan authorizes no implementation. No source edit, build, test execution,
program launch, archive creation, or other implementation work begins until
the human owner explicitly authorizes this plan. A later implementation
approval still does not authorize sub-agent use.
