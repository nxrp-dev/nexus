# Work Plan: Nexus BindingSource-Style Data Binding Core

Status: Approved with the requested revisions incorporated; awaiting direct implementation authorization.
Date: 2026-09-13
Revised: 2026-09-14

## Inputs

- Human request: "Go ahead and generate the work plan."
- Reviewed source: `C:\Users\kcollins\Downloads\nexus-bindingsource-workplan-request (1).md`.
- Conversation review accepted the revised request as planning input. The production coordinator is a settled requirement; this is not a contracts-only implementation.
- Owner review requires explicit caller operations instead of a policy interface and includes DateTime and Currency in the initial scalar carrier. The remaining plan is approved; this revision does not begin implementation.
- This single plan uses the topic filename without the browser download suffix. No repository request copy or alternative plan is created.
- Governing files: `AGENTS.md`, `.ai/protocols/architecture-change.md`, `.ai/protocols/codex-workplan-format.md`, `.ai/standards/pascal.md`.
- Existing architectural note: `docs/nexus-ui/data-binding.md`. Its tentative context class names are not requirements for this new subsystem.

## Summary

Implement a GUI-independent binding subsystem around one canonical `TNXBindingSource`. Upstream contracts expose indexed items and resolvable values; the coordinator owns the public cursor and bindings; target contracts expose values and edit submission. All participating contracts are non-owning interfaces. Production helper objects may implement the coordinator's internal binding, subscription, and edit bookkeeping.

Prove the production subsystem using ordinary Pascal test sources, targets, converters, validators, and edit sessions. No production control, data adapter, reflection mechanism, or event loop is involved. This plan specifies the approved target behavior, not existing APIs or verified compiler results.

## Verified Findings

- At inspection, `main` and remote `origin/main` both identify `86065c7678292cb6d4dcd42cbe28a3293dd9d901`; the working tree was clean.
- `docs/nexus-ui/data-binding.md` says the binding layer is not implemented. A search of `NexusLib` Pascal sources found no `BindingSource`, `INXBinding`, `TNXDataContext`, or `TNXObjectContext` implementation.
- `NexusLib` separates `core`, `ui`, `net`, `script`, and other libraries into their own directories. A new `binding` directory avoids coupling the subsystem to UI or persistence.
- `NexusLib/ui/src/obNXControl.pas` declares `INXControlParent` under `{$interfaces corba}`. This is a local precedent for non-reference-counted contracts, not a reason to depend on that UI unit.
- `NexusLib/core/src/obNXJSONValues.pas` defines JSON-specific values and depends on `TypInfo`, `fpjson`, and class factory infrastructure. It is unsuitable as the binding value contract.
- `NexusTools/Test/src/obNXTestRegistry.pas`, `obNXTestSuite.pas`, `obNXTestCase.pas`, `obNXTestContext.pas`, and `obNXTestResult.pas` provide registration, assertions, case execution, and results without requiring the GUI runner. `TNXTestCase.Execute` returns an owned `TNXTestResult`.
- `obNXTestRunner.pas` brings in JSON RPC value types. A small console entry point can instead enumerate the existing registry and execute its cases directly, avoiding JSON/RTTI dependencies in this test project without changing NexusTest.
- `lazbuild.exe` resolves to `C:\lazarus\lazbuild.exe`; `fpc.exe` resolves to `C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe`. Neither compiler nor tests were run during planning.

## Architecture Problem

Value synchronization alone does not establish a data-aware system. Multiple consumers must agree on the current item, bindings must follow that item without stale subscriptions, and pending target input must survive conversion or write failure. Non-owning interfaces also require explicit disconnection before objects die.

These responsibilities need one defined coordinating implementation and independently implementable contracts. The coordinator must not acquire knowledge of model classes, control classes, business validation, or storage transactions.

## Target Contract

### Terminology

- **Cursor**: the coordinator's navigation state.
- **`Current`**: the item at the cursor.
- **`Position`**: the cursor's index.
- **`Currency`**: exclusively the Pascal fixed-point monetary datatype.

### Ownership and state flow

