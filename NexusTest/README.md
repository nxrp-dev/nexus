# NexusTest Playground

This is a first-pass NexusTest playground.

It includes:

- explicit test registry
- explicit suites
- explicit test cases
- test context/assertions
- structured result objects
- JSON-RPC command processor
- sample test DLL/shared library
- simple host app that loads the library and calls `NXTest_ExecuteCommand`

## Exported module contract

The sample test module exports:

```pascal
function NXTest_Init: Integer; cdecl;
procedure NXTest_Release; cdecl;

function NXTest_ExecuteCommand(
  ARequest: PChar;
  var AResultId: Integer;
  var AResultSize: Integer
): Integer; cdecl;

function NXTest_ReadResult(
  AResultId: Integer;
  ABuffer: PChar;
  ABufferSize: Integer;
  var ABytesWritten: Integer
): Integer; cdecl;
```

The command payload is currently UTF-8 JSON-RPC 2.0 text.

`NXTest_ExecuteCommand` executes the command and stores the response inside the module. It returns a result ID and the exact buffer size needed to read the response.

`AResultSize` includes every byte required by `NXTest_ReadResult`, including the trailing `#0` terminator.

`NXTest_ReadResult` copies and consumes the stored result. A result is single-use. If the supplied buffer is too small, the result is not consumed.

No Pascal objects, Pascal strings, records, exceptions, or caller/callee-owned allocations cross the module boundary.

## Supported commands

- `nxtest/getCapabilities`
- `nxtest/listTests`
- `nxtest/runTest`
- `nxtest/runSuite`
- `nxtest/runAll`

## Build

Windows:

```bat
build_windows.bat
```

Linux/macOS-ish:

```sh
./build_linux.sh
```

## Example host usage

Windows:

```bat
sample\Host\nxtest_host.exe sample\SampleTests\nxtest_sampletests.dll list
sample\Host\nxtest_host.exe sample\SampleTests\nxtest_sampletests.dll run-all
sample\Host\nxtest_host.exe sample\SampleTests\nxtest_sampletests.dll run-test Sample.PassingString
```

Linux:

```sh
sample/Host/nxtest_host sample/SampleTests/libnxtest_sampletests.so list
sample/Host/nxtest_host sample/SampleTests/libnxtest_sampletests.so run-all
sample/Host/nxtest_host sample/SampleTests/libnxtest_sampletests.so run-test Sample.PassingString
```

## Current design rule

The DLL boundary exposes intent, not encoding: `NXTest_ExecuteCommand`.

JSON-RPC is the current command contract. The result boundary is deterministic: execute returns a result ID and exact result buffer size; read consumes that specific result.
