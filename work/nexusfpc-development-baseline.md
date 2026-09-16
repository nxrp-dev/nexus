# NexusFPC development build baseline

Verified 2026-09-15, before source cleanup.

- Checkout: `C:\gitdev\tools\NexusFPC`
- Branch: `main`
- Commit: `13647609644921670c5b4fbb38744021d1bdde4d`
- Commit subject: `Avoid range check error when aArgs is empty in FFIInvoke function`
- Compiler version: `3.3.1`
- Host and target: `x86_64-win64`
- Bootstrap compiler: `C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe`
- Git working tree was clean before and after the build. No source patches applied.

This identifies the tested development checkout; it is not a claim that an upstream
remote was refreshed. The installed Lazarus/FPC toolchain was not replaced.

## Build

From the checkout directory:

```powershell
$env:PATH = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64;' + $env:PATH
& 'C:/lazarus/fpc/3.2.2/bin/x86_64-win64/make.exe' all `
  PP=C:/lazarus/fpc/3.2.2/bin/x86_64-win64/ppcx64.exe `
  CPU_TARGET=x86_64 OS_TARGET=win64
```

Exit code: **0**. The normal release build completed compiler bootstrapping,
successive compiler binary comparison, whole-program optimization passes, RTL,
standard packages, and bundled utilities.

[Complete build log](../output/fpc-dev-baseline-build.log).

Built compiler: `C:\gitdev\tools\NexusFPC\compiler\ppcx64.exe`

Compiler SHA-256:

```text
F34059E025840C8812061EDCBE3A4556FC6026334AE66DEFC36BC078058DC406
```

RTL units are under `rtl/units/x86_64-win64`; package units are under
`packages/<package>/units/x86_64-win64`, relative to the checkout.
Use these matching units with this compiler, not the installed 3.2.2 units.

## Application verification

The [shared FPC example](../NexusTools/Forge/tests/fixtures/shared-fpc/README.md)
was compiled directly with the new compiler using `-n` and explicit paths to its
new RTL, rtl-objpas, fcl-base, fcl-json, and fcl-xml units, plus the example's
local support and include directories. All application outputs went to
`output/FPCDevBaseline`, separate from the earlier 3.2.2 example build.

- Compilation exit code: **0**.
- Execution exit code: **0**.
- Output: `Shared FPC: hello world`.
- [Compile log](../output/FPCDevBaseline/compile.log).
- [Execution output](../output/FPCDevBaseline/run.log).

This proves the native build, compiler self-consistency check, and JSON/XML
application smoke test. The full upstream compiler test suite and cross-target
builds were not run in this baseline. No archives were produced.