- An application/form/service owner creates and destroys `TNXBindingSource`.
- The coordinator owns individual binding objects and its subscription registrations. It owns copies of pending values and error results, but not upstream items, endpoints, converters, validators, or edit sessions.
- The upstream owner owns its source, items, and member endpoints. The target owner owns targets. Providers of optional collaborators keep them alive until explicitly detached.
- State flows from upstream item source through current-item resolution and a binding to a target. Two-way bindings submit proposed target values back through conversion, validation, and endpoint writes.
- Rendering, persistence, focus handling, and input events remain adapter responsibilities. A future focus-loss handler calls an explicit submit operation; the core does not infer focus or depend on a GUI event loop.
- All operations and participant notifications use one owning thread. No worker, timer, dispatcher service, or polling is added.

### Unit and package layout

| Path | Responsibility |
| --- | --- |
| `NexusLib/binding/AGENTS.md` | Reference the repository Pascal standard and the GUI-independent scope. |
| `NexusLib/binding/src/tpNXBinding.pas` | The single definitions of value/result/event types, identifiers, enums, and non-owning interfaces. |
| `NexusLib/binding/src/obNXBindingSource.pas` | Canonical `TNXBindingSource`; small owned binding/subscription helpers initially stay in its implementation section where possible. |
| `NexusLib/binding/docs/contracts.md` | Normative method semantics, ownership rules, event traces, and capability requirements for adapter authors. |
| `NexusLib/binding/tests/obNXBindingTestObjects.pas` | Fake participants and event recorder; no replacement binding engine. |
| `NexusLib/binding/tests/tsNXBindingContracts.pas` | Reusable endpoint/source/subscription capability tests driven by fixture creation methods. |
| `NexusLib/binding/tests/tsNXBindingSourceTests.pas` | Real coordinator scenarios and integration assertions. |
| `NexusLib/binding/tests/NexusBindingTests.lpr` and `.lpi` | Console test entry point using existing NexusTest cases directly. |
| `docs/nexus-ui/data-binding.md` | Replace tentative runtime direction with an accurate link and status after implementation. |

No Lazarus package or global build-system change is required for the first pass. Use unit search paths, as the existing test projects do. Production dependencies are ordinary RTL/FCL units only; test-framework units never enter production `uses` clauses. Shared definitions remain in `tpNXBinding`, without aliases or re-exports.

### Values and operation results

Use a small copied value record, `TNXBindingValue`, with explicit state (`unset`, `null`, `value`) and scalar kind (`Boolean`, `Int64`, `Double`, `UTF8String`, `DateTime`, `Currency`). DateTime and Currency have distinct kind tags and typed payload fields (`TDateTime` and Pascal `Currency`); they do not masquerade as Double or Int64 endpoints. Store managed text as an ordinary managed record field, not a managed variant-record arm. Only the field identified by the kind is meaningful. No arbitrary object pointers, JSON values, implicit Variant coercion, or serialized payloads.

- An endpoint descriptor declares its stable scalar kind and acceptance of null/unset. Unset is absence of a supplied value; null is a supplied null value; an empty string is a present string of length zero.
- A binding without a converter requires matching kinds. Conversion between kinds is explicit, including DateTime/Double and Currency/Int64 or Double. DateTime transfers the supplied date/time value without implicit time-zone conversion; Currency retains its native fixed-point value without a floating-point intermediate. Display formatting and parsing belong to converters. General decimal types, enums, sets, binary values, objects, arrays, and other composites remain deferred.
- `TryRead(out AValue)` and `TryWrite(const AValue)` return a structured result. Expected outcomes include success, unavailable, read-only, wrong kind, conversion failure/incomplete input, validation failure, rejected write, unsupported, busy, and source changed. Navigation also exposes the explicit `PendingEdits` result. Results carry a stable code and copied diagnostic text; no exception object is retained.
- A refused write makes no endpoint value change. A successful write may normalize the value; the coordinator reads it back and distributes the actual accepted value.
- No-op writes produce no value-change notification. Expected failures use results; unexpected exceptions propagate after internal guards and registrations are restored in `finally` blocks. Do not disguise programming errors as user validation errors.
- Readability/writability changing with item state is endpoint state, distinct from whether an object implements a capability interface. State-change notifications make these transitions observable.

### Proposed interfaces and boundaries

The names and operation shapes below are the intended API surface. Stage 1 supplies complete Pascal declarations and documents every argument/result using these semantics.

