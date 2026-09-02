# NexusLib

NexusLib is the shared Pascal support layer used by other Nexus modules. It is intentionally smaller than the application modules and should stay focused on reusable infrastructure.

## Current contents

- `obNXCommandLine.pas` provides slash-style command-line flag registration, parsing, defaults, validation, and help text.
- `obNXClassFactory.pas` provides keyed class registration and object creation through `TNXFactoryObject`.
- `obNXJSONValues.pas` provides typed JSON value objects, arrays, objects, positional params, and object/property mapping helpers.
- `obNXJSONRPCMessages.pas` provides JSON-RPC 2.0 message parsing, validation, request base classes, and success/error response construction.
- `obNXPersist.pas` provides JSON-backed persistent objects, binary payload support, and persistent lists.
- `net/src/xmpp` provides the NexusXMPP client protocol library: prepared JIDs, bounded XML stream framing, endpoint discovery, verified TLS, SCRAM-SHA-256, stanza and IQ dispatch, caller-thread event pumping, roster/discovery modules, bounded reconnect policy, and in-memory XEP-0198 resumption/replay.

## NexusXMPP

The deterministic Win64 test entry point is `NexusLib/net/tests/NexusNetXMPPTests.lpr`. Build it with:

```powershell
fpc -B -FuNexusLib\net\src\xmpp -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetXMPPTests\units -FEoutput\NexusNetXMPPTests\bin NexusLib\net\tests\NexusNetXMPPTests.lpr
```

The explicit live-test client is `NexusLib/net/examples/xmpp/NexusXMPPConsole.lpr`. It reads its JID, password, CA bundle, and optional endpoint override only from `NEXUS_XMPP_*` environment variables. Live server interoperability is not part of the deterministic test claim.

The retained deterministic verification record is `NexusLib/net/tests/NexusNetXMPPTests.md`.

The current Synapse integration pins TLS 1.2 because its exposed version selector cannot express “TLS 1.2 or newer” without also enabling obsolete protocols. TLS 1.3, SASL2, channel binding, Bind2, FAST, WebSocket/BOSH, and durable stream-resumption state remain outside the verified Phase 1 boundary.

## References

- [JSON-RPC Protocol Modeling](json-rpc.md) explains how to model a JSON-RPC protocol with the current NexusLib object model.

## Used by

`NexusLS` uses NexusLib for command-line parsing, class-factory dispatch, typed JSON DTOs, and JSON-RPC message handling.

`NexusTest` uses NexusLib for its JSON-RPC command processor and typed request/result values.

## Current boundary

NexusLib should not own editor behavior, test-running policy, UI behavior, schema generation, or tool-specific workflows. Those belong in their top-level modules.

Shared code belongs here when it can be used without importing module-specific assumptions. If a helper only makes sense for one module, keep it with that module until reuse is real.
