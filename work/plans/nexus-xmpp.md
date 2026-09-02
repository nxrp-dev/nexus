# Work Plan: NexusXMPP Client Protocol Library

## Inputs

- Source request: the owner's request for an implementation work plan based on the completed NexusXMPP design discussion.
- Authoritative design input: `C:\Users\kcollins\Downloads\nexus-xmpp-design-final.md`.
- Related discussion/review notes:
  - NexusXMPP is a dedicated client-to-server XMPP library, not a generic messaging framework.
  - Synapse remains the socket/TLS/DNS dependency; NexusXMPP owns XMPP stream framing, negotiation, stanza models, dispatch, and session behavior.
  - A dedicated connection thread owns the socket, parser, and connection state.
  - Application callbacks are delivered only through bounded event pumping on the caller's thread.
  - The initial implementation must prove parser, Unicode/JID, cryptography, TLS, and shutdown behavior before feature breadth is added.
- Existing constraints:
  - Follow repository `AGENTS.md`, `NexusLib/net/AGENTS.md`, `.ai/standards/pascal.md`, and `.ai/protocols/architecture-change.md`.
  - Keep protocol parsing, transport, and session orchestration separated according to their distinct failure modes.
  - Do not add dependencies on NexusUI, either language server, NexusSchema, or project-specific applications.
  - Do not silently fall back to `TSSLNone` or accept an unverified TLS peer.
  - Treat the final design as the target architecture, subject to demonstrated toolchain limitations discovered by the proof gates below.
  - This plan covers the foundational implementation and Phase 1 of the design. Phase 2 messaging extensions and Phase 3 authentication modernization are separate follow-on work.

## Summary

Add a new `NexusLib/net/src/xmpp` subsystem implementing an RFC-based XMPP client library on top of Synapse. The library will expose a small client facade while keeping endpoint discovery, transport security, stream negotiation, stanza parsing, request correlation, extension dispatch, and application event delivery in explicit owners.

The work begins with production-directed proof slices, not broad feature implementation. Those slices must establish that the selected FPC XML reader can safely consume XMPP's long-lived stream, that a suitable standards-compliant JID/Unicode path and SCRAM primitive provider are available, that Synapse OpenSSL 3 can enforce the required TLS identity checks, and that a blocked connection can be shut down deterministically. A failed proof gate stops the implementation for a design or dependency decision rather than causing an unplanned custom parser, cryptographic implementation, or unsafe fallback.

After those gates pass, implement the Phase 1 client core: JIDs, framing and stanzas, endpoint discovery, TLS, classic SASL with SCRAM and policy-controlled PLAIN, resource binding, message/presence/IQ dispatch, request correlation, service discovery, roster support, and XEP-0198 stream management. Deliver a standalone deterministic test project and a minimal console client for explicit live interoperability testing.

## Verified Findings

- `NexusLib/net` currently contains only the torrent subsystem. NexusXMPP can be added as a sibling protocol without reshaping or depending on torrent implementation classes.
- `NexusLib/net/AGENTS.md` already defines the correct library boundary: transport, protocol parsing, storage, and session orchestration remain separated, and normal tests are deterministic rather than live-network dependent.
- `NexusLib/net/tests/NexusNetTorrentTests.lpr` demonstrates the current lightweight convention for a standalone networking test executable with local assertions and loopback socket coverage.
- The bundled Synapse dependency already supplies:
  - `TTCPBlockSocket` in `lib/synapse/blcksock.pas`;
  - SRV record querying and decoding in `lib/synapse/dnssend.pas`;
  - an OpenSSL 3 implementation in `lib/synapse/ssl_openssl3.pas`.
- Synapse does not make TLS safe by default:
  - the socket-level SSL implementation defaults to `TSSLNone`;
  - certificate verification defaults to disabled;
  - the OpenSSL 3 wrapper dynamically loads its libraries and can therefore be unavailable at runtime.
