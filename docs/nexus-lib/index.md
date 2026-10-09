# Nexus Shared Libraries

Shared Pascal support lives in independently described packages under packages/nexus-packages. Core helpers live in core/src; source-independent binding lives in binding/src. The Pascal project and compiler-option models belong to projects/nxbuild/src.

## Current contents

- `obNXCommandLine.pas` provides slash-style command-line flag registration, parsing, defaults, validation, and help text.
- `obNXClassFactory.pas` provides keyed class registration and object creation through `TNXFactoryObject`.
- `obNXJSONValues.pas` provides typed JSON value objects, arrays, objects, positional params, and object/property mapping helpers.
- `obNXJSONRPCMessages.pas` provides JSON-RPC 2.0 message parsing, validation, request base classes, and success/error response construction.
- `obNXPersist.pas` provides JSON-backed persistent objects, binary payload support, and persistent lists.
- `packages/nexus-packages/network/xmpp` provides the NexusXMPP client protocol library: ASCII-validated JIDs and credentials, bounded XML stream framing, endpoint discovery, verified TLS, SCRAM-SHA-256, stanza and IQ dispatch, caller-thread event pumping, roster/discovery, direct and room messaging, Carbons, bounded MAM queries, bounded reconnect policy, and in-memory XEP-0198 resumption/replay.

## NexusXMPP

The deterministic Win64 test entry point is `packages/nexus-packages/network/xmpp/test/NexusNetXMPPTests.lpr`. Build it with:

```powershell
fpc -B -Fupackages\nexus-packages\network\xmpp\src -Fupackages\nexus-packages\network\external\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetXMPPTests\units -FEoutput\NexusNetXMPPTests\bin packages\nexus-packages\network\xmpp\test\NexusNetXMPPTests.lpr
```

The explicit live-test client is `packages/nexus-packages/network/xmpp/examples/NexusXMPPConsole.lpr`. It reads its JID, password, CA bundle, and optional endpoint override only from `NEXUS_XMPP_*` environment variables. Applications receive replayable transmitted stanzas that become uncertain after rejected resumption through `OnUnrecoverableStanzas`; NexusXMPP does not resend them automatically. Live server interoperability is not part of the deterministic test claim.

The retained deterministic and Openfire 5.1.2 live verification record is
`packages/nexus-packages/network/xmpp/test/NexusNetXMPPTests.md`. The live test entry point is
`packages/nexus-packages/network/xmpp/test/NexusNetXMPPLiveTest.lpr`; it reads credentials and endpoint
configuration from `NEXUS_XMPP_*` environment variables.

Phase 2 messaging keeps ordinary stanza IDs, sender origin IDs, issuer-scoped
stanza IDs, reply references, receipt IDs, archive result IDs, and room occupant
IDs distinct. Forwarded Carbon and MAM content uses a shared decoder and carries
an explicit delivery context rather than being redispatched as live traffic.
Automatic receipts are disabled by default. MAM queries enforce concurrent,
page-size, result-count, and aggregate-byte limits and return an owned operation
handle. Receipt correlations, verified capabilities, rooms, occupants, and MUC
history are likewise bounded through `TNXXMPPClientConfig`; NexusXMPP provides
no durable message storage or application/AI policy.

Phase 2 applications register focused message, discovery/ping, MUC, Carbon, and
MAM modules before connecting. Callback message/discovery objects are borrowed;
MAM operation interfaces are caller-owned. The console example supports typed
discovery and explicit instant-room creation plus join/message/leave commands through
`NEXUS_XMPP_DISCO_JID`, `NEXUS_XMPP_ROOM`, and `NEXUS_XMPP_ROOM_NICK`.

The current Synapse integration pins TLS 1.2 because its exposed version
selector cannot express "TLS 1.2 or newer" without also enabling obsolete
protocols. TLS 1.3, SASL2, channel binding, Bind2, FAST, WebSocket/BOSH, and
durable stream-resumption state remain outside the verified boundary.

## References

- [JSON-RPC Protocol Modeling](json-rpc.md) explains how to model a JSON-RPC protocol with the shared typed object model.

## Used by

`NexusLS` uses the core, serialization/json, network/json-rpc, and lsp packages for command-line parsing, class-factory dispatch, typed JSON values, and JSON-RPC message handling.

`NexusTest` uses the core, serialization/json, and network/json-rpc packages for its JSON-RPC command processor and typed request/result values.

## Current boundary

Shared foundation packages should not own editor behavior, test-running policy, UI behavior, schema generation, or tool-specific workflows. Those belong to the relevant GUI package or project.

Shared code belongs in a package when it can be used without importing project-specific assumptions. If a helper only makes sense for one project, keep it with that project.