| Contract | Required operations and responsibilities |
| --- | --- |
| `INXBindingObservable` | Subscribe an `INXBindingObserver`, returning a subject-local numeric token; unsubscribe that token. Publishes value/state/list/closing events as appropriate. |
| `INXBindingObserver` | Receive a typed event from a live subject. Observer references are borrowed. |
| `INXBindingValue` | Descriptor, `TryRead`, and observable value/state. This is the readable endpoint contract. |
| `INXBindingWritableValue` | `TryWrite`; separate optional capability. Runtime writable state may still deny a particular write. |
| `INXBindingItem` | Stable source-local item identity and `ResolveValue(AMemberId, out AEndpoint)`. |
| `INXItemSource` | Count, indexed item access, and structural/closing notifications. It has no public cursor or navigation operations. |
| `INXBindingSource` | Attach/detach an item source, read Count/Position/Current, request a position or first/prior/next/last, add/remove a binding, inspect binding state, submit/cancel binding input, acknowledge a changed baseline, refresh, commit/cancel an edit session, and observe coordinator changes. |
| `INXBindingConverter` | Direction-explicit conversion using input value and destination descriptor; return converted value or a structured failure. |
| `INXBindingValidator` | Validate a proposed source value against the item/member context without mutating it. |
| `INXBindingEditSession` | Optional current-item transaction capability: begin, dirty state, commit, cancel, and notifications. Implemented by an item/test participant, not simulated by the binding engine. |

Use `{$interfaces corba}` for these contracts and plain explicitly owned objects. Capability discovery must use compiler-supported interface checks, with stable interface identifiers where required; verify this in the Stage 1 compile. Do not add a custom capability registry, `SupportsX` boolean catalogue, `TInterfacedObject`, or casting workaround.

`INXItemSource` is already an indexed collection contract, so an additional `INXBindingList` adds nothing here. Navigation belongs to `INXBindingSource`. Sorting, filtering, searching, insertion, deletion commands, and tree traversal capabilities are deferred; this phase must observe external collection changes but need not initiate those operations.

### Cursor and value resolution

- Positions are zero-based. No current item means Position = -1 and Current = nil. An empty source always has this state. Initial attachment selects item zero when nonempty.
- `TrySetPosition(-1)` explicitly clears selection, even in a nonempty source. Other out-of-range positions return a range failure without mutation. First/Last on empty and movement past an edge are successful no-ops. Next from no selection chooses first; Prior from no selection chooses last.
- Source-local item identities remain stable while an item exists and are not reused during a source attachment. Identity is independent of position and does not require retaining a dead object.
- Member identity is an opaque, case-sensitive UTF-8 key compared exactly. It is not parsed: punctuation has no property-path meaning. Fakes may implement a simple member table.
- On an accepted cursor change, detach old member subscriptions, resolve the same member identities on the new item, attach new subscriptions, and synchronize source-to-target. Target-to-source initial transfer is never repeated implicitly on navigation.
- A missing member, no current item, or unreadable value puts that binding into an explicit unavailable state. Do not write a fabricated null/default into the target. The target may retain its display, but cannot submit against the old item; consumers observe availability separately.
- Binding definitions remain registered when unavailable and retry resolution on a current-item or source reset event. A converter/read/write failure marks the affected binding; it does not restore the old cursor after the transition has already been accepted.
- Upstream structural events distinguish insertion, removal, replacement, and reset. Insertion/removal before Current adjusts Position while retaining current identity. Removing Current selects the successor at the old index, otherwise the preceding final item, otherwise none. Replacement at the same position is a Current change if identity differs. Reset searches for the retained identity, otherwise selects first or none.
- Removal events are emitted after the list changes but before removed objects are freed. Endpoints additionally issue Closing before destruction. Upstream lifetime must span the complete synchronous notification dispatch.
- External removal cannot be refused. Detach the removed item's endpoints immediately. Preserve any copied pending input as an orphaned edit with its old identity and an unavailable result; never submit it to the replacement item. Explicit cancellation clears it and refreshes from the new current item.

### Binding direction, initial synchronization, and updates

Each binding definition names a member, target endpoint, mode, update trigger, and optional converter/validator. `OneWay` means source-to-target. `TwoWay` also accepts target proposals. No implicit target-to-source-only mode is needed.

