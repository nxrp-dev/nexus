# Work Plan: NexusBot Shutdown Ownership

## Inputs

- Source request: the human owner's request to correct the two remaining
  `Sleep(1)` shutdown loops after determining why the controller and XMPP
  bot-control module wait during destruction.
- Related discussion: shutdown must be derived from object and thread
  ownership. A component must stop the producers it owns while their callback
  targets remain alive, then dispose of retained work; it must not poll memory
  waiting for an assumed owner to disappear.
- Existing constraints: retain direct Pascal event callbacks, narrow
  critical-section memory guards, exactly-once control completion, and the
  current BotHost/XMPP protocol behavior. Do not introduce a timer, polling
  service, application pump, event bus, task framework, or replacement wait
  loop.

## Summary

Correct shutdown ordering so the controller first closes admission and
synchronously quiesces every active host's XMPP and App Server producers while
the controller, pending records, and transport correlations remain alive.
After all producer threads have stopped, the controller can cancel and release
the remaining pending operations and then destroy its hosts without a `Busy`
poll.

Remove the bot-control module destructor's incoming-count poll. The owning
`TNXXMPPClient` joins its connection thread before freeing modules, and the
BotHost/controller shutdown sequence will eliminate external completion
producers before module destruction. At that boundary, a retained incoming
correlation is an invariant violation, not work that a surviving thread can
eventually clear.

## Verified Findings

- `ClaimNextPending` marks a pending operation `Busy`, copies its active host,
  operation, phase, and token, and releases the controller critical section.
  `ProcessClaim` then reads host state and may invoke a host lifecycle method
  before `ReleaseClaim` relinquishes or completes the claim.
- `HostChanged` calls `AdvancePending` directly on the thread delivering the
  host event. Controller processing can therefore be active on an XMPP or App
  Server producer thread while the application thread begins controller
  shutdown.
- Controller shutdown currently tries to empty `FPending` before it shuts down
  active hosts. A busy record cannot be extracted because another thread is
  using its claim, so shutdown sets `CompletionRequested` and repeatedly
  sleeps until `ReleaseClaim` runs.
- Deleting that controller loop alone would permit pending and active-host
  memory to be freed while `ProcessClaim` is using it. The poll protects a real
  race, but that race is created by the current shutdown order.
- `TNXBotHost.Shutdown` waits for `TNXXMPPClient.Disconnect`, which requests
  disconnection and joins `FConnection`. Its App Server side only enqueues
  `StopServer`; the App Server worker is not joined until
  `TNXCodexAppServer.Destroy` terminates and waits for it. The existing host
  `Shutdown` therefore does not yet mean that every host producer is
  quiescent.
- `TNXXMPPClient.Destroy` calls `Disconnect` before freeing its owning module
  list. Consequently the connection thread has stopped before
  `TNXXMPPBotControlModule.Destroy` runs.
- Bot-control `Lifecycle(xmlFinalDisconnect)` synchronously removes every
  non-publishing incoming correlation and cancels its controller token.
  Publishing records are retained only to protect the `HandleRequest` stack
  during its `OnRequest`/token-publication window.
- A publishing `HandleRequest` cannot remain on the joined connection thread
  when the module is destroyed. If a publishing record remains at that point,
  sleeping cannot repair it because that thread no longer exists.
- An incoming completion may originate on a different bot's lifecycle thread.
  Its `Complete` method extracts the correlation under the module lock and
  then delivers outside the lock. Merely observing `FIncoming.Count = 0` does
  not prove that such an extracted completion has finished using the module.
  Correctness must therefore come from quiescing all controller-owned producer
  threads before any host destroys its XMPP modules, not from polling the list.
- The GUI currently frees `FControlInterpreter` before freeing the controller
  that owns and shuts down `FHost`, while `FHost.OnPrompt` still points to the
  interpreter. That callback must be disconnected before interpreter
  destruction as part of the same shutdown ownership boundary.

## Architecture Problem

The present code tries to infer object safety by repeatedly observing
collection state:

1. The controller treats `Pending.Busy = False` as evidence that it may begin
   destruction, while the producer threads capable of making records busy are
   still running.
2. The bot-control module treats `FIncoming.Count = 0` as evidence that nobody
   is using the module, even though completion deliberately extracts its record
   before delivering through the module.

Neither observation establishes lifetime ownership. The correct boundary is
the existing ownership hierarchy: the controller owns active hosts; each host
owns its XMPP client and App Server; those objects own their worker threads.
The owner must stop and join those workers while all callback targets and
retained records remain valid. Once every producer has returned, pending
records and modules can be finalized synchronously without polling.

## Target Contract

### Controller shutdown

- `TNXBotController.Shutdown` is an application-owner operation. It is not run
  by an XMPP or App Server worker callback.
