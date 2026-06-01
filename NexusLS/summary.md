# Recent Work Summary

## NexusPas Scanner Coverage Promotion Pass

- Promoted a bounded scanner/lexer slice from `tcscanner.pas`.
- Promoted active-adjusted cases: 12.
- Marked passrc-internal scanner/helper cases not applicable: 4.
- Newly active NexusPas tests added: 2.
- Active-adjusted inventory mappings now total: 359.
- Remaining deferred inventory mappings: 1,681.
- Not-applicable passrc-internal mappings: 34.
- Inventory rows remain: 2,074.
- Original published test methods remain: 2,073.
- Full-key duplicate count remains: 0.

## Lexer Changes

- Added UTF-8 BOM handling at the start of a source file, preserving it as leading whitespace.
- Added escaped keyword identifier handling for forms such as `&xor`.
- Kept scanner behavior Nexus-owned; no passrc scanner option model or helper object model was introduced.

## Active Assertions Added

- Escaped keyword identifiers.
- `Self` as a NexusPas identifier token.
- Parenthesis symbol tokens for passrc `TestBraceOpen` / `TestBraceClose`.
- Raw token-series preservation for keywords, whitespace, comments, and identifiers.
- Adjusted non-whitespace token walking for token-series behavior without adding scanner switches.
- Brace and paren-star directive token preservation, including DEFINE spacing variants.
- UTF-8 BOM preservation before the first real token.

## Inventory

- `tcscanner.pas` active-adjusted mappings increased from 130 to 142.
- `tcscanner.pas` deferred mappings decreased from 64 to 48.
- `tcscanner.pas` not-applicable mappings increased from 0 to 4.
- `TTestTokenFinder.TestFind`, `TTestStreamLineReader.TestCreate`, `TTestScanner.TestonComment`, and `TTestScanner.TestOperatorIdentifier` are marked not applicable because they target passrc scanner helpers, callbacks, or option-model behavior rather than NexusPas lexer contracts.

## Verification

- `lazbuild NexusLS\NexusLSTestModule\NexusLSTestModule.lpi` passed.
- `lazbuild NexusLS\nexusls.lpi` passed.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-suite NexusPas.PassrcPort`
  - 43 run, 43 passed, 0 failed, 0 skipped.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-all`
  - 202 run, 202 passed, 0 failed, 0 skipped.
- CodeTools/passrc/FPCUnit dependency scan found no active references in `NexusLS\src` or `NexusLS\NexusLSTestModule`.
- `git diff --check` found no whitespace errors.

## Archive

- No commit was made.
- Archive created with the default timestamped `New-NexusSourceArchive.ps1` call including `NexusLS` and `NexusLib`.
