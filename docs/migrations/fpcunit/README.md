# FPCUnit retirement and retained-test conversion

Completed on 2026-10-16 on x86_64 Linux, under the owner's instruction to convert
useful tests to nxtest, remove helpers/runners and remove fcl-fpcunit, with no bridge.

## Result

Useful coverage from 129 fixture/helper units was converted. Every runnable
fixture registers explicit nxtest callbacks. Context and case names are passed
to ordinary objects; callbacks own setup, teardown and destruction. Domain
helpers for XML, vectors and collections remain domain checks. No FPCUnit API,
compatibility superclass, registry adapter or runner is retained.

Removed NexusFPC `packages/fcl-fpcunit` (57 tracked source/support files), its
old package/RTL/compiler runners, JSON's `jsonfpcunit` unit and namespace wrapper,
fpGUI's FPCUnit GUI runner and Lazarus registration, obsolete test generators
and unsupported old test templates. The compiler package checklist, JSON
namespace map/package descriptions and active package documentation now reflect
that removal. Historical headers, archived snapshots and dependency-history
notes retain their original terminology.

Removed unused `TDBBasicsTestSetup`/`TDBBasicsTestCase` FPCUnit helpers.
`toolsunit` remains a plain database connector/data helper because compiler
regression programs consume it. All six DB compiler test programs build and run.

The reusable nxtest context gained native procedure/method `AssertRaises`
operations, including subclass matching, wrong/missing-exception failures and
restoration of result details after an intentionally caught assertion.
Test execution now preserves messages when native failure/skip exceptions are
raised directly. Seven dedicated regressions exercise those behaviors.

## Preserved originals and provenance

[original-tests.tar.gz](original-tests.tar.gz) contains 629 untouched source/data
files captured before conversion, including the complete FPCUnit package,
retained tests and neighboring fixtures. Every file has a SHA-256 entry in
[original-hashes.json](original-hashes.json). Archive SHA-256:

```text
0782f5dd74ad1133b61e75412b12df3dc5c4a646f914d4daba5e5a766e040c86
```

[retired-support.tar.gz](retired-support.tar.gz) additionally preserves 98
retired runner/template/support files, including ancillary files beyond the
first snapshot. [Per-file hashes](retired-support-hashes.json) and the archive
hash are recorded beside it. Archive SHA-256:

```text
087380032a6e593ea3427139466b1d2845ff508c8e2b4910fdeed5b2a3db7226
```

