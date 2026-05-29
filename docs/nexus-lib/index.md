# NexusLib

NexusLib is the shared Pascal support layer used by other Nexus modules. It is intentionally smaller than the application modules and should stay focused on reusable infrastructure.

## Current contents

- `obNXCommandLine.pas` provides slash-style command-line flag registration, parsing, defaults, validation, and help text.
- `obNXClassFactory.pas` provides keyed class registration and object creation through `TNXFactoryObject`.
- `obNXJSONValues.pas` provides typed JSON value objects, arrays, objects, positional params, and object/property mapping helpers.
- `obNXJSONRPCMessages.pas` provides JSON-RPC 2.0 message parsing, validation, request base classes, and success/error response construction.
- `obNXPersist.pas` provides JSON-backed persistent objects, binary payload support, and persistent lists.

## Used by

`NexusLS` uses NexusLib for command-line parsing, class-factory dispatch, typed JSON DTOs, and JSON-RPC message handling.

`NexusTest` uses NexusLib for its JSON-RPC command processor and typed request/result values.

## Current boundary

NexusLib should not own editor behavior, test-running policy, UI behavior, schema generation, or tool-specific workflows. Those belong in their top-level modules.

Shared code belongs here when it can be used without importing module-specific assumptions. If a helper only makes sense for one module, keep it with that module until reuse is real.