- The OpenSSL 3 wrapper has host-name verification/SNI-related support, but no complete ALPN or channel-binding/exporter surface was found. Those capabilities must be measured before Phase 3 is planned; Phase 1 must not depend on them.
- FPC XML units are already used elsewhere in the repository, but no reusable NexusLib streaming-XML layer exists. NexusXMPP should integrate `fcl-xml` directly if the framing proof succeeds.
- `NexusTools/Schema/src/obXMLObjects.pas` is persistence-oriented and is not an XMPP parser or suitable dependency for this library.
- Repository inspection found SHA-1 usage for torrent identity and Base64 helpers, but did not establish a complete provider for SHA-256, HMAC, PBKDF2, cryptographically secure random bytes, constant-time comparison, PRECIS, or IDNA. The implementation must resolve this through the dependency gates rather than infer availability.
- `docs/architecture/dependencies.md` documents NexusLib as the shared base layer and directs module-specific behavior to remain in its owning module.
- The requested `TNXXMPPClient.PumpEvents` parameter follows the Pascal standard as `AMaxCount`, not `aMaxCount`.

## Architecture Problem

XMPP is not a sequence of independent XML documents over a socket. It is a long-lived, restartable XML stream whose transport, TLS, authentication, resource binding, stanza exchange, and optional stream resumption alter one another's legal states. Treating it as a thin socket wrapper would distribute state and ownership across callers, allow callbacks from a transport thread, and make shutdown and recovery nondeterministic.

The security-sensitive dependencies also have unresolved capability boundaries. Synapse exposes SSL support but does not enable or verify it by default. FPC XML support exists but has not yet been proven against XMPP stream framing and restarts. The repository does not visibly contain all Unicode/JID and SCRAM primitives required by the standards. Building feature modules before resolving those foundations would make later corrections invasive and could create false security guarantees.

The corrective architecture is therefore one XMPP-owned session engine with explicit state, single-threaded transport ownership, bounded cross-thread queues, immutable queued values, and narrow extension points. Standards and provider gaps are proof gates, not places for speculative abstractions or silent degradation.

## Target Contract

### Owner

`NexusLib/net/src/xmpp` owns all reusable NexusXMPP client protocol behavior.

The minimal console client under `NexusLib/net/examples/xmpp` owns only configuration, credential input, event pumping, and display. It must not become a second protocol implementation.

### Responsibilities

- `TNXXMPPClient` is the public facade. It owns configuration, the immutable connected module set, the connection worker, outgoing command submission, and caller-thread event delivery.
- `TNXXMPPConnection` owns the dedicated connection thread's socket, parser, protocol state machine, reconnect/resumption activity, and terminal failure transition.
- The endpoint resolver converts a logical XMPP service identity into ordered direct-TLS and STARTTLS connection candidates using `_xmpps-client._tcp` and `_xmpp-client._tcp` SRV records plus standards-defined fallback. The original service identity remains the TLS identity; an SRV target never replaces it.
- The transport layer owns exact socket reads/writes, TLS activation, timeouts, and the dedicated shutdown wake path. It does not parse stanzas or dispatch modules.
- The stream framer owns byte-level XMPP stream boundaries and resource limits. It passes complete XML fragments to the selected XML reader and never grows an unbounded document tree for the entire connection.
- Stanza objects own retained, independently usable XML data. Queued stanzas and error/event payloads cannot reference parser buffers or connection-owned mutable state.
- The dispatcher distinguishes exclusive IQ responders from observers:
  - an IQ responder is registered by exact `(IQ type, child QName)` and only one responder may own a key;
  - observers may be multiple and may use explicit predicates;
  - an unhandled `get` or `set` IQ receives the required error response rather than disappearing silently.
- The request manager assigns and correlates IQ IDs, validates permitted reply senders, applies timeouts, cancels pending work on terminal disconnect, and enqueues completion to `PumpEvents`.
- SASL code owns mechanism selection and exchanges but consumes cryptographic primitives from an identified provider. Password policy, plaintext-transport prohibition, and channel security decisions are not delegated to feature modules.
- XMPP extension modules register their responders/observers before connection. The module set is frozen from connection start through final disconnect.
- Stream management owns sequence counters, acknowledgement, replay eligibility, and resumption state. It cannot replay application operations whose semantics are not safe to repeat.

