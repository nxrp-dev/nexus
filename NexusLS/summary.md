# Recent Work Summary

## Passrc Inventory Identity Repair

- Added `OriginalTestClass` to `NexusPasPassrcTestInventory.csv`.
- Inventory identity is now `SourceUnit + OriginalTestClass + OriginalTestMethod`.
- Inventory rows remain: 2,074.
- Original published test methods remain: 2,073.
- Full-key duplicate count: 0.

## NexusPas Passrc Promotion Pass

- Promoted a bounded scanner-foundation slice from `tcscanner.pas`.
- Promoted cases attempted: 24.
- Newly active NexusPas tests added: 0.
- Existing NexusPas scanner tests were extended to assert the newly promoted behaviors.
- Active-adjusted inventory mappings now total: 248.
- Remaining deferred inventory mappings: 1,796.
- Not-applicable passrc-internal mappings: 30.

## Parser And Lexer Changes

- Added lexer keyword recognition for additional Pascal scanner tokens:
  - `bitpacked`
  - `dispinterface`
  - `except`
  - `exports`
  - `false`
  - `file`
  - `finally`
  - `goto`
  - `helper`
  - `is`
  - `label`
  - `mod`
  - `on`
  - `raise`
  - `specialize`
  - `true`
- Extended scanner tests for:
  - line-ending whitespace token form
  - tab whitespace token form
  - backslash symbol
  - `<<` / `>>` compound symbols
  - additional keyword tokens

## Verification

- `lazbuild NexusLS\NexusLSTestModule\NexusLSTestModule.lpi` passed.
- `NexusPas.PassrcPort`: 36 passed / 36 total.
- Full test run: 195 passed / 195 total.
- `lazbuild NexusLS\nexusls.lpi` passed.
- CodeTools/passrc dependency scan found no active references in `NexusLS\src` or `NexusLS\NexusLSTestModule`.

## Inventory

- Coverage map: `NexusLS/NexusLSTestModule/NexusPasPassrcTestInventory.csv`.
- Readable report: `NexusLS/NexusLSTestModule/NexusPasPassrcTestInventory.md`.
- Full uploaded archive inventory remains at 2,073 original published test methods across 15 source units.

## Archive

- No commit was made.