Both archives and every recorded file hash were verified after the conversion.
Source-specific notices remain in the archived and maintained material.
The shared FPC distribution notices remain with NexusFPC packages and RTL. Canonical upstream
credit, revision/date evidence, locations and mixed license status are recorded
in [Nexus attributions](../../../ATTRIBUTIONS.md#retired-fpcunit-and-retained-test-conversion).
The FPCUnit files last changed at NexusFPC
`6c5bd2eef00b97fe12e5b1e87310ec60313b8c52` (2026-10-14); that is local lineage,
not an assertion of an exact unmodified upstream revision.

## Diagnosed test failures

| Area | Verified cause and correction |
| --- | --- |
| Base64 decoding fixture | Original declaration had `s, expected: );` and could not compile. Restored the intended `AnsiString` parameters. |
| RTL streaming (five original failures) | An explicit Int64 default must be omitted; WideString uses the existing `vaUString` representation; enum/set properties with no declared default must be streamed; HexToBinary leaves the parser at the following identifier. Corrected the expectations/decoder and retained the behavioral checks. |
| Chain stream writes | Existing proxy aggregate streams reject writes with `EStreamError`. The two invalid write-success tests now verify rejection and unchanged position/content, including a stream boundary. |
| Floating checks | Removed accidental Currency rounding inherited from FPCUnit overload resolution. Used typed Single/Double comparisons and justified tolerances; time round trips compare the precision actually encoded by TimeToStr/DateTimeToStr. Point3D length checks Sqrt(3), not the rounded 1.7321. |
| Matrix3D methods | Converted two published constructor-shaped tests into ordinary native test procedures and registered them explicitly. |
| RTL duplicate registrations | Original runner registered the 24 TTestValueSimple cases twice: 530 registrations, 506 distinct identities. Native registration preserves all distinct cases once. |
| Generic notifications (two failures with current compiler) | The value-notification matcher incorrectly iterated FExpectKeys instead of FExpectValues. Corrected the loop bound; retained the notification assertions. |
| fpGUI HVIF input | Original test silently passed if its external Haiku file did not exist. Now explicitly skips with the missing-file reason. |
| fpGUI IDE themes | Four failures were absent data in the scratch working directory. Preparing the existing theme files produces 488 passes; no implementation or expectation change was needed. |

Original RTL collection tests reproduced five failures before conversion.
Original generic tests reproduced 23 failures with the installed compiler and
two with the current compiler. The original runs reproduced those failures; raw migration logs are not retained.
No collection implementation change was needed or made.

### Compiler difference

The installed `778927a6be-work-95622f1b76` SDK emits `crc32l` for byte/word memory
operands. A one-byte string hash changes with adjacent allocation bytes, and a
default dictionary can lose a key immediately after adding it. Small independent reproductions isolated this from test-framework
conversion. Current NexusFPC already selects the correct operand sizes in
`compiler/x86/rax86.pas`; it was not modified by this work.

Built a private current compiler/RTL from clean source revision
`3175c76fba08b47429e39877743a9bcff8a81f3a`, using the documented bootstrap helper
with an isolated checkout and no installation promotion. Compiler generations
2 and 3 matched, as did 90 RTL objects. Compiler SHA-256:

```text
316bec259e9513513b08f263a416b63903d5ccf30b5bfcf4f6b68fbae07418ed
```

The seed was the installed NexusFPC compiler. The installed `current` SDK
was left unchanged.

## Final execution through permanent nxbuild recipes

| Suite | Passed | Skipped |
| --- | ---: | ---: |
| FCL DB | 943 | 0 |
| FCL JSON | 528 | 1 |
| FCL XML | 36 | 0 |
| FCL image | 17 | 0 |
| FCL process | 23 | 0 |
| RTL collections/streaming | 269 | 0 |
| RTL objpas/RTTI/math | 506 | 0 |
| RTL generics | 208 | 0 |
| FCL base | 74 | 0 |
| FCL net | 110 | 0 |
| FCL registry | 9 | 0 |
| FCL hash | 31 | 0 |
| Hash | 14 | 0 |
| Compiler utilities | 28 | 0 |
| Compiler recompilation | 30 | 0 |
| fpGUI framework | 566 | 1 |
| fpGUI IDE | 488 | 0 |
| New nxtest context regressions | 7 | 0 |
| **Total** | **3,887** | **2** |

Zero failures and errors. This includes 3,882 retained case executions (3,880
passes plus two skips), and seven new framework regression cases. Both GUI
suites executed on the local display; they were not merely compiled.
The JSON skip is the existing Linux line-break case; the HVIF skip is described
above. Compact machine-readable totals are saved in [results.json](results.json).

Separately rebuilt and ran existing review regressions against the maintained
runtime packages: DB 16/16, image 18/18, JSON 14/14, XML 14/14, process 11 passes
plus three Windows-only skips. JSON generated-code cases used the matching SDK
and compiled/executed generated classes. All six independent compiler DB
programs built and exited zero. Raw migration build/run logs are not retained.

## Limits and remaining independent material

- Six optional fpGUI IDE debugger adapter cases were already commented out in
  the original runner. Their test source is converted, but the repository lacks
  required PDR units (`pdr_ports`, `pdr_engine`), so those six are not built/run.
  No stubs or fabricated passing results were introduced.
- Linux is the executed target. Windows-specific process regressions explicitly
  skip here. No Delphi validation is required by Nexus.
- External W3C corpora and the external Haiku HVIF input are not supplied.
- Independent punit tests and plain compiler test programs are not FPCUnit
  consumers and were not removed as part of this request.
- The host's default SDK predates the current CRC32 fix. Use a matching current
  SDK for the complete retained-suite run; the private verified build remains
  under ignored output, with reproducible identity recorded above.

Final diff checks passed in Nexus, nexus-packages and NexusFPC. All mapped
sources exist, no active converted suite imports FPCUnit, and its package has
no remaining files. The required spoken notification was attempted but could
not run because `pwsh` is unavailable on this host.

## Test ownership cleanup

The migration-only dispatcher and central suite catalog were removed. Native
runners and nxbuild recipes now live beside each owning package/compiler test
suite. Nxtest's own context regressions live in `projects/nxtest/test`.
`utNXTestConsole` is the shared native console entry point in the nxtest package.

The original source archives and their manifests above remain byte-for-byte
unchanged. Raw migration build/run logs and their evidence archive were
removed at the owner's request. `results.json` retains the compact verified
totals. This is an internal maintainer record.
