# Recent Work Summary

## NexusPas Routine Structural Promotion Pass

- Promoted a bounded routine/procedural-type slice from `tcprocfunc.pas` and `tctypeparser.pas`.
- Promoted active-adjusted cases: 36.
- Newly active NexusPas tests added: 1.
- Active-adjusted inventory mappings now total: 536.
- Remaining deferred inventory mappings: 1,504.
- Not-applicable passrc-internal mappings remain: 34.
- Inventory rows remain: 2,074.
- Original published test methods remain: 2,073.
- Full-key duplicate count remains: 0.

## Parser Changes

- Fixed top-level interface routine declarations so they no longer consume following declaration sections as routine-local declarations.
- Kept this pass structural only. NexusPas still does not model passrc procedure modifier enums, calling-convention enums, comment attachment, expression evaluation, dialect validation, operator semantic typing, or passrc object-model expectations.

## Active Assertions Added

- Comment-adjacent procedure/function declarations still produce routine symbols.
- `cdecl; forward;` procedure/function tails are skipped structurally while preserving routine symbols and function return type text.
- Delphi-style implementation function declarations without repeated result type parse without corrupting the surrounding routine structure.
- Procedural type aliases preserve declared type text for:
  - plain procedure types
  - `var`, `const`, and `out` parameter groups
  - combined parameter names
  - untyped `var`, `const`, and `out` parameters
  - default parameter values as structural text
  - open-array and `array of const` parameters
  - `reference to procedure`
  - `procedure is nested`

## Inventory

- `tcprocfunc.pas` active-adjusted mappings increased from 118 to 124.
- `tcprocfunc.pas` deferred mappings decreased from 12 to 6.
- `tctypeparser.pas` active-adjusted mappings increased from 115 to 145.
- `tctypeparser.pas` deferred mappings decreased from 167 to 137.
- Coverage map: `NexusLS/NexusLSTestModule/NexusPasPassrcTestInventory.csv`.
- Readable report: `NexusLS/NexusLSTestModule/NexusPasPassrcTestInventory.md`.

## Verification

- `lazbuild NexusLS\NexusLSTestModule\NexusLSTestModule.lpi` passed.
- `lazbuild NexusLS\nexusls.lpi` passed.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-suite NexusPas.PassrcPort`
  - 46 run, 46 passed, 0 failed, 0 skipped.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-all`
  - 205 run, 205 passed, 0 failed, 0 skipped.
- CodeTools/passrc/FPCUnit dependency scan found no active references in `NexusLS\src` or `NexusLS\NexusLSTestModule`.
- `git diff --check` found no whitespace errors.

## Archive

- No commit was made.
- Archive created with the default timestamped `New-NexusSourceArchive.ps1` call including `NexusLS` and `NexusLib`.
