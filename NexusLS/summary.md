# Recent Work Summary

## NexusPas Routine Directive Promotion Pass

- Promoted a bounded routine declaration slice from `tcprocfunc.pas`.
- Promoted active-adjusted cases: 64.
- Newly active NexusPas tests added: 1.
- Active-adjusted inventory mappings now total: 423.
- Remaining deferred inventory mappings: 1,617.
- Not-applicable passrc-internal mappings remain: 34.
- Inventory rows remain: 2,074.
- Original published test methods remain: 2,073.
- Full-key duplicate count remains: 0.

## Parser Changes

- Extended NexusPas routine directive skipping for additional structural routine tails:
  `alias`, `compilerproc`, `far`, `hardfloat`, `ms_abi_cdecl`,
  `ms_abi_default`, `mwpascal`, `oldfpccall`, `public`,
  `sysv_abi_cdecl`, `sysv_abi_default`, and `vectorcall`.
- Kept behavior structural only. NexusPas does not model passrc procedure modifier enums, calling convention enums, public-name expressions, alias expressions, or external library expressions in this pass.

## Active Assertions Added

- Deprecated/platform/experimental/unimplemented routine tails.
- Additional calling convention tails including safecall, pascal, oldfpccall, hardfloat, MS ABI, MW Pascal, SysV ABI, and vectorcall.
- Public name, varargs, far, compilerproc, noreturn, assembler, export, external name/library/name, cdecl combinations, and alias routine tails.
- Explicit enum default parameter type capture.
- Var open-array parameter type capture for procedures and functions.
- Function return type preservation across routine-tail skipping.

## Inventory

- `tcprocfunc.pas` active-adjusted mappings increased from 54 to 118.
- `tcprocfunc.pas` deferred mappings decreased from 76 to 12.
- `tcprocfunc.pas` not-applicable mappings remain 0.
- Coverage map: `NexusLS/NexusLSTestModule/NexusPasPassrcTestInventory.csv`.
- Readable report: `NexusLS/NexusLSTestModule/NexusPasPassrcTestInventory.md`.

## Verification

- `lazbuild NexusLS\NexusLSTestModule\NexusLSTestModule.lpi` passed.
- `lazbuild NexusLS\nexusls.lpi` passed.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-suite NexusPas.PassrcPort`
  - 44 run, 44 passed, 0 failed, 0 skipped.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-all`
  - 203 run, 203 passed, 0 failed, 0 skipped.
- CodeTools/passrc/FPCUnit dependency scan found no active references in `NexusLS\src` or `NexusLS\NexusLSTestModule`.
- `git diff --check` found no whitespace errors.

## Archive

- No commit was made.
- Archive created with the default timestamped `New-NexusSourceArchive.ps1` call including `NexusLS` and `NexusLib`.