### State Flow

The connection uses one explicit state machine with legal transitions enforced in one owner:

1. `Disconnected`: configuration and module registration are allowed.
2. `Resolving`: produce ordered endpoint candidates without changing the logical service identity.
3. `Connecting`: establish the TCP socket on the connection thread.
4. `Securing`: perform direct TLS or STARTTLS and require successful provider loading, trust validation, host/service identity validation, and negotiated policy.
5. `Authenticating`: select and run an allowed classic SASL mechanism.
6. `Binding`: restart the stream when required and bind a resource.
7. `Online`: dispatch stanzas, requests, events, discovery, roster, and stream-management traffic.
8. `Resuming`: attempt XEP-0198 resumption only when prior state and policy permit it.
9. `Closing`: stop accepting ordinary commands, wake blocking I/O through the dedicated control path, drain/cancel owned work, and release the socket on its owning thread.
10. `Failed`: preserve one structured terminal error, fail pending requests, publish the fatal event if possible, and proceed to deterministic cleanup.

Illegal public operations fail explicitly. A disconnect request remains available even if the ordinary outgoing queue is full.

### Queue And Event Behavior

- The outgoing application-command queue and incoming application-event queue have explicit finite capacities configured before connection.
- If the outgoing queue is full, the public send/request operation fails without transmitting a partial command.
- If the pending-IQ limit is full, a new IQ request fails before bytes are transmitted.
- If the event queue cannot accept an event, the connection enters a controlled fatal state. It must not silently lose protocol-significant events or block forever waiting for the application.
- Shutdown uses a separate wake/control mechanism and cannot depend on capacity in the ordinary outgoing queue.
- `TNXXMPPClient.PumpEvents(AMaxCount = 100)` dispatches at most the requested number of events on the caller's thread and returns promptly.
- User callbacks never execute on the connection thread.

### Parsing And Security Behavior

- XMPP owns byte framing; `fcl-xml` owns namespace-aware XML interpretation after a proof test demonstrates safe integration.
- Reject DTDs, external entities, unsupported processing instructions, excessive nesting, oversized stream openings, and oversized stanzas before they can exhaust memory or trigger external access.
- Preserve qualified names and namespace identity. Dispatch never relies on prefix spelling.
- JID processing follows RFC 7622 as updated by RFC 9844, including correct localpart/resourcepart preparation and domain IDNA handling. Case behavior follows the applicable profile for each part rather than a repository-wide text shortcut.
- TLS selection is explicit. Provider load failure, missing trust roots, certificate failure, service-identity mismatch, downgrade, and required-ALPN failure are fatal and structured.
- Classic SASL Phase 1 supports SCRAM mechanisms justified by the available provider and published test vectors. PLAIN is available only when explicitly permitted and only over an authenticated secure channel.
- Credentials, SCRAM intermediate secrets, and TLS diagnostic text are excluded from ordinary logs and exception messages.

### Persistence Behavior

- Phase 1 keeps credentials and resumable-session data in memory only.
- No credential vault, cross-process token store, account database, or durable XEP-0198 store is introduced.
- Stanza and event values retain only the data required by the application; parser trees and sensitive negotiation material are released as soon as their owner no longer needs them.

## Scope

Expected additions and narrowly related changes are:

- `NexusLib/net/src/xmpp/AGENTS.md`
  - reference `.ai/standards/pascal.md` and `NexusLib/net/AGENTS.md` explicitly;
  - record the XMPP thread, ownership, parsing, and security boundaries.
- `NexusLib/net/src/xmpp/`
  - shared XMPP types, errors, configuration, and connection state;
  - JID parsing/preparation;
  - byte stream framing and retained stanza models;
  - endpoint discovery and ordering;
  - transport/TLS integration;
  - dispatcher, module base, and IQ request manager;
  - SASL negotiation, stream negotiation, binding, and connection/client owners;
  - Phase 1 modules for message, presence, roster, service discovery, and stream management.