- Default initial transfer is source-to-target. Two-way registration may explicitly request target-to-source initial submission through the normal conversion/validation/write path. Registration returns an observable binding handle even when initial transfer fails, so the pending input/error is inspectable and removable.
- The target must be writable for source display. Two-way additionally requires a readable target and source write capability. If current source writability later changes, existing display still works and submissions return read-only.
- Triggers are `OnChange` and `Explicit`. OnChange attempts submission when a target reports a change. Explicit captures pending input but waits for `Submit`. A future focus-loss adapter calls Submit; there is no core focus abstraction.
- Binding handles are coordinator-local numeric identifiers, not borrowed internal object pointers. Removed handles are invalid and are not reused during that coordinator lifetime.
- A write notification attributable to the coordinator's own target transfer is not a new user proposal. After source acceptance, read back once and refresh all clean sibling bindings, including the originating binding. Each sibling has its own conversion and error result.
- One-way binding never writes the source after target changes. A changed one-way target is refreshed from the source when the next explicit refresh or source event occurs.

### Editing, validation, and transaction boundaries

The coordinator owns each binding's copied pending target value, baseline source value, pending flag, and result. A pending flag means a proposal differs from its last accepted target representation, not that a database transaction exists. Returning to the accepted representation clears local pending/error state. Source edit-session dirty state remains separately exposed.

Submission order is: confirm current identity/availability, read pending value, convert to source representation, validate, begin an optional item edit session if needed, write, read back accepted value, and refresh clean bindings. Conversion failure, incomplete input such as `"-"`, validation failure, or write rejection retains target input and the pending flag. A source-level normalization is displayed after successful acceptance.

`CancelPending` discards only local pending input and refreshes from the currently available source value. It does not undo a previously accepted write. `CommitEdit` first submits pending bindings for Current in registration order, then asks its optional edit session to commit. `CancelEdit` asks that session to cancel first and, on success, clears current-item pending values and refreshes. Failed session commit/cancel retains state and reports the failure.

Without an edit-session capability, Submit still works but transactional CommitEdit/CancelEdit return unsupported. The engine never advertises rollback of already accepted writes merely because it has value copies.

Multi-binding submission is not falsely atomic. If a later binding rejects, earlier accepted writes remain accepted (or pending in the source edit session), later bindings are untouched, Current does not move, and the result identifies the failing binding. Two differing pending proposals for the same item/member cause submission to refuse with an explicit ambiguous-proposal result before either is written; identical proposals may be submitted once and both refreshed. No silent last-writer-wins rule.

An edit-session Cancel must restore its session baseline atomically or refuse without mutation. Commit failure must preserve the session for correction/retry/cancel. An application requiring more than one item's atomic transaction supplies that separately; it is not a first-pass coordinator responsibility.

### Explicit caller operations and deterministic failures

The caller decides how to respond to failed transitions through the ordinary public API. There is no policy interface, callback, coordinator-owned policy state, or automatic commit/cancel-and-navigate operation.

Requested navigation that would change Current while local pending input or a dirty item session exists returns `PendingEdits` without changing the cursor, submitting, committing, or cancelling anything. The caller may submit pending input and commit an edit session if present, or cancel pending input/session edits, then retry `TrySetPosition`. Failed submission/session operations leave the edit unresolved, so a retry still refuses. Local pending input can be cancelled without a session; undoing accepted writes still requires the session capability. A no-op navigation request remains a no-op. Explicit source replacement/detachment follows the same refusal rule; forced Closing cannot be refused. No automatic retry, prompt, or continuation is retained by the coordinator.

When the source changes while local target input is pending, preserve the target input, mark the baseline/source-changed condition, and expose the current source value and result. Ordinary Submit refuses with source-changed. The caller may explicitly discard pending input and refresh through `CancelPending`, or acknowledge/rebase against the latest available source baseline while retaining the proposal, then explicitly retry Submit. Acknowledgement itself performs no write and bypasses neither conversion nor validation. A subsequent source change marks the condition again. Ordinary Refresh must not silently discard pending input or acknowledge the changed baseline. This is a local edit condition, not a general conflict-resolution service.

Source notifications from another binding count as external changes for a pending sibling. Orphaned input after item removal is never eligible for baseline acknowledgement against a different item. No business-specific choice is built into the coordinator.

### Notification, reentrancy, and feedback contract

