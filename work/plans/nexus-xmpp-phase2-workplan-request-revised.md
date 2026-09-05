# Work Plan: NexusXMPP Phase 2 Messaging And Multi-User Chat

## Owner Amendment: 2026-09-03

The human owner expanded the approved MUC scope after implementation review.
Instant room creation is normal XEP-0045 client functionality owned by the
production MUC module. The live test creates its own unique instant room through
that public API; it does not contain test-only stanza construction. It also
joins the owner-provided permanent `nexus-test` room and sends a uniquely labeled
message so the result can be inspected directly in Openfire.

## Inputs

- Source request: `C:\Users\kcollins\Downloads\nexus-xmpp-phase2-workplan-request-revised.md`.
- Related discussion/review notes:
  - Phase 2 is a reusable, application-neutral messaging layer for shared human/AI conversation rooms; Nexus-specific bot and AI behavior remains outside NexusXMPP.
  - Protocol identifiers must retain their distinct issuers and scopes rather than being collapsed into one message ID.
  - Carbons and MAM must share one trusted forwarding decoder and must not recursively redispatch forwarded content as ordinary live traffic.
  - MUC recovery must distinguish accepted XEP-0198 resumption from a newly authenticated and bound session.
  - MUC join history must be distinguishable from live room traffic, retain delay metadata, remain bounded, and never trigger receipt or chat-state side effects merely because it was delivered.
  - Carbon activation must have typed enable/disable behavior: a new bound session enables again when requested, while a resumed stream retains the prior negotiated state.
  - XEP-0184 receipts correlate the ordinary stanza `id`; they do not substitute an XEP-0359 `origin-id`.
- Existing constraints:
  - Follow repository `AGENTS.md`, `NexusLib/net/AGENTS.md`, `NexusLib/net/src/xmpp/AGENTS.md`, `.ai/standards/pascal.md`, and `.ai/protocols/architecture-change.md`.
  - Preserve connection-thread socket/protocol ownership, bounded cross-thread queues, retained event data, and caller-thread callback delivery through `PumpEvents`.
  - Extend the Phase 1 owners only where Phase 2 demonstrates a required seam; do not redesign TLS, SASL, transport, framing, or XEP-0198.
  - Keep NexusUI, AI-agent policy, application protocols, durable message storage, Phase 3 authentication work, and generic framework abstractions out of scope.
  - Implementation remains local. The human owner has not authorized sub-agent use.

## Summary

Add a coherent Phase 2 messaging layer to NexusXMPP covering ordinary and room message metadata, XEP-0045 room participation, XEP-0359 identifiers, XEP-0461 replies, XEP-0184 delivery receipts, XEP-0085 chat states, XEP-0280 carbons, and bounded XEP-0313 MAM queries.

The implementation begins by correcting four shared limitations exposed by those features: the retained stanza currently describes only its root and first child; caller-thread module APIs have no typed route onto the connection thread; modules do not receive session lifecycle distinctions; and outgoing XEP-0030 queries/capability state do not exist. The correction will preserve the existing connection, dispatcher, request-manager, event-pump, and module ownership model rather than introducing another transport or event framework.

Once those seams exist, introduce one shared typed message representation and one bounded forwarding decoder. Each feature module will consume that common representation. MUC will own room and occupant state, Carbons will own carbon activation and validation, and MAM will own query/result correlation and limits. Applications receive typed caller-thread callbacks while raw retained stanzas and unknown extensions remain available.

## Verified Findings

### Current Phase 1 implementation

- `TNXXMPPClient` owns configuration, module lifetime, the dispatcher, command/event queues, shared pending-IQ capacity, and the connection thread. It freezes the module set from `Connect` until final `Disconnect`.
- `TNXXMPPConnection` exclusively owns normal socket I/O, framing, request correlation, recovery, stream-management state, and protocol-state transitions. Application callbacks are not invoked there.
- `TNXXMPPObjectQueue` is an owned, lock-protected, finite object queue. Failed enqueue leaves ownership with the caller, and queued objects are freed by the queue.
- `TNXXMPPCommand` currently supports only raw XML, IQ, and disconnect commands. Raw message/presence replayability is inferred from the first bytes of the XML rather than stated by the command producer.
- `TNXXMPPModule.Send` calls a sender installed by the client. `TNXXMPPConnection.SendModuleXML` rejects calls outside the connection thread and always transmits module XML as non-replayable. A module therefore cannot expose an ordinary caller-thread join, chat-state, carbon, or MAM API through the current sender.
- Modules receive only `RegisterHandlers` on setup and `PumpStanza` on caller-thread delivery. They have no explicit notification that a transport was interrupted, an old stream was resumed, a new session was authenticated/bound, or a session was permanently lost.
- `TNXXMPPDispatcher` provides exact, exclusive IQ `get`/`set` responder keys and multiple observers. The connection uses it before queuing the same retained top-level stanza for caller-thread pumping. It does not transform nested forwarded messages or attach a delivery/trust context.
- `TNXXMPPRequestManager` allocates the IQ stanza ID on the connection thread in `BeginRequest`, tracks one final result/error per request, validates an optional exact `from`, and converts timeout/cancellation/completion into caller-thread events. The public `SendIQ` returns only a Boolean, so the generated IQ ID is unavailable synchronously.
- `TNXXMPPStanza` owns the raw XML and parsed DOM and retains root attributes. Because FPC 3.2.2 loses DOM namespace metadata, the implementation separately captures only the root and first element-child QNames from the validated bytes. Phase 2 needs namespace-correct traversal of multiple sibling extensions and nested forwarded stanzas.
- `TNXXMPPStanza.TextContent` returns all descendant text, not the message body specifically. There is no typed body, delay, stable-ID, reply, receipt, chat-state, forwarding, carbon, MAM, or MUC metadata model.
- `TNXXMPPEvent` currently carries state, a raw retained stanza, an error, an IQ completion, or unrecoverable XEP-0198 replay work. Its connection state cannot tell modules whether `xcsOnline` followed a successful resume or a fresh authentication/bind.
- `TNXXMPPDiscoModule` advertises configured `disco#info` features and answers incoming queries. It does not issue `disco#info`/`disco#items` requests, parse results, validate entity-capability hashes, or maintain a bounded capability cache.
- `TNXXMPPOpenSSL` exposes SHA-256, HMAC-SHA-256, PBKDF2-SHA-256, and secure random bytes. XEP-0115 makes SHA-1 mandatory for its capability verification string, so the existing XMPP-specific OpenSSL adapter needs one narrowly scoped SHA-1 digest operation; SHA-1 must not be reused for authentication, password derivation, or new security protocols.
- `TNXXMPPRosterModule` demonstrates the intended division: connection-thread dispatch performs protocol work, synchronized state is retained by the module, and `PumpStanza` invokes application callbacks on the caller thread.
- XEP-0198 already reserves replay capacity before transmitting a replayable stanza and explicitly surfaces replayable work made unrecoverable by failed resumption. Phase 2 must supply replay eligibility explicitly instead of weakening those guarantees.