- The first short controller-memory operation sets `FShuttingDown`, closing
  admission and preventing host notifications from starting another
  advancement pass.
- Under the controller lock, shutdown obtains stable references to the active
  hosts it must quiesce. It performs no host behavior, callback, destruction,
  sleep, or wait while holding the lock.
- Outside the lock, shutdown disconnects each active host's `OnChanged`
  callback and synchronously quiesces the host. Host quiescence means:
  - the XMPP connection has been requested to stop and its thread has joined;
  - the App Server worker has been requested to stop and its thread has joined;
  - no host-owned producer can newly call `HostChanged`, controller model
    control, or a retained controller completion after quiescence returns.
- Hosts and their modules remain allocated during this quiescence pass. A
  lifecycle callback already in progress may return through `ReleaseClaim`,
  and final XMPP lifecycle handling may cancel incoming controller tokens,
  while every referenced object is still alive.
- After all active hosts are quiescent, no pending record may remain `Busy`.
  Shutdown extracts and cancels the remaining pending records through the
  normal exactly-once ownership path, invokes completions outside the lock,
  and performs no polling.
- Only after pending completion is settled does shutdown detach and destroy
  active hosts outside the controller lock.
- Shutdown remains idempotent. Repeated host shutdown/destruction must not
  restart workers or redeliver pending completions.

### Host and App Server shutdown

- `TNXBotHost.Shutdown` becomes the final, synchronous quiescence boundary for
  the threads owned by that host. Returning from it guarantees that neither
  XMPP nor App Server will issue another event from a worker thread.
- Operational `StopAppServer` behavior remains distinct: it may continue to
  request an ordinary reusable stopped state without destroying the worker.
- `TNXCodexAppServer` exposes one final shutdown operation used by its owner and
  destructor. That operation terminates/wakes and joins its existing worker
  exactly once, then leaves destruction to release the already-quiescent
  object state.
- No extra thread, event-dispatch layer, timeout, or periodic check is added.
  Any existing primitive needed to wake the App Server's own blocking loop
  remains local to that existing worker's termination path.

### Bot-control module destruction

- `TNXXMPPBotControlModule` continues to own only transport correlation for
  incoming IQ requests. The controller remains the sole owner of operation
  lifetime and exactly-once completion.
- Permanent transport loss continues to arbitrate correlation extraction and
  controller cancellation under the existing narrow module lock, with
  callbacks invoked after release.
- Final disconnect synchronously retires retained incoming correlations while
  the controller is alive.
- Module destruction occurs only after the owning XMPP connection thread and
  all controller-owned completion producers have been quiesced.
- Remove the destructor's `FIncoming.Count`/`Sleep(1)` loop. Do not replace it
  with an event, condition variable, reference-count wait, another counter
  poll, or forced delay.
- The correlation list must be empty at destruction by construction. Focused
  tests enforce that invariant. Destruction does not wait for an unknown
  external owner.

### GUI callback lifetime

- Before destroying `TNXBotControlInterpreter`, the GUI clears
  `FHost.OnPrompt` so the host cannot invoke a freed interpreter.
- Controller, App Server bot-control, and XMPP bot-control callbacks remain
  connected only as long as required to settle shutdown cancellation, then are
  cleared or destroyed with their owning host before the controller itself is
  released.
- Alias fields such as `FHost` and `FControlModule` do not own those objects and
  continue to be nulled rather than freed independently.

## Scope