- Notifications are synchronous and follow state mutation. Subscribers observe a coherent subject state. Registration order determines delivery order; a subscription added during dispatch begins with the next event.
- Unsubscribe is idempotent and effective immediately, including for a later callback in the active dispatch. Use token entries with active flags/deferred compaction, not a snapshot containing unprotected observer pointers.
- No-op value/position changes do not notify. Coordinator event categories distinguish PositionChanged, CurrentChanged, BindingStateChanged, and DataChanged. A structural data change is not misreported as a value edit.
- Within an accepted cursor operation, stage the new cursor state and binding states first, perform target synchronization, then publish PositionChanged if needed, CurrentChanged if needed, binding-state events in registration order, and one DataChanged. Public coordinator observers see the final state. Raw target observers may see individual transfers; cross-target atomic display is not promised.
- While an operation or coordinator notification is active, reentrant public navigation, submit, refresh, or registration requests return Busy with no side effects. Unsubscribe and safe binding removal remain allowed; reclamation of internal objects waits until the active call unwinds.
- Synchronous endpoint notifications caused by an expected write are recorded under that binding's active-transfer guard. They do not recursively submit. After the write returns, re-read the accepted value and publish the completed change. Scope guards per operation/binding; do not mute unrelated binding notifications with one blanket flag.
- Participant observers and converter/validator callbacks must not initiate independent data/list mutations from inside notification dispatch. Coordinator-controlled transfers are the permitted internal path, including read-back normalization of the originating target while its initial notification is still active. Writable targets must support this nested transfer; the binding guard prevents its notification from becoming another proposal. Upstream list mutation during its own structural dispatch is refused with Busy. This first pass deliberately provides no unbounded fixed-point propagation loop or application event queue.
- Closing events may invalidate references during a callback. Check registration/liveness after every external call before further use. Destroying the coordinator or a currently executing participant from its own callback is prohibited; disconnect/remove may be requested, and the owner frees it after the outer call returns.
- Callback exceptions are contract violations. Restore guards, finish required internal invalidation, and propagate; do not silently swallow them or claim notification delivery completed. Closing cleanup must still clear local borrowed references in `finally` paths.

### Lifetime and disconnection

Each observable owns its registration storage; the subscriber owns the responsibility to unregister its tokens. Source and target owners explicitly disconnect or emit Closing while the object is fully alive, before fields/endpoints used by subscribers are destroyed. Interface variables do not keep objects alive.

Coordinator destruction first marks it closing, disables outward updates, unsubscribes all live subjects, clears borrowed collaborators, and then frees bindings/registration storage. Target Closing removes that target's subscriptions and disables its bindings without reading or writing it again. Source Closing clears Current/Position and all item subscriptions, retains only copied pending input and binding definitions, and publishes unavailable state to surviving consumers.

After receiving Closing, subscribers discard both subject references and tokens; they do not later call Unsubscribe on that subject. Subscribe on a closing subject fails. Standalone observer owners unregister before destruction. Converters, validators, and sessions must be detached or outlive their registration; they are never freed by the coordinator. Test both explicit disconnection and Closing paths.

## Scope

Create the units, contract documentation, test fixtures, and console project listed above. Implement complete first-pass scalar binding, cursor, and edit coordination in the real coordinator. Update the existing binding documentation only after the implementation establishes those APIs. No existing UI, persistence, networking, scripting, or test framework refactor is included.

## Out Of Scope

fpGUI integration/adapters; databases, datasets, SQL, SQLite; RTTI/property adapters; JSON and NexusScript adapters; real grids, trees, or editors; designers; declarative syntax; inherited contexts; property expressions; templates; automatic UI generation; sorting/filtering/searching engines; application-policy interfaces/callbacks; cross-thread dispatch; automatic persistence; multi-item transactions; arbitrary value-object serialization.

The established semantics must remain usable by later adapters. Additional scalar kinds or capabilities may be justified later; this pass does not promise that every eventual consumer can be expressed without any contract additions.

## Staged Implementation Plan

### Stage 1: Declare and compile the contracts

Create the new folder guidance, `tpNXBinding`, normative contract document, and console project skeleton. Define full method signatures, all six scalar kinds, value states, results, identifiers, subscription events, and explicit caller operations before coordinator logic. Supply minimal fake read-only and writable endpoints to compile capability discovery and non-owning ownership paths.

Acceptance: declarations and fixtures compile using the installed compiler; dropping interface variables does not destroy explicitly owned test objects; absence/presence of write and edit capabilities is correctly observable. No GUI, JSON, RTTI, or production data unit enters the test dependency graph. All state transitions above have named results and documented pre/postconditions.

### Stage 2: Endpoints, subscriptions, and scalar binding

