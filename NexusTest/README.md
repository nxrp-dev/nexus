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
  AResponse: PChar;
  AResponseSize: Integer;
  var ABytesWritten: Integer
): Integer; cdecl;
```

The command payload is currently UTF-8 JSON-RPC 2.0 text. The caller supplies the response buffer. For commands that run tests, call once with a sufficiently large buffer; do not use a sizing call that would execute the same command twice.

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

JSON-RPC is the current command contract. Pascal objects, Pascal strings, records, and exceptions do not cross the module boundary.