- `NexusLib/net/tests/NexusNetXMPPTests.lpr` and, if needed for repeatable Lazarus configuration, `NexusNetXMPPTests.lpi`.
- `NexusLib/net/tests/fixtures/xmpp/`
  - synthetic XML stream/transcript fixtures;
  - published standards vectors represented locally with source citations;
  - synthetic local TLS certificates and keys used only by loopback tests.
- `NexusLib/net/examples/xmpp/`
  - a minimal console client and project file for explicit live testing after automated tests pass.
- `docs/architecture/dependencies.md` and `docs/nexus-lib/index.md`
  - document the new subsystem, external runtime dependencies, security expectations, and build/test entry points.
- Bundled Synapse units only if a proof gate demonstrates a small missing hook required by an in-scope Phase 1 contract. Any such change must remain a narrowly reviewed Synapse integration change, not a general fork redesign.

Likely production units include `tpNXXMPPTypes.pas`, `obNXXMPPError.pas`, `obNXXMPPJID.pas`, `obNXXMPPStreamFramer.pas`, stanza model units, `obNXXMPPEndpointResolver.pas`, `obNXXMPPDispatcher.pas`, `obNXXMPPRequestManager.pas`, `obNXXMPPSASL.pas`, `obNXXMPPModule.pas`, `obNXXMPPConnection.pas`, and `obNXXMPPClient.pas`. Exact unit grouping may be simplified during implementation when responsibilities remain clear; the plan does not require one class per unit.

## Out Of Scope

- Server-to-server XMPP, component protocol, server implementation, federation, and XMPP-over-WebSocket/BOSH.
- A generic transport abstraction or replacement networking framework.
- A new general-purpose XML parser, DOM, Unicode library, cryptography suite, DNS stack, or threading framework.
- MUC, delivery receipts, chat states, stable/origin IDs, replies, carbons, and message archive management. These are Phase 2 modules after the Phase 1 core is proven.
- SASL2, Bind2, channel binding, FAST, and related modernized authentication work. These are Phase 3 and depend on verified TLS-provider capabilities.
- File transfer, Jingle, pubsub, OMEMO, push notifications, and broad XEP coverage.
- Durable credential storage, account UI, cross-process stream-resumption persistence, or integration into a specific Nexus application.
- Refactoring the existing torrent subsystem or moving Synapse into another library.
- Claiming interoperability with a server that was not actually tested.
- Copying JOPL or another XMPP library's implementation. External implementations may inform behavior and test cases only where license and provenance are clear.

## Staged Implementation Plan

### Stage 1: Establish The Test Harness And Resolve Foundation Gates

1. Add the XMPP folder instructions and a standalone XMPP test executable that compiles without application dependencies.
2. Add small production-directed probes, retained as focused tests or the first production implementation, for:
   - byte framing of an XMPP stream opening followed by multiple stanzas and a stream restart;
   - namespace-aware `fcl-xml` parsing of each framed element without external entity or DTD access;
   - OpenSSL 3 provider selection, runtime load detection, trust loading, SNI, and service host validation on a loopback TLS peer;
   - interruption of a blocked Synapse read by the proposed connection-owner shutdown mechanism;
   - availability and correctness of the required Unicode/PRECIS/IDNA and SCRAM primitives.
3. Record each provider and its license/runtime requirements in dependency documentation.
4. Apply hard gates:
   - If `fcl-xml` cannot consume the framed XMPP elements and stream restarts safely, stop and present the demonstrated limitation before proposing a custom parser.
   - If no acceptable PRECIS/IDNA provider exists, stop for a dependency decision. Do not substitute ASCII-only behavior and call it RFC-compliant.
   - If no acceptable HMAC/PBKDF2/CSPRNG/constant-time provider exists, stop for a dependency decision. Do not create ad hoc cryptography under this plan.
   - If OpenSSL 3 cannot enforce Phase 1 certificate and service-identity requirements through a narrow integration, stop before authentication work.

### Stage 2: Implement Core Values, Limits, Framing, And Stanzas