Implement the real coordinator's binding registration/removal, initial direction, one-way/two-way transfer, conversion/validation, state reporting, and synchronous echo guards. Add source/target Closing and safe subscription removal at this stage rather than retrofitting lifetime later.

Acceptance: scalar tests, failure retention, normalization, multiple subscribers/targets, and teardown tests pass; each successful source change reaches each clean target once without recursive source writes.

### Stage 3: Cursor and value resolution

Implement indexed source attachment, an identity-based cursor, navigation, current member resolution, endpoint replacement, empty/missing states, and structural list changes. Add shared-consumer scenarios with at least two items and two members.

Acceptance: navigation and externally changed list tests pass; old endpoints cannot update current bindings; position-only shifts preserve current identity; callback traces match the specified ordering.

### Stage 4: Editing and explicit caller transitions

Implement pending state, explicit/OnChange submission, source edit-session orchestration, deterministic `PendingEdits` refusal, source baseline acknowledgement, and orphaned edits. Exercise submit/commit/cancel/rebase and navigation retries as separate caller operations. Converters, validators, and edit-session implementations remain test objects.

Acceptance: incomplete input survives refusal; commit/cancel and partial-failure results match the contract; unsupported rollback is reported honestly; no pending value can be submitted to a replacement item accidentally.

### Stage 5: Integration and contract audit

Run the full matrix, verify participant teardown in different ownership orders, inspect external-call boundaries and dependency closure, and finish adapter-facing documentation. Update the existing binding overview to identify the implemented subsystem and its actual limits.

Acceptance: all required tests pass with zero skips; production units are independent of UI/data technologies; lifetime and notification traces are documented; the implementation report identifies commands, results, and any remaining limits. Create the repository-required fresh source archive after the approved implementation pass and verify it contains the new source/test/contract files.

Implementation remains local; this plan authorizes no sub-agent use.

## Verification Plan

### Test objects

| Test participant | Purpose |
| --- | --- |
| `TTestItem` | Stable identity, two or more independently resolvable members, optional session. |
| `TTestSource` | Indexed items; insertion, removal, replacement, reset, explicit Closing. |
| `TTestValue` / `TTestReadOnlyValue` | Descriptor/read/write/state; normalized/rejected writes and event counts. |
| `TTestTarget` | User proposals distinct from coordinator writes; pending string input. |
| `TTestConverter` | Integer/text conversion, incomplete text, failure, normalization. |
| `TTestValidator` | Accepted/rejected proposals; verifies invocation order and no mutation. |
| `TTestEditSession` | Baseline/current copies, begin/commit/cancel failure injection and dirty state. |
| `TTestObserver` | Event sequence, unsubscribe during callback, Busy requests, Closing assertions. |

Fixtures expose factory/setup operations so endpoint/source capability tests can later run against real adapters. Tests assert public state and event traces, not private list layout. Coordinator tests always instantiate `TNXBindingSource`.

### Contract-test matrix

| Area | Required cases and observable assertions |
| --- | --- |
| Values | Present/empty string/null/unset distinct; all six kinds enforced; DateTime and Currency round-trip through same-kind endpoints without numeric coercion; mismatched numeric kinds require conversion; negative/fractional Currency retains exact native value; DateTime date/time portion survives transfer; copied text survives participant destruction; availability and runtime read-only transitions visible. |
| Initial transfer | Default source-first, explicit target-first in two-way, failed initial conversion retained, late source attachment and unavailable member. |
| Direction | One-way never writes source; two-way transfers both ways; no-op values do not notify; source normalization is read back. |
| Updates | OnChange vs Explicit; two members and multiple clean targets update correctly; converter/validator order and rejected writes retain input. |
| Cursor | Empty, first/last/edges, -1, invalid position; same item/no-op; position-only shift; item replacement with same position; no-current transitions. |
| Resolution | Old member detached; new member subscribed; missing/read-only/wrong-kind members; reset retries resolution; stale old notifications cannot write current targets. |
| Collection change | Insert/remove before Current; delete Current with successor/predecessor/empty; reset retains identity; removed objects freed only after dispatch. |
| Editing | `"-"` to integer; dirty/clean/error transitions; explicit cancellation; accepted write differs from transaction commit; failed commit/cancel retains state. |
| Multi-binding edit | Failure after earlier acceptance is reported without false rollback; differing proposals to one member refuse before writes; equal proposals converge. |
| Caller navigation sequence | `PendingEdits` refusal performs no write/commit/cancel; caller explicitly submits/commits then retries; caller explicitly cancels then retries; failed edit operation keeps retry refused; unsupported rollback; clean/no-op navigation. |
| Pending source change | Target A pending while B writes; preserve input and refuse Submit; caller discard/refresh or rebase then Submit; rebase does not write or bypass validation; ordinary Refresh preserves pending input; repeated source change requires renewed acknowledgement. |
| Forced removal | Pending edit becomes orphaned with old identity; replacement item untouched; copied input survives old item destruction; cancel refreshes new item. |
| Subscriptions | Multiple observers, stable order, self-unsubscribe, remove next subscriber, add during dispatch, idempotent unsubscribe, invalid handle. |
| Teardown | Coordinator first, source first, target first; explicit disconnect and Closing; remaining observers safe; no retained dead interface/token. |
| Reentrancy | Write echo does not resubmit; public nested mutation returns Busy; independent bindings are not silently muted; binding removal during callback is safe. |
| Exceptions | Unexpected converter/observer exception releases guards; required Closing invalidation survives exceptions; next valid operation is usable. |
| Event order | Cursor and binding states coherent at coordinator callbacks; PositionChanged/CurrentChanged reflect actual differences; failure results precede completion observation. |