### Current tests and live boundary

- `NexusNetXMPPTests.lpr` provides deterministic tests for framing, retained stanza QNames, dispatcher ownership, IQ correlation/capacity, TLS, SASL, state transitions, bounded queues, XEP-0198 recovery rules, discovery responses, roster behavior, and repeated client lifecycle.
- The current deterministic target is an `.lpr`-only FPC build with output isolated below `output/NexusNetXMPPTests`.
- `NexusNetXMPPLiveTest.lpr` currently proves two-client Openfire TLS, authentication, binding, presence, and basic one-to-one message exchange. It does not register Phase 2 modules or exercise a room/archive/carbon feature.
- `NexusNetXMPPTests.md` records Openfire 5.1.2 as the controlled live server and explicitly states that accepted live XEP-0198 forced resumption was not exercised.
- The checked-in XMPP fixtures currently contain TLS material and the controlled Openfire public certificate, but no Phase 2 XML transcript corpus.
- `NexusXMPPConsole.lpr` is a minimal Phase 1 client. It registers disco and roster modules and displays raw stanzas; it has no typed Phase 2 operations.

### Selected specification baseline

The following official XSF revisions were verified on 2026-09-02 and are the implementation baseline. Experimental status is intentional and must remain visible in documentation:

| Specification | Selected revision | Status | Phase 2 use |
| --- | --- | --- | --- |
| [XEP-0030 Service Discovery](https://xmpp.org/extensions/xep-0030.html) | 2.5.0, 2024-04-30 | Final | outgoing info/items queries and feature advertisement |
| [XEP-0045 Multi-User Chat](https://xmpp.org/extensions/xep-0045.html) | 1.35.5, 2026-05-03 | Stable | instant room creation, room participation, and room state |
| [XEP-0359 Unique and Stable Stanza IDs](https://xmpp.org/extensions/xep-0359.html) | 0.7.0, 2023-02-20 | Experimental | `origin-id` and one-or-more `(by,id)` stanza IDs |
| [XEP-0461 Message Replies](https://xmpp.org/extensions/xep-0461.html) | 0.2.1, 2026-02-25 | Experimental | semantic reply references |
| [XEP-0184 Message Delivery Receipts](https://xmpp.org/extensions/xep-0184.html) | 1.4.0, 2018-08-02 | Stable | receipt requests/responses and correlation |
| [XEP-0085 Chat State Notifications](https://xmpp.org/extensions/xep-0085.html) | 2.1, 2009-09-23 | Final | typed transient chat state |
| [XEP-0280 Message Carbons](https://xmpp.org/extensions/xep-0280.html) | 1.0.1, 2021-12-26 | Stable | validated sent/received carbon copies |
| [XEP-0313 Message Archive Management](https://xmpp.org/extensions/xep-0313.html) | 1.1.3, 2025-04-09 | Stable | bounded streamed personal/MUC archive queries |
| [XEP-0297 Stanza Forwarding](https://xmpp.org/extensions/xep-0297.html) | 1.0, 2013-10-02 | Stable | shared carbon/MAM forwarded-stanza envelope |
| [XEP-0059 Result Set Management](https://xmpp.org/extensions/xep-0059.html) | 1.0, 2006-09-20 | Stable | MAM page request and final page metadata |
| [XEP-0004 Data Forms](https://xmpp.org/extensions/xep-0004.html) | 2.13.2, 2024-08-30 | Final | MAM filters and extended disco information |
| [XEP-0068 Field Standardization](https://xmpp.org/extensions/xep-0068.html) | 1.3.0, 2020-05-05 | Active/Informational | `FORM_TYPE` and registered field interpretation |
| [XEP-0128 Service Discovery Extensions](https://xmpp.org/extensions/xep-0128.html) | 1.0.1, 2019-07-30 | Active/Informational | typed MUC room information forms |
| [XEP-0203 Delayed Delivery](https://xmpp.org/extensions/xep-0203.html) | 2.0, 2009-09-15 | Final | MAM and MUC-history delay metadata |
| [XEP-0082 XMPP Date and Time Profiles](https://xmpp.org/extensions/xep-0082.html) | 1.1.1, 2021-08-31 | Active/Informational | strict delay/filter timestamp parsing and UTC serialization |
| [XEP-0421 Occupant identifiers](https://xmpp.org/extensions/xep-0421.html) | 1.0.1, 2025-04-09 | Stable | stable participant identity in supporting MUCs |
| [XEP-0428 Fallback Indication](https://xmpp.org/extensions/xep-0428.html) | 0.2.1, 2024-03-20 | Experimental | bounded reply-fallback body ranges only |
| [XEP-0199 XMPP Ping](https://xmpp.org/extensions/xep-0199.html) | 2.0.1, 2019-03-26 | Final | ping responder and MUC self-ping request |
| [XEP-0410 MUC Self-Ping](https://xmpp.org/extensions/xep-0410.html) | 1.1.0, 2019-09-25 | Stable | verify room occupancy after ambiguous interruption/resumption |
| [XEP-0115 Entity Capabilities](https://xmpp.org/extensions/xep-0115.html) | 1.6.0, 2022-03-08 | Stable | narrowly required feature advertisement and verified capability caching |

Normative and operational dependency relationships selected for implementation are:

- XEP-0045 depends on XMPP Core/IM plus XEP-0004, XEP-0030, XEP-0068, XEP-0082, and XEP-0128. This plan implements only the slices needed for room discovery/information, entry/history, participant state, messages, subject, nickname changes, and exit; form-driven administration remains excluded.
- XEP-0359 is the authority for origin and service-assigned stanza identifiers. XEP-0461 uses the contextually correct referenced ID; a groupchat reply uses the room-assigned stanza ID whose `by` is the bare room JID and cannot be constructed safely without it.
- XEP-0461 requires reply feature advertisement through XEP-0030 and XEP-0115. XEP-0428 is used only to mark/remove the optional compatibility fallback portion of a reply body.
- XEP-0085 depends on XMPP Core/IM and XEP-0030 and defines its interaction with groupchat. It remains transient even when carried inside an otherwise eligible carbon wrapper.
- XEP-0280 depends on XEP-0030, XEP-0085, and XEP-0297. XEP-0184 payloads can be carbon-eligible, but receiving a carbon copy does not authorize this resource to generate a receipt.
- XEP-0313 depends on XEP-0030, XEP-0059, and XEP-0297. Its filters use XEP-0004/0068 field conventions, and archived content uses XEP-0203/XEP-0082 delay timestamps and XEP-0359 identifiers where provided.
- XEP-0421 depends on XEP-0030 and XEP-0045. An Occupant ID is scoped to the issuing room/service contract and is not a replacement for a real JID or occupant JID.
- XEP-0410 applies XEP-0199 ping semantics to the client's own XEP-0045 occupant JID. It is the bounded mechanism used here to resolve ambiguous room occupancy rather than assuming an accepted transport recovery preserved room state.

## Architecture Problem

The Phase 1 architecture correctly centralizes socket and stream state, but its extension contract is mostly reactive: modules can answer or observe an incoming stanza while on the connection thread, and later inspect every retained stanza during caller-thread pumping. That is sufficient for roster pushes and disco responses. It is not sufficient for active, stateful protocols whose public methods originate work, survive transport transitions, and correlate multiple incoming stanzas with one operation.

Adding each XEP as an independent raw-XML helper would repeat the same defects: separate message parsers would disagree about identifiers, forwarded MAM/carbons would be mistaken for live traffic, modules would bypass thread ownership to send, and room/carbon state would not know whether `Online` meant resume or a new bound session. MAM would additionally be forced into the single-response IQ abstraction even though its results precede the final IQ as a message stream.

The correction is not a new generic protocol framework. NexusXMPP needs one Phase 2-specific shared message model, one namespace-correct retained element traversal facility, one extension of the existing bounded command queue for typed module operations, and explicit module lifecycle hooks emitted by the existing connection owner. Those seams let focused protocol modules remain independent without duplicating identity, forwarding, threading, or lifecycle policy.

## Target Contract

### Ownership

- `TNXXMPPClient` remains the public facade and owner of the immutable connected module set, command/event queues, connection lifetime, and caller-thread pumping.
- `TNXXMPPConnection` remains the sole owner of the socket, stream state, request manager, XEP-0198 state, recovery decisions, connection-thread module command execution, and exact session-lifecycle notifications.
- `TNXXMPPStanza` continues to own retained raw XML and DOM data. A namespace-aware element/extension view owned by the stanza will expose all direct children and bounded nested children without transferring DOM ownership.
- A shared message parser/model owns protocol-neutral message content: ordinary attributes/body, delivery context, delay, independent identity fields, reply metadata, receipt metadata, chat state, and retained unknown extensions. It does not own room membership, carbon activation, or archive-query policy.
- The forwarding decoder owns XEP-0297 structural validation and bounded unwrap results. Carbons and MAM supply the wrapper-specific trust rule and resulting delivery context.
- Each protocol module owns only its feature state:
  - discovery owns outgoing query correlation and a bounded in-memory capability cache;
  - MUC owns rooms, occupants, membership transitions, history classification, and self-ping recovery;
  - receipts owns eligibility/policy and sent-receipt correlation;
  - chat states owns typed parsing/sending, not user-idle timers;
  - carbons owns enablement and wrapper validation;
  - MAM owns bounded query operations, intervening result correlation, cancellation, and final completion.
- Applications own any model copied or retained beyond a callback and all persistence. No Phase 2 object implies process-restart durability.

### Namespace-correct retained structure

- Extend retained stanza inspection so callers can enumerate every direct element child by `(namespace URI, local name)` and perform explicitly bounded descendant traversal needed for forwarding and data forms.
- Resolve namespace declarations at each nested element rather than trusting prefix spelling or the FPC DOM namespace fields that are known to be incomplete on the current toolchain.
- Keep raw XML and unknown extension children available. Typed parsing consumes recognized elements without deleting or rewriting the retained stanza.
- Add focused accessors for element attributes, direct text, child enumeration, and owned/borrowed lifetime rules. Do not expose parser buffers or create a general XML framework outside NexusXMPP.
- Enforce the existing stanza byte/depth limits and a separate small forwarding unwrap-depth limit. Malformed recognized extensions produce structured per-feature invalid metadata or errors; they do not cause an unbounded search.

### Module command and session lifecycle seam

- Extend the existing command queue with one `xckModule` path containing an owned, immutable typed module operation and its registered target module. The queue capacity, enqueue failure behavior, and disconnect wake path remain unchanged.
- A module public method validates its arguments, allocates any identity the caller needs immediately, creates its typed command, and returns failure synchronously if the existing command queue cannot accept it. It never calls the socket or connection directly.
- The connection validates that the target belongs to the frozen module set and executes the operation on the connection thread through a narrow XMPP session context. That context permits stanza transmission with an explicit replay policy and IQ initiation through the existing request manager; it does not expose the transport or socket.
- Replace raw-prefix replay inference with an explicit protocol replay classification carried by each outgoing command. Capacity must still be reserved before transmission. IQ operations remain non-replayed and are cancelled on connection loss; message/presence replay decisions remain visible to XEP-0198.
- Add connection-thread module lifecycle hooks for temporary transport loss, successful stream resumption, fresh authenticated/bound session, permanent session failure/loss, and final disconnect. The client keeps module instances alive until the connection thread has stopped.
- Queue a retained lifecycle outcome for caller-thread pumping as needed by typed module callbacks. Internal protocol recovery may act on the connection-thread hook, but application callbacks continue to run only during `PumpEvents`.
- A newly bound session clears session-scoped capabilities and causes requested features such as carbons and room membership to be re-established. A successful XEP-0198 resumption retains prior negotiated/module state unless the applicable protocol requires verification. Temporary loss marks room state stale without claiming that occupancy survived.

### Shared message and identity contract

- Parse and expose the ordinary stanza `id` independently from XEP-0359 data.
- Represent an `origin-id` as its own optional value and represent server/service stanza IDs as a collection of `(by JID, id)` values because multiple assigning entities may add IDs.
- Preserve receipt request/response metadata separately. A receipt response's correlation value refers to the original ordinary message stanza `id`, never automatically to `origin-id`.
- Preserve MAM query ID and result ID on the archive envelope, not as aliases of the forwarded message IDs.
- Preserve XEP-0421 Occupant ID on MUC participant/message metadata independently from occupant JID, nickname, and disclosed real JID.
- Define delivery context as at least live, MUC history, sent carbon, received carbon, and MAM result. Context is attached to the typed message and controls side effects.
- Preserve valid XEP-0203 delay data as source JID, UTC timestamp, and optional reason. Invalid timestamps remain detectable and are not silently converted to a current time.
- `SendMessage` is reshaped into a typed send operation. The caller may provide a valid origin ID or receive a securely allocated one synchronously before enqueue. The result also exposes the ordinary stanza ID used for XEP-0184 correlation. Queue rejection does not report the message as accepted.
- Use the existing OpenSSL secure-random owner to produce UUID-compatible identifiers; do not add another random provider.
- Typed callback values either clone their retained data or document callback-only borrowing consistently. No typed event may reference a parser-owned transient node.

### Discovery and capability contract

- Extend XEP-0030 with typed `disco#info` and `disco#items` requests using the existing IQ capacity/request owner.
- Parse identities, features, items, nodes, and the narrowly required XEP-0004/XEP-0068/XEP-0128 extended information. Preserve unknown identities, fields, and features without trying to interpret them.
- Add a finite cache keyed by exact queried entity JID plus node. Configure maximum entries and a bounded lifetime; clear unversioned session results on a fresh bound session and on final disconnect.
- Implement the XEP-0115 verification string and hash checking needed to trust/cache advertised entity capability nodes. Unverified/malformed capability advertisements may prompt direct disco but are never cached as verified facts.
- Implement XEP-0115's mandatory SHA-1 verification through the existing XMPP-specific OpenSSL owner. Unknown or unsupported advertised hash algorithms trigger ordinary direct disco and are not accepted into the shared verified-capabilities cache.
- Feature modules request discovery through this one owner. They do not each maintain an independent feature cache or recursively scan a server without a caller request.
- Advertising a module's supported feature updates the existing disco response owner before connection. Feature advertisement remains fixed with the frozen module set.

### Forwarding and delivery context contract

- One XEP-0297 decoder accepts a retained wrapper element, enforces exactly one permitted forwarded stanza, applies the configured nesting bound, parses optional delay metadata, and returns the outer wrapper, forwarded stanza, and validation result.
- The decoder does not dispatch the forwarded stanza. The invoking Carbon or MAM module validates wrapper authority and creates one typed message with the appropriate delivery context.
- Carbons validate outer sender/recipient and sent-versus-received structure against the client's bound/bare JID according to XEP-0280. Invalid or spoofed wrappers are surfaced as structured protocol diagnostics and never as trusted messages.
- MAM validates query/result correlation and archive authority before treating forwarded content as an archive result.
- Receipt automation, chat-state session changes, and other live-only side effects are forbidden for `sent carbon`, `received carbon`, `MAM result`, and `MUC history` solely because the wrapper reached this resource.

### MUC contract

- The MUC module exposes typed instant-room creation, join, leave, change nickname, send groupchat message, send private occupant message, and set subject operations.
- Instant creation joins a new room, recognizes status 201, and submits the standard empty `muc#owner` data form. Existing-room and configuration failures remain explicit. Join input includes room bare JID, nickname, optional room password, and bounded XEP-0045 history request controls.
- Each room has explicit state: creating, configuring, joining, joined, leaving, stale/disconnected, rejoining, failed, and left. Lifecycle transition reasons distinguish creation/configuration, requested leave, conflict, kick/ban, service error, new-session rejoin, successful resumed verification, and permanent session loss.
- Self-presence is recognized from MUC status code 110 and the room/occupant address, not by nickname comparison alone. Nickname changes follow status code 303 and related presence. Role and affiliation remain separate typed values.
- Each occupant retains occupant JID/nickname, role, affiliation, optional disclosed real JID, optional XEP-0421 Occupant ID, availability/status, and self flag. Occupant ID is preferred for cross-nickname association only when supplied by the room; its absence is represented honestly.
- Initial reflected presence constructs the room roster. Presence updates, unavailable/kick/ban/nickname transitions, subject, room errors, groupchat messages, and private occupant messages produce typed caller-thread events.
- Delayed messages received during entry are marked as MUC history, retain XEP-0203 metadata, and count against explicit history/result delivery limits. They are not treated as fresh messages for automatic receipts or transient state changes.
- On temporary loss, joined rooms become stale. On accepted XEP-0198 resumption, the module retains the candidate occupancy and performs XEP-0410 self-ping when the state is ambiguous. The exact self-ping result determines joined, rejoin, or failed behavior.
- On a fresh authenticated/bound session, rooms that were configured for recovery transition to rejoining and send new join presence; rooms not configured for recovery become failed/left explicitly. No code assumes old occupancy survived a new session.
- Implement the narrow XEP-0199 IQ responder and outgoing ping support required by XEP-0410. Timers and outstanding self-pings are bounded, session-owned, and cancelled on loss/leave.
- Room discovery uses the shared outgoing disco owner. This plan implements instant room creation only; reserved/custom room configuration, invitation workflows, moderation, affiliation administration, registration, and service administration remain outside scope.

### Replies, receipts, and chat states

- XEP-0461 parsing exposes reply `to` and referenced ID independently from the ordinary body. Sending a one-to-one reply requires an explicit reference selected by the caller.
- Sending a groupchat reply accepts only the room-assigned XEP-0359 stanza ID whose `by` equals the bare room JID. If that identity is absent, the typed groupchat reply operation fails rather than falling back to an origin/local ID that the room cannot authoritatively resolve.
- When requested, XEP-0428 reply fallback generation and parsing handles only the body ranges associated with `urn:xmpp:reply:0`. Preserve the wire body and expose semantic display body with valid fallback ranges removed. Reject invalid ranges without corrupting the body.
- XEP-0184 sending can request a receipt only when the message has an ordinary stanza ID. The module retains a bounded sent-message correlation set and surfaces received, duplicate, unknown, malformed, expired, and failed correlations deterministically.
- Automatic receipts default off. An explicit policy may enable them only for eligible newly received one-to-one content messages from acceptable senders. Groupchat requests are disabled by default, and no MAM, carbon, MUC-history, receipt, error, or otherwise ineligible message generates an automatic receipt.
- XEP-0085 uses a typed five-value state (`active`, `composing`, `paused`, `inactive`, `gone`). Applications decide when to send states; NexusXMPP does not infer human activity or add UI timers.
- Chat states may be combined with an ordinary message or sent as bodyless transient messages according to the XEP. Standalone state events are not delivered as durable conversation messages. Applicable groupchat handling is associated with a room/occupant context and does not mutate occupant presence.

### Carbons contract

- Expose typed enable and disable operations and the states disabled, enabling, enabled, disabling, failed, and unknown-after-loss.
- Enabling first verifies server support through shared discovery unless the caller explicitly requests a fresh attempt. IQ completion controls the state; no Boolean enqueue result is reported as successful activation.
- A fresh bound session re-enables carbons when the caller's desired state is enabled. An accepted stream resumption preserves the negotiated enabled state and does not issue a duplicate enable request.
- Parse sent/received wrappers through the shared forwarding decoder, validate authority/addressing, and surface a typed message retaining direction, wrapper, forwarded addressing, IDs, reply, receipt, chat-state, delay, and unknown extensions.
- Carbon content is never recursively passed through top-level stanza dispatch. It cannot independently trigger receipt generation or another carbon operation.

### MAM operation contract

- A MAM query returns an owned operation handle synchronously with its generated query ID. The operation records target archive JID, filter, requested page, limits, cancellation state, and final outcome.
- Query filters use only the in-scope XEP-0004 fields: `FORM_TYPE`, `with`, `start`, `end`, `before-id`, `after-id`, `ids`, and `include-groupchat` where allowed by the selected XEP revision/server. Timestamp serialization uses UTC XEP-0082 form.
- XEP-0059 request support covers bounded `max`, `before`, `after`, and last-page requests needed by MAM. The final result exposes `first`, optional first index, `last`, count, `complete`, and `stable` without inventing absent values.
- The ordinary IQ request manager owns the initiating IQ and final result/error/timeout. The MAM module owns the correlated intervening `<message><result queryid=...>` stream and its per-query state.
- Enforce configured maxima for concurrent MAM operations, requested page size, total accepted results, aggregate forwarded XML bytes, and forwarding depth. Capacity failure occurs before the query is transmitted.
- Each valid result produces a bounded incremental caller-thread event containing MAM query ID, MAM result ID, archive source/context, delay, and the decoded forwarded message. Optional accumulation, if implemented, uses the same limits and is disabled by default.
- Cancellation marks the operation terminal locally, releases owned capacity, suppresses later callbacks except the single cancellation completion, and ignores/diagnoses late results deterministically. XMPP provides no general wire cancellation for an already sent MAM query, so cancellation does not claim that the server stopped sending.
- The final IQ completes the operation only after earlier queued result events because the existing event queue preserves receive order. Results after final completion, duplicate result IDs, unknown query IDs, wrong archive senders, malformed forwards, limit overflow, timeout, transport loss, and permanent session loss have explicit tested outcomes.
- MUC archive queries target the room bare JID and apply the room's authority/identity rules. Retrieved results do not imply current room membership.

### Persistence and resource behavior

- All Phase 2 state is in memory and bounded: capabilities, room/occupant sets, pending receipt correlations, forwarded depth, MUC history, carbon state, MAM operations/results, and self-pings.
- Add explicit configuration limits with conservative defaults and validate them before connection. Prefer counts plus byte limits where retained raw XML dominates memory.
- A full new session clears session-authoritative data and explicitly rebuilds requested room/carbon state. Final disconnect releases every operation and retained stanza. No callback receives an object after its owner has freed it.
- The application remains responsible for conversation storage, deduplication across process restarts, UI presentation, AI participant behavior, and retry policy for semantically uncertain messages.

## Scope

Expected production changes are limited to `NexusLib/net/src/xmpp` and its public documentation:

- Extend `tpNXXMPPTypes.pas` or add focused `tpNXXMPPMessageTypes.pas`/`tpNXXMPPMUCTypes.pas` units as the single owners of shared enums, records, limits, and protocol identities. Do not alias or re-export those definitions from feature units.
- Extend `obNXXMPPConfig.pas` with validated Phase 2 capacities, timeouts, and explicit receipt/recovery defaults.
- Extend `obNXXMPPStanza.pas` and, if clearer, add one XMPP-owned retained-element helper for namespace-correct sibling/nested traversal and stanza cloning.
- Add a shared typed message model/parser and XEP-0297 forwarding decoder.
- Extend `obNXXMPPCommand.pas`, `obNXXMPPModule.pas`, `obNXXMPPClient.pas`, and `obNXXMPPConnection.pas` for the typed module command/session lifecycle contract and explicit replay policy.
- Extend `obNXXMPPEvents.pas` only with retained lifecycle/typed payload ownership needed by the modules; do not turn it into a generic event bus.
- Extend `obNXXMPPRequestManager.pas` only where synchronous operation identity or module-owned IQ initiation requires it. Keep single-final-IQ ownership there; do not move MAM result streaming into the generic request manager.
- Extend `obNXXMPPDisco.pas` for outgoing XEP-0030, narrow XEP-0115 support, and bounded capability caching.
- Extend `obNXXMPPOpenSSL.pas` only with the SHA-1 digest operation required by XEP-0115 capability verification. Do not expose SHA-1 as a preferred general cryptographic primitive.
- Add focused XMPP protocol units for data forms/RSM/date-delay helpers, XEP-0199 ping, MUC, receipts, chat states, carbons, and MAM. XEP-0359 and replies may remain shared message helpers rather than artificial stateful modules.
- Extend `NexusLib/net/tests/NexusNetXMPPTests.lpr` and add synthetic Phase 2 transcript fixtures under `NexusLib/net/tests/fixtures/xmpp` where file fixtures are clearer than inline strings.
- Extend `NexusLib/net/tests/NexusNetXMPPLiveTest.lpr` to create a unique instant room through the production MUC API before running the Openfire room scenario.
- Update `NexusLib/net/examples/xmpp/NexusXMPPConsole.lpr` only enough to demonstrate typed discovery, instant room creation, room join/message/leave, and event pumping without becoming a chat application.
- Update `NexusLib/net/tests/NexusNetXMPPTests.md`, `docs/architecture/dependencies.md`, and `docs/nexus-lib/index.md` with the implemented XEP baseline, maturity, limits, APIs, runtime behavior, build commands, and verified live boundary.

Exact unit grouping may be simplified during implementation when ownership remains explicit. Do not create one unit per XML element merely to mirror the XEP list.

## Out Of Scope

- Reserved/custom room configuration, owner/admin/moderator operations beyond the instant-room submission, registration, invitations, voice requests, kicking/banning, affiliation management, and service administration.
- Nexus-specific bots, commands, AI providers, agent orchestration, artifact transfer, or `urn:nexus:*` application protocols.
- A local message/archive database, cross-process capability cache, durable receipt store, conversation UI, search index, or generic persistence subsystem.
- OMEMO, OpenPGP, file transfer, HTTP upload, Jingle, PubSub, push notifications, reactions, corrections, retractions, message moderation, threads beyond XEP-0461 reply metadata, and unrelated XEP families.
- SASL2, Bind2, FAST, channel binding, TLS-provider modernization, WebSocket, BOSH, server-to-server XMPP, or component protocol.
- A general XML framework, generic streaming-query framework, generic event bus, alternate command queue, new transport abstraction, or socket access from feature modules.
- XEP-0115 cross-process persistence or legacy unverified capability caching. Its scope is only the verified feature advertisement/cache machinery needed by this phase.
- Automatic resend of application messages after rejected XEP-0198 resumption. Existing unrecoverable-work reporting remains authoritative.
- Claiming Prosody, ejabberd, public-server, MUC administration, or live forced-resumption interoperability without executing those checks.
- Copying implementation code from JOPL, Exodus, or another XMPP client library.

## Staged Implementation Plan

### Stage 1: Lock the protocol fixtures and shared retained XML contract

1. Add synthetic transcript fixtures for each selected XEP, including namespace-prefix variants, multiple extension siblings, unknown extensions, malformed recognized elements, nested forwarding, delayed MUC history, and multi-result MAM sequences.
2. Extend retained stanza traversal to enumerate direct children and bounded descendants by namespace URI/local name while preserving raw XML and DOM ownership.
3. Add cloning/retention tests proving typed data survives parser/framer advancement and does not depend on namespace prefix spelling.
4. Add XEP-0082 UTC parse/serialize, XEP-0203 delay parsing, narrow XEP-0004/0068 form parsing/building, XEP-0128 room-info parsing, and XEP-0059 request/result helpers.
5. Stop this stage if the selected namespace reconstruction cannot correctly represent nested declaration shadowing; correct the retained model before feature modules consume it.

### Stage 2: Establish shared identity, message, and forwarding models

1. Define the single source of truth for ordinary stanza ID, origin ID, a collection of `(by,id)` stanza IDs, receipt correlation, reply reference, delay, delivery context, MAM envelope IDs, and Occupant ID.
2. Parse message bodies and recognized Phase 2 sibling extensions without relying on whole-stanza `TextContent`; retain unknown elements.
3. Add secure synchronous origin/stanza ID allocation and reshape outgoing message construction to return the assigned values before enqueue.
4. Implement XEP-0461 parsing/building and context-dependent ID validation, including the room-assigned stanza-ID rule.
5. Implement the narrow XEP-0428 body-range parser/builder and separate wire body from fallback-stripped display body.
6. Implement the bounded XEP-0297 decoder and delivery-context wrapper without redispatch.
7. Verify invalid/duplicate identity elements, multiple legitimate `stanza-id` issuers, conflicting reply/fallback data, malformed dates, and forwarding depth/size boundaries.

### Stage 3: Add the bounded module command and lifecycle seam

1. Add one owned typed module-command variant to the existing queue and give registered modules a submitter that fails synchronously on queue saturation.
2. Add the narrow connection-thread session context for explicit-replay stanza send and existing-request-manager IQ initiation.
3. Pass the immutable registered module set to the connection for validated command targets and lifecycle notification; preserve client ownership and wait-for-thread destruction order.
4. Emit exact hooks for temporary loss, accepted resume, fresh bind, permanent failure, and final disconnect, plus retained caller-thread lifecycle outcomes where modules expose them publicly.
5. Remove replayability inference from raw XML prefixes and make all current client/module send paths choose an explicit policy.
6. Add deterministic tests for wrong/unregistered module targets, queue saturation, pre-online commands, lifecycle order, accepted resume versus fresh session, callback thread identity, replay-capacity failure before send, and teardown with pending module work.

### Stage 4: Extend discovery and narrow supporting modules

1. Add typed outgoing `disco#info` and `disco#items` requests, result models, exact reply-sender validation, and bounded session cache keyed by entity/node.
2. Add XEP-0115 advertisement parsing, canonical verification-string construction, mandatory SHA-1 calculation through `TNXXMPPOpenSSL`, hash validation, and verified in-memory cache reuse. Malformed/unverifiable/unsupported-hash caps fall back to explicit disco rather than trusted caching.
3. Register advertised feature namespaces from the frozen Phase 2 module set through the existing disco responder.
4. Add XEP-0199 incoming responder and typed outgoing ping through the common request/command seam.
5. Test eviction/expiry, new-session clearing, resumed-session preservation, duplicate/unknown features, multiple identities/forms, spoofed replies, invalid caps hashes, and IQ capacity failure.

### Stage 5: Add one-to-one message metadata features

1. Implement the receipt module with explicit default-off automatic policy, bounded sent correlation, ordinary stanza-ID rules, and context eligibility.
2. Implement typed XEP-0085 parsing/sending and ensure bodyless state stanzas produce transient state callbacks rather than durable message callbacks.
3. Connect typed reply/message sending to the new public message result contract and discovery advertisement.
4. Exercise combined message bodies, stable IDs, replies, fallback, receipt request/response, and chat state in different sibling orders with unknown extensions preserved.
5. Verify duplicates, unknown receipt IDs, malformed requests, groupchat default policy, and absence of automatic side effects for synthetic MAM/carbon/history contexts.

### Stage 6: Implement MUC participation and recovery

1. Add typed room, occupant, role, affiliation, error, status-code, join-history, and lifecycle state models.
2. Implement instant room creation/configuration plus join/leave/nickname/availability parsing and commands, including passwords, self-presence status 110, room-created status 201, conflicts, nick-change status 303, kick/ban outcomes, and structured room errors.
3. Implement room roster/state updates, groupchat/private messages, subject changes, XEP-0359 room identities, and XEP-0421 occupant identity.
4. Parse entry history as bounded `MUC history` delivery using XEP-0203 rather than live message delivery.
5. Connect temporary-loss, accepted-resume, fresh-session, and permanent-loss lifecycle hooks. Implement bounded XEP-0410 self-ping resolution and configured automatic rejoin only for a fresh session.
6. Test successful instant configuration, existing-room rejection, structured configuration failure, reordered reflected presence, missing optional metadata, duplicate occupants, nickname reuse, Occupant ID continuity/change, anonymous/non-anonymous JID exposure, unexpected room creation, history overflow, self-ping outcomes, and reconnect/resume distinction.

### Stage 7: Implement carbon activation and trusted delivery

1. Add typed enable/disable commands and IQ-controlled activation state through the module command/request seam.
2. Apply fresh-session re-enable and resumed-session retain rules.
3. Parse and validate sent/received carbon wrappers through the shared forwarding decoder and construct one typed carbon message with direction/context.
4. Preserve all shared message metadata and unknown extensions while suppressing recursive dispatch and automatic receipt/state side effects.
5. Test spoofed outer senders, wrong wrapper direction, missing/multiple forwards, nested carbon/MAM wrappers, duplicated delivery, activation failure, queue/IQ capacity, reconnect, resume, and disable.

### Stage 8: Implement bounded MAM streaming

1. Add the per-query operation owner, synchronous query ID, typed filters, RSM request, concurrent-operation capacity, and caller cancellation.
2. Register a narrow MAM-result observer keyed by namespace/query ID while leaving final IQ correlation in the request manager.
3. Decode valid results through the shared forwarding/message pipeline and enqueue incremental typed results in receive order.
4. Parse final `fin`/RSM metadata, enforce final sender/query matching, and produce exactly one terminal completion.
5. Enforce result count, aggregate bytes, page size, forwarding depth, and optional accumulation limits before retaining additional data.
6. Test results followed by final IQ, empty pages, forward/backward/last pages, personal and MUC targets, duplicates, out-of-order/unknown/late results, malformed forwarding/delay/RSM, cancellation, timeout, transport loss, queue pressure, and limit exhaustion.

### Stage 9: Integrate, document, and verify controlled Openfire behavior

1. Register all Phase 2 modules together and test responder keys, observer predicates, message ownership, callback ordering, and absence of duplicate processing.
2. Extend the minimal console example only with typed discovery, instant room creation, room join/message/leave, and diagnostic display needed for manual inspection.
3. Extend the live test with environment-selected Phase 2 scenarios. Use unique resources and create a unique instant room through the public MUC API; keep the MUC service and optional nick overrides outside source.
4. Exercise Openfire-supported discovery, MUC participation between the two temporary users, stable IDs/replies/receipts/chat states, carbons using multiple resources, and MAM paging where the installed configuration advertises each feature.
5. Record the exact Openfire version, enabled plugins/configuration, tested feature namespaces, room preparation, successful and negative cases, and all unverified behavior. Do not infer support from server brand or a successful basic login.
6. Update public documentation with API ownership/lifetimes, limits, XEP revisions/statuses, experimental-feature warning, session recovery semantics, build/test instructions, and the absence of local persistence/application policy.
7. Perform a final architecture inspection for socket ownership, queue bounds, replay classification, retained data, module lifetime, forwarded trust, and caller-thread callbacks before acceptance.

## Sub-Agent Delegation

Implementation remains local to the primary Codex process. The human owner has not requested sub-agent use. Neither approval of this plan nor later implementation authorization permits delegation or parallel sub-agent work.

## Verification Plan

### Clean compilation

Use the current explicit FPC command and keep all generated output under `output/`:

```powershell
fpc -B -FuNexusLib\net\src\xmpp -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetXMPPTests\units -FEoutput\NexusNetXMPPTests\bin NexusLib\net\tests\NexusNetXMPPTests.lpr
```

Compile frequently after structural stages. At completion run a clean `-B` rebuild of the deterministic tests, live-test target, and console example using equivalent isolated output paths. Do not report stale-unit success.

### Deterministic automated coverage

Run `output\NexusNetXMPPTests\bin\NexusNetXMPPTests.exe` with the documented OpenSSL 3 runtime path and preserve all Phase 1 tests. Add focused coverage for:

- QName-correct sibling/nested extension traversal, namespace shadowing/prefix changes, unknown extensions, clone/ownership, malformed recognized extensions, and size/depth limits;
- every distinct identity and issuer scope, multiple stanza IDs, synchronous origin/stanza ID allocation, secure uniqueness, queue rejection, and retained copying;
- XEP-0082 timestamps, XEP-0203 delays, XEP-0004/0068 forms, XEP-0128 room data, and XEP-0059 request/result edges;
- module command capacity/ownership/threading, explicit replay policy, session lifecycle order, resumed versus fresh session, and terminal cleanup;
- outgoing disco info/items, cache keys/limits/expiry, XEP-0115 verification, spoofed/malformed responses, and frozen feature advertisement;
- XEP-0461 one-to-one/MUC correct-ID rules, XEP-0428 Unicode body ranges, invalid fallback, raw/display body separation, and forwarded replies;
- XEP-0184 eligibility, ordinary stanza-ID correlation, manual/default-off automatic policy, duplicate/unknown/malformed/expired receipts, and suppression for MAM/carbon/history/groupchat defaults;
- all five XEP-0085 states, bodyless transient delivery, combined message/state, repetition/context rules, MUC association, and no conversation-message duplication;
- MUC state transitions, status codes, roles/affiliations, self-presence, nick conflict/change, kick/ban/error, participant identity, subject, private/groupchat message, entry history, limits, self-ping, rejoin, resume, and session loss;
- carbon activation/disable/reconnect/resume, valid sent/received context, authority validation, spoofing, nested/malformed forwarding, metadata preservation, and no redispatch;
- MAM filters, query/result IDs, personal/MUC authority, incremental ordering, RSM pages, final completion, cancellation, late/unknown/duplicate/malformed results, timeout/loss, and every configured bound;
- all modules registered together without responder collision, duplicate callbacks, thread violations, leaked operations, or changes to Phase 1 XEP-0198 behavior.

Tests remain transcript/pure-object/loopback based by default. They do not depend on public DNS or a live server.

### Focused inspection

Review every match from focused searches such as:

```text
rg -n "SendModuleXML|\.Send\(|FTransport\.(Send|Receive|Connect|Secure|Close)" NexusLib\net\src\xmpp
rg -n "xckModule|Replay|Lifecycle|Session" NexusLib\net\src\xmpp
rg -n "origin-id|stanza-id|received|reply|chatstates|forwarded|carbons|mam:2|muc#user|occupant-id" NexusLib\net\src\xmpp
rg -n "NexusUI|NexusTools|NexusSchema|NexusLS|urn:nexus" NexusLib\net\src\xmpp NexusLib\net\tests\NexusNetXMPPTests.lpr
rg -n "TObjectList\.Create\(False\)|TList\.Create|TStringList\.Create" NexusLib\net\src\xmpp
```

Confirm by inspection, not grep absence alone, that:

- only the connection owner touches the socket;
- every cross-thread payload owns its data and every queue/operation/cache has a limit;
- no forwarded stanza is redispatched as live top-level traffic;
- automatic receipts cannot originate from carbon, MAM, or room-history delivery;
- a new bound session and an accepted XEP-0198 resume invoke different module behavior;
- all distinct protocol IDs remain distinct through every wrapper;
- application callbacks occur only through caller-thread pumping.

### Controlled Openfire verification

Build the live target with the documented FPC paths. Supply accounts, passwords, CA file, endpoint, optional MUC service, nicknames, and selected scenario through `NEXUS_XMPP_*` environment variables; never commit credentials. The target generates unique resources and a unique room node.

For each Openfire-advertised feature:

1. verify outgoing disco and retain the exact advertised namespace;
2. create and configure a unique instant room through `TNXXMPPMUCModule`, join the second user, and verify self/occupant lifecycle, room message, reply, subject, history classification, nickname change, and leave;
3. verify receipts/chat states in eligible one-to-one traffic and their negative contexts;
4. enable carbons and use two distinct resources for one account to verify sent/received direction and disable/reconnect behavior;
5. issue bounded personal and room MAM queries and verify query IDs, streamed results, delay/stable IDs, RSM completion, cancellation/late-result behavior where controllable;
6. exercise new-session room rejoin and, only when a controllable interruption can produce accepted XEP-0198 resumption, test retained carbon/room state and self-ping behavior.

Record unsupported plugins/features as unavailable, not failed library behavior. Continue to describe basic Phase 1 interop separately from any Phase 2 or accepted-resumption result.

### Documentation and acceptance evidence

- Update `NexusNetXMPPTests.md` with exact clean-build commands, deterministic result, Openfire version/configuration, room preparation, certificate fingerprint boundary, feature advertisements, and scenario outcomes.
- Update dependency and NexusLib documentation with every implemented XEP revision/status and any intentionally unimplemented optional branch.
- Report warnings separately from failures and identify any live scenario not run.
- Before final implementation reporting, create the architecture checkpoint archive required by `.ai/protocols/architecture-change.md` using `scripts\New-NexusSourceArchive.ps1` and verify that new production/test/documentation files are included.

## Risks And Questions

- **Experimental specifications:** XEP-0359, XEP-0461, and XEP-0428 may change. Keep namespace/version behavior isolated in their parser/builders and document the selected revision; do not add compatibility modes without a demonstrated peer requirement.
- **FPC DOM namespace loss:** Phase 2 depends on correct multiple/nested QName handling. A partial first-child extension of the current workaround is unacceptable; namespace shadowing must be proven before protocol parsing proceeds.
- **Module state crosses two threads:** lifecycle/dispatch work occurs on the connection thread while public reads and callbacks occur on the pump thread. State owners need explicit locking or owned event transfer, not incidental reliance on timing.
- **Event pressure:** one network stanza may yield a raw callback plus typed module callback, but it must consume a predictable bounded event representation rather than fan out into unbounded queued objects. MAM aggregate byte/count limits must be enforced before event creation.
- **Identifier trust:** origin IDs are sender claims, stanza IDs are authoritative only within the stated `by` scope, receipt IDs refer to ordinary stanza IDs, MAM result IDs belong to the archive result, and Occupant IDs belong to the room. APIs and tests must not silently promote one authority into another.
- **Duplicate delivery:** XEP-0198 replay, carbons, MAM, and live traffic can expose the same logical message through different paths. NexusXMPP preserves identities and context so applications can deduplicate; it does not promise universal deduplication when authoritative IDs are absent.
- **Receipt privacy:** automatic receipts reveal resource activity. Default-off policy and eligibility checks are part of the library contract, not merely application advice.
- **MUC ambiguity:** successful stream resumption does not prove room occupancy survived a room service/component interruption. XEP-0410 is therefore included narrowly; inconclusive results remain explicit rather than being labeled joined.
- **Openfire configuration:** MAM, carbons, Occupant IDs, reply/stanza IDs, and room history depend on server/plugin/configuration support. The live pass must begin with discovery and document absence precisely.
- **Capability cache authority:** raw advertised features and verified XEP-0115 capability nodes are not equivalent. Cache state stays bounded and in memory, and unverified hash data never becomes trusted shared capability state.
- **XEP-0115 SHA-1 requirement:** the selected Stable revision still makes SHA-1 mandatory for capability verification. Its use is isolated to matching a peer's advertised verification string through the existing OpenSSL adapter and is not authorization to weaken TLS, SASL, identifiers, or any other cryptographic policy.
- **MAM cancellation:** cancellation is local because the selected protocol has no general cancel stanza for an outstanding query. Late network results may still arrive and must be ignored/diagnosed within bounded processing.
- **API reshaping:** `SendMessage: Boolean` cannot satisfy immediate identity and receipt-correlation requirements. This plan intentionally replaces that shape and updates the console/live/test call sites; no legacy wrapper is retained without a verified external integration.
- **Live recovery control:** deterministic transcript tests are authoritative for every lifecycle branch. A live accepted-resumption/self-ping scenario is reported only if the local Openfire environment can force and observe it reliably.

No unresolved product choice blocks approval. Optional bounded accumulation of MAM results may be omitted in favor of the required incremental interface. MUC Self-Ping is selected because the requested recovery contract otherwise cannot resolve ambiguous retained occupancy. Automatic receipts are selected as disabled by default. Any materially different policy requires owner review before implementation.

## Approval Gate

This document is a planning artifact only. No Phase 2 code edit, build, test, live connection, archive, dependency change, or implementation repository operation begins until the human owner explicitly authorizes implementation of this plan.

Approval plus the 2026-09-03 owner amendment authorizes only the scoped NexusXMPP Phase 2 work above, including instant room creation. It does not authorize application integration, broader MUC administration, persistent message storage, Phase 3 authentication work, unrelated XEPs, or sub-agent use.