1. Define configuration, connection states, structured errors, queue limits, stanza limits, timeout policy, and immutable event/result types.
2. Implement `TNXXMPPJID` with separate localpart, domainpart, and resourcepart processing and round-trip/string comparison tests derived from the relevant standards.
3. Implement the incremental byte framer:
   - recognize the stream opening and closing boundaries;
   - emit complete top-level stanzas across arbitrary network chunk boundaries;
   - enforce total, nesting, and stanza-size limits;
   - reject prohibited XML constructs before XML interpretation.
4. Convert complete fragments into namespace-aware retained stanza objects for message, presence, and IQ while keeping unknown extension children available by QName.
5. Add hostile chunking, malformed UTF-8, namespace, oversized input, and ownership/lifetime tests before socket integration continues.

### Stage 3: Implement Dispatch And IQ Correlation Without A Socket

1. Add the immutable-before-connect module registry.
2. Implement exact exclusive IQ responder registration and multiple predicate observers.
3. Implement ID allocation, pending-request capacity, reply-sender validation, deadlines, cancellation, and queued completion.
4. Add generic required error replies for unhandled `get`/`set` IQ requests.
5. Test duplicate registration, ambiguous observations, unknown responses, spoofed sender responses, timeout order, cancellation, and event ownership entirely in memory.

### Stage 4: Implement Pure Stream Negotiation And SASL Transcripts

1. Model stream opening, advertised features, STARTTLS restart, SASL selection/exchange, post-authentication restart, resource binding, and online transition as explicit inputs and outputs independent of the socket.
2. Implement classic SASL mechanisms supported by the approved primitive provider, prioritizing SCRAM-SHA-256 and adding other classic SCRAM variants only when justified by interoperability requirements.
3. Keep PLAIN disabled by default and make its secure-channel and explicit-policy prerequisites executable conditions.
4. Validate SCRAM against published vectors and add negative transcripts for nonce mismatch, iteration policy, invalid proof, malformed server data, and server-signature mismatch.
5. Assert all legal state transitions and prove that malformed or out-of-order features fail with structured errors.

### Stage 5: Add The Connection Thread, Bounded Queues, And Shutdown

1. Implement the dedicated connection owner around `TTCPBlockSocket`.
2. Add the bounded caller-to-connection command queue and connection-to-caller event queue with the specified failure rules.
3. Add the independent shutdown wake/control path proven in Stage 1.
4. Wire parsing, negotiation, dispatch, request correlation, and event creation on the connection thread.
5. Implement `PumpEvents(AMaxCount = 100)` with caller-thread callback delivery and bounded work.
6. Test queue saturation, concurrent disconnect, blocked read interruption, callback thread identity, object lifetime, pending-request cancellation, and repeated connect/disconnect destruction cycles.

### Stage 6: Add Endpoint Discovery And TLS Transport

1. Wrap Synapse SRV querying in the XMPP endpoint resolver; do not create a second DNS stack.
2. Implement RFC-compliant priority/weight ordering, direct-TLS and STARTTLS service names, no-service results, explicit port overrides, and host/port fallback.
3. Make selection deterministic under a seeded test source while retaining correct weighted behavior in production.
4. Implement direct TLS and STARTTLS flows with explicit OpenSSL 3 selection, runtime availability checks, trust roots, SNI, and verification against the original XMPP service identity.
5. Never continue in plaintext after TLS was requested or required. Never treat an SRV target as the certificate identity.
6. Add loopback tests for a trusted certificate, unknown issuer, wrong identity, expired/not-yet-valid certificate where supported by fixtures, absent provider, and attempted downgrade.

### Stage 7: Complete Authentication, Binding, And The Public Client Facade

1. Connect endpoint selection, transport security, pure negotiation, SASL, resource binding, dispatcher, and request manager through the explicit state machine.
2. Freeze configuration and module registration at connection start and restore mutability only after final disconnect.
3. Expose narrowly scoped public operations for connect, disconnect, send message/presence, send IQ request, and pump events.
4. Return structured failures with stage, condition, recoverability, and safe diagnostic text.
5. Add transcript-backed loopback sessions for successful STARTTLS and direct-TLS connections, authentication failure, bind failure, clean close, abrupt close, and reconnect policy.