### Build and run

From repository root, after implementation authorization:

```powershell
lazbuild NexusLib\binding\tests\NexusBindingTests.lpi
& .\output\NexusBindingTests\x86_64-win64\NexusBindingTests.exe
```

The new LPI will explicitly set that output path and separate unit output directory. Its search paths are `tests`, `../src`, and `../../../NexusTools/Test/src`; it must not need UI/core JSON unit paths. The runner enumerates `TNXTestRegistry` suites/cases, invokes `Execute`, prints failures and totals, frees results, and returns nonzero for failure/error or unexpected skips. This is a proposed command for the project to be created, not a claim that it already builds.

Compile after each structural stage and run the affected suites, then the complete suite at Stage 5. Use a final heap-check build where supported by the new project's verified compiler settings; record any test-host allocation noise separately and resolve actual binding leaks. No GUI manual test is required: manually review the console totals and recorded event traces for cursor changes, rejected edits, and teardown.

Focused review commands:

```powershell
rg -n 'uses|interfaces|TInterfacedObject|_AddRef|_Release|QueryInterface|TypInfo|fpjson|fpg_|TDataSet|SQLite|TThread' NexusLib/binding
rg -n 'Subscribe|Unsubscribe|Closing|TryWrite|TrySetPosition|Submit|Cancel|Commit' NexusLib/binding
git diff --check
```

Inspect actual `uses` closure rather than treating grep absence as proof. Contract prose may legitimately mention excluded concepts. Audit every borrowed reference across external calls, all result paths after failed writes, and the exact test count/zero-skip outcome. Broader builds are needed only if implementation changes shared existing code, which this plan does not propose.

## Risks And Questions

- The scalar carrier includes Boolean, Int64, Double, UTF8String, DateTime, and Currency. Currency is the native fixed-point scalar, not a general arbitrary-precision decimal facility. Enums, sets, blobs, objects, arrays, and other composite/general decimal types remain deferred; do not silently encode them as strings or numeric stand-ins.
- Non-owning interfaces cannot protect against an owner freeing an object without disconnecting. Closing and owner discipline are contractual requirements, tested but not replaced by reference counting.
- This synchronous first pass restricts mutation from observer callbacks and refuses public reentrancy. If application-driven recursive mutation must be supported, that is an architectural change requiring explicit revised scheduling semantics, not a hidden queue added during implementation.
- Source transactions are optional and do not confer cross-item atomicity. Partial accepted writes must remain visible in results and tests.
- A future cursor-based adapter must reconcile its private cursor with the indexed item contract while the coordinator retains the public cursor. This plan neither implements nor proves that adapter; stable item identity/value resolution remain its obligations.
- No application-policy abstraction is required: deterministic refusal/preservation and explicit caller operations cover the required scenarios. The owner approved the plan with removal of policy machinery and addition of DateTime/Currency; those changes are incorporated here. Any incompatible requirement discovered before implementation should revise this same plan.

## Approval Gate

This artifact authorizes planning only. No implementation, build, test run, control/data integration, or implementation archive begins until the human owner directly authorizes implementation. Commit and push this plan alone as the required planning handoff; implementation commits remain a separate owner decision.