- `NexusTools/BotHost/src/obNXBotController.pas`
- `NexusTools/BotHost/src/obNXBotHost.pas`
- `NexusTools/BotHost/src/obNXCodexAppServer.pas`
- `NexusTools/BotHost/src/obNXXMPPBotControl.pas`
- `NexusTools/BotHost/uiNXBotHostMain.pas`
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`
- Standalone BotHost tests where final App Server shutdown behavior requires
  focused verification
- BotHost documentation describing final synchronous shutdown ownership

## Out Of Scope

- Changing normal INVITE, DISMISS, LIST, or STATUS behavior.
- Restoring controller deadlines or adding any new timeout.
- Replacing direct Pascal events with queued application messages, an event
  bus, task system, or NexusUI work pump.
- Changing App Server JSON-RPC request deadlines or XMPP IQ/connection
  timeouts.
- Redesigning ordinary App Server start/stop/restart behavior beyond separating
  reusable stop from final owner shutdown.
- Changing NexusXMPP's general module API or connection-thread model.
- Broad critical-section cleanup, lock-free containers, or generalized
  lifetime infrastructure.
- Adding defensive sleeps, spin waits, or test-only production hooks.

## Staged Implementation Plan

1. **Make App Server final shutdown explicit and synchronous.**
   Separate reusable `StopServer` from owner destruction. Add an idempotent
   final shutdown path that terminates and wakes the existing App Server
   worker, joins it, and is reused by the destructor. Verify that no worker
   callback can occur after it returns.

2. **Make host shutdown a complete quiescence boundary.**
   Update `TNXBotHost.Shutdown` to disconnect/join XMPP and invoke final App
   Server shutdown. Keep owned objects allocated until the host destructor so
   callbacks and transport correlations remain valid throughout quiescence.
   Preserve idempotence for the destructor's repeated call.

3. **Reorder controller shutdown around ownership.**
   Close admission, obtain stable active-host references under the controller
   lock, and quiesce every host outside it. Do not drain or destroy pending
   records before the producers have stopped. After quiescence, cancel and
   finish every remaining pending record once, then detach and release active
   hosts outside the lock.

4. **Remove controller busy polling.**
   Delete the `Sleep(1)` branch and repeat-until busy wait. Treat a busy record
   after complete host quiescence as a failed internal invariant during focused
   testing, not as a state to wait out in production.

5. **Remove bot-control destructor polling.**
   Retain normal final lifecycle cleanup, delete the incoming-count wait loop,
   and free the already-retired correlation list normally. Do not add a
   replacement synchronization mechanism.

6. **Correct GUI callback teardown order.**
   Clear the host's interpreter callback before freeing the interpreter. Keep
   controller callback targets alive until controller-owned host quiescence and
   pending cancellation are complete.

7. **Document the final lifetime contract.**
   Record that controller shutdown is owner-thread initiated, host shutdown is
   synchronous final quiescence, and XMPP modules are destroyed only after all
   producers capable of using their correlations have stopped.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan does not authorize
spawning, resuming, messaging, or delegating to sub-agents. Plan approval and
implementation approval do not grant sub-agent permission; the human owner
must request sub-agent use explicitly in the current conversation.

## Verification Plan

- Add focused deterministic tests proving:
  - shutdown closes admission before producer quiescence;
  - a controller operation already claimed by a host producer returns normally
    while all controller, pending, active-host, and completion objects remain
    alive;
  - controller shutdown waits only by joining the producer owned by the host,
    not by inspecting `Busy` in a sleep loop;
  - after host quiescence, all remaining pending operations complete exactly
    once as cancelled and none remain busy;
  - App Server final shutdown produces no later worker callback and is
    idempotent;
  - final XMPP disconnect retires incoming IQ correlations before module
    destruction;
  - a completion racing final transport loss is either delivered or cancelled
    exactly once while the module remains alive;
  - GUI/interpreter teardown cannot invoke a freed prompt target.
- Preserve and rerun all existing controller lock-boundary, token-publication,
  cancellation, capacity, and transport-loss tests.
- Build and run the focused BotHost test module:

  ```powershell
  lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
  output\NexusTestHost\nxtest_host.exe `
    output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
    run-all
  ```

- Rebuild and run the standalone fake-App-Server test, including final worker
  shutdown.
- Rebuild the NexusBotHost GUI.
- Rebuild and run the deterministic NexusXMPP tests because module final
  lifecycle and client destruction order are part of the verified contract.
- Run an Openfire BotHost connect/join/exit cycle and confirm clean application
  exit without a delay, hang, duplicate IQ result, or post-destruction event.
- Focused searches must show no production BotHost destructor or controller
  shutdown loop containing `Sleep`, and no replacement polling loop.
- Inspect every changed critical-section region to confirm it contains only a
  small controller/correlation memory ownership transition and no callback,
  host operation, wait, or destruction.
- Run `git diff --check`, inspect the final diff for scope, and create the fresh
  source archive required after an approved architecture implementation.

## Risks And Questions

- App Server final shutdown must wake any blocking process/pipe operation before
  joining its worker. The implementation must reuse the worker's existing
  interruption/termination mechanics rather than wait on a thread that cannot
  observe termination.
- Quiescing one host at a time is safe only while every host object remains
  allocated. No active host or XMPP module may be destroyed until all hosts
  capable of producing controller completions have quiesced.
- Final lifecycle cancellation may synchronously re-enter the controller.
  `FShuttingDown` must reject new admission while still allowing cancellation
  and `ReleaseClaim` to settle existing tokens.
- The existing reference counts around active hosts must be balanced while the
  quiescence snapshot is held. Stable references are acquired under the lock
  and released only after pending ownership has been settled.
- No unresolved design choice blocks implementation. The correction is an
  ownership-order change, not a choice of a new synchronization primitive.

## Approval Gate

This work plan is for review only. No source implementation, build, test,
launch, archive, or source change begins until the human owner explicitly
authorizes implementation. Approval to implement does not authorize sub-agent
use.