### Stage 8: Add Phase 1 Protocol Modules

1. Implement RFC 6121 message and presence behavior needed by the client facade.
2. Add roster retrieval, push handling, subscription-state events, and required roster-push acknowledgements.
3. Add XEP-0030 service discovery through the common IQ dispatcher.
4. Add XEP-0198 stream management:
   - enable/acknowledge counters;
   - maintain a bounded replay set;
   - separate replayable protocol stanzas from unsafe application operations;
   - resume only when the server identity, session token, time window, and local state agree;
   - fail or surface unrecoverable pending work explicitly when resumption is rejected.
5. Add deterministic transcript tests for each module and for extension coexistence through the dispatcher.

### Stage 9: Deliver Console Interoperability And Documentation

1. Add a minimal console client that configures one account, registers the Phase 1 modules, connects, pumps events, sends basic stanzas, and shuts down cleanly.
2. Keep credentials out of source, command history where practical, test fixtures, and normal logs.
3. Run explicit live interoperability checks against a locally controlled server, beginning with one supported Prosody, ejabberd, or Openfire configuration. Record the exact server/version/configuration actually tested.
4. Test the other named servers when available; report them as unverified rather than blocking deterministic library completion if the environments are unavailable.
5. Update dependency and NexusLib documentation with supported standards, runtime OpenSSL requirements, build/test commands, known capability boundaries, and the explicit Phase 2/Phase 3 exclusions.
6. Perform an architecture pass for ownership, shutdown, error propagation, security defaults, bounded memory, module isolation, and absence of application dependencies before requesting acceptance.

## Sub-Agent Delegation

Implementation remains local to the primary Codex process. The human owner has not requested sub-agent use, and neither approval of this plan nor later implementation approval authorizes delegation.

## Verification Plan

### Compilation

Add repeatable Lazarus project metadata or use an equivalent explicit FPC invocation with all output under `output/`. The expected primary commands are:

```text
lazbuild -B NexusLib\net\tests\NexusNetXMPPTests.lpi
lazbuild -B NexusLib\net\examples\xmpp\NexusXMPPConsole.lpi
```

If the test project intentionally remains an `.lpr`-only target, document and run the complete `fpc` command, including `NexusLib/net/src/xmpp`, bundled Synapse, `fcl-xml`, crypto-provider, unit-output, and binary-output paths. Do not rely on an undocumented IDE search path.

Compile after every structural stage. Verify a clean `-B` rebuild at the end; do not report success from stale units.

### Automated Tests

The standalone XMPP test executable must cover at least:

- JID parsing, serialization, comparison, Unicode preparation, IDNA, prohibited code points, IPv6 domain literals, empty/optional parts, and maximum UTF-8 octet lengths;
- stream opening/closing, restart, every-byte chunk boundaries, multiple stanzas per chunk, namespace scope, malformed UTF-8/XML, DTD/entity rejection, nesting limits, and stanza-size limits;
- retained stanza and event lifetime after parser buffers advance or the connection is destroyed;
- dispatcher responder uniqueness, observer predicates, unknown extensions, and required unhandled-IQ errors;
- IQ IDs, permitted reply senders, spoofed/unknown replies, pending capacity, timeouts, cancellation, and completion only through event pumping;
- legal and illegal protocol-state transitions through TLS, SASL, binding, online, closing, failure, reconnect, and resumption;
- published SCRAM vectors and negative authentication transcripts;
- SRV priority/weight behavior, fallback, no-service records, explicit endpoints, and preservation of the logical TLS identity;
- OpenSSL provider absence, trust success/failure, wrong identity, validity failure where fixture support permits it, STARTTLS downgrade, and direct TLS;
- bounded outgoing/event/pending-IQ queues, fatal event overflow, non-blocking public failure, shutdown while queues are full, and blocked-read interruption;
- caller-thread callback delivery, bounded `PumpEvents`, and repeatable connect/disconnect/destruction;
- roster, discovery, message/presence, and XEP-0198 transcripts including acknowledgement counters and accepted/rejected resumption.

