# NexusTest

NexusTest is a Pascal test framework built around loadable test modules.

Instead of assuming tests must run inside one executable, one IDE, or one command-line runner, NexusTest gives tests a small shared-library boundary. A test module can be loaded by a host, queried for its available tests, executed through JSON-RPC commands, and monitored by tools such as NexusTestUI.

That makes NexusTest useful anywhere a shop wants test execution to be repeatable, inspectable, and separate from the application being tested.

## What It Solves

Traditional Pascal test setups are often tied tightly to one runner or one project shape. That works until you want tests to be:

- discovered by a tool before they run
- loaded from a DLL or shared library
- run individually, by suite, or as a full module
- monitored visually while they execute
- driven by another process without sharing Pascal object ownership
- reused by command-line tools, GUI tools, and future automation

NexusTest solves that by making the test module a stable boundary.

The module owns its registry, suites, cases, assertions, and results. The host talks to it through a small exported API and JSON-RPC commands.

## Why It Is Useful

NexusTest is well suited for Pascal teams that need practical test tooling without turning the test runner into the center of the architecture.

The useful parts are deliberately simple:

- Tests are organized as suites and cases.
- Assertions write structured result data.
- Test modules can be listed before execution.
- Hosts can run all tests, one suite, or one test.
- Results include status, duration, and message data.
- A GUI runner can display the module without becoming the source of truth.
- No Pascal objects, strings, records, exceptions, or caller-owned allocations cross the shared-library boundary.

That last point matters. It keeps the boundary predictable across tools, processes, and future host implementations.

## How It Works

A NexusTest module exports four functions:

```pascal
function NXTest_Init: Integer; cdecl;
procedure NXTest_Release; cdecl;
function NXTest_ExecuteCommand(ARequest: PAnsiChar; var AResultId: Integer; var AResultSize: Integer): Integer; cdecl;
function NXTest_ReadResult(AResultId: Integer; ABuffer: PAnsiChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer; cdecl;
```

The host sends UTF-8 JSON-RPC 2.0 command text to `NXTest_ExecuteCommand`. The module stores the response and returns a result ID plus the exact buffer size needed to read it. The host then calls `NXTest_ReadResult` to copy the response.

A successful read consumes the stored result. If the buffer is too small, the result remains available and the required size is returned.

## Supported Commands

NexusTest modules support the core commands a host needs to discover and execute tests:

| Command | Purpose |
| --- | --- |
| `nxtest/getCapabilities` | Ask what the module supports. |
| `nxtest/listTests` | Return suites and test cases without running them. |
| `nxtest/runAll` | Run the full module. |
| `nxtest/runSuite` | Run one suite. |
| `nxtest/runTest` | Run one test case. |

The same command shape is used by the sample host, NexusTestUI, and the NexusLS test module.

## Visual Test Running

NexusTestUI is a NexusUI-based runner for loadable test modules. It presents suites and cases in a tree, runs selected tests or full modules, and displays status, duration, and messages.

The UI does not own the tests. It is a client of the test module. That separation keeps test state in the framework and module where it belongs.

## Adoption Fit

NexusTest is a strong fit when:

- tests need to be loaded from compiled Pascal modules
- multiple tools need to run the same tests
- a GUI test monitor is useful
- a command-line host is still required
- test discovery matters
- the test boundary must remain plain and stable

It is especially useful for tooling-heavy Pascal code such as language servers, generators, framework modules, and applications where tests benefit from being loaded and inspected by separate tools.

## Where To Look Next

- `NexusTest/src` contains the framework, registry, runner, result store, command processor, and module client.
- `NexusTest/sample` contains a sample module and host.
- `NexusTest/NexusTestUI` contains the GUI runner.
- `NexusLS/NexusLSTestModule` shows NexusTest being used for real NexusLS coverage.
