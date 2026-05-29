# NexusTest

NexusTest is the repository's current test framework and test-module playground. It defines explicit registries, suites, cases, context/assertions, structured results, JSON-RPC test commands, and a small module boundary for host-driven test execution.

## Source layout

- `src` contains the test framework, runner, registry, command processor, result store, module client, module wrapper, and JSON-RPC DTO values.
- `sample/SampleTests` contains a sample test module.
- `sample/Host` contains a simple host that loads a test module and calls its exported command function.
- `NexusTestUI` contains a NexusUI-based client interface.
- `README.md` describes the current playground contract and supported commands.

## Module contract

The sample module exposes a small C-style ABI:

```pascal
function NXTest_Init: Integer; cdecl;
procedure NXTest_Release; cdecl;
function NXTest_ExecuteCommand(ARequest: PAnsiChar; var AResultId: Integer; var AResultSize: Integer): Integer; cdecl;
function NXTest_ReadResult(AResultId: Integer; ABuffer: PAnsiChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer; cdecl;
```

Command payloads are UTF-8 JSON-RPC 2.0 text. Results are stored by the module and read back by result ID. A successful read consumes that result. If the caller's buffer is too small, the result remains available and the required size is returned.

No Pascal objects, Pascal strings, records, exceptions, or caller/callee-owned allocations cross the module boundary.

## Supported commands

- `nxtest/getCapabilities`
- `nxtest/listTests`
- `nxtest/runTest`
- `nxtest/runSuite`
- `nxtest/runAll`

## Current boundary

NexusTest depends on `NexusLib` for JSON-RPC request handling and typed JSON values. The framework is currently a first-pass playground with a sample host/module flow and a UI client. Treat the ABI and JSON-RPC command shape as the important current design boundary.