Tests must use loopback or pure transcripts by default. External DNS and live public servers are not part of the automated pass.

### Focused Greps And Inspection

Run focused repository checks to confirm:

```text
rg -n "TSSLNone|VerifyCert|SSLImplementation" NexusLib\net\src\xmpp
rg -n "NexusUI|NexusTools|NexusSchema|NexusLS" NexusLib\net\src\xmpp NexusLib\net\tests\NexusNetXMPPTests.lpr
rg -n "Synchronize|QueueAsyncCall|Application\.ProcessMessages" NexusLib\net\src\xmpp
rg -n "Password|ClientProof|ServerSignature|Authorization" NexusLib\net\src\xmpp
```

Review every match rather than treating grep absence alone as proof. Also inspect all socket access to confirm only the connection thread owns normal socket operations and that the shutdown path is the sole deliberate cross-thread interruption mechanism.

### Manual Verification

- Run the console client against each explicitly available local server configuration.
- Exercise both STARTTLS and direct TLS where the server supports them.
- Verify wrong credentials, wrong certificate identity, unavailable trust roots, server restart, network interruption, clean application shutdown, and Ctrl+C during a blocked connection.
- Confirm callbacks execute on the console/main thread and a stalled event pump produces the designed bounded failure rather than unbounded growth.
- Capture sanitized protocol transcripts only; review them for credentials, SCRAM material, and sensitive stanza content before retaining them.
- Record exact server versions and features. Do not generalize a single successful server test into universal XMPP compatibility.

## Risks And Questions

- **PRECIS and IDNA provider:** no acceptable implementation has yet been verified in the repository. Selecting or adding one may require a human dependency/license decision and is a hard gate before RFC-compliant JIDs can be claimed.
- **Cryptographic provider:** the required SHA/HMAC/PBKDF2/CSPRNG/constant-time surface has not yet been verified. A dependency choice is preferable to local cryptographic invention and may require approval.
- **`fcl-xml` stream fit:** the library is suitable for XML documents, but its exact behavior with XMPP stream framing, inherited namespaces, stream restarts, entity controls, and retained nodes must be proven. A demonstrated failure requires a revised parsing decision.
- **Synapse OpenSSL 3 fit:** provider loading, platform trust roots, host verification, SNI, and blocked-I/O shutdown must be proven on the target runtime. Any wrapper change increases maintenance responsibility and must stay narrow.
- **ALPN and channel binding:** the current wrapper does not visibly expose the full capability. Phase 1 should tolerate ALPN only where it is genuinely optional; required ALPN or channel binding remains outside scope until the provider surface is designed.
- **Platform claim:** the initial verified target is the repository's current Win64/FPC environment. Keep the code portable, but do not claim Linux or macOS support until the owner identifies those targets and they are compiled and tested.
- **XEP-0198 replay semantics:** stanza acknowledgement does not prove application-level idempotence. The API must distinguish safe protocol replay from operations the application must reconsider.
- **Live interoperability availability:** automated correctness must not depend on public services. Missing Prosody, ejabberd, or Openfire environments should be reported precisely; at least one controlled live server is required before the console proof is called complete.
- **Scope pressure:** MUC and modern message extensions are motivating features but must not be pulled into Phase 1 before the foundational state, TLS, authentication, queues, and stream-management behavior is verified.

No open product choice blocks approval of this work plan. The provider questions become implementation gates: if repository/toolchain inspection cannot identify acceptable existing providers, implementation pauses for the owner's decision rather than selecting a new dependency implicitly.

## Approval Gate

This document is a planning artifact only. No NexusXMPP implementation, build, test, live connection, dependency addition, or Synapse modification begins until the human owner explicitly authorizes implementation of this plan.

Approval authorizes the scoped Phase 1 work and its proof gates. It does not authorize Phase 2, Phase 3, application integration, or sub-agent use.
