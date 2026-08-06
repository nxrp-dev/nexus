# NexusPas passrc test inventory

This file summarizes the source-controlled coverage map in `NexusPasPassrcTestInventory.csv`.

## Source archive audit

- Source archive: `lib/fcl-passrc/tests.zip`
- Source units processed: 15
- Inventory rows: 2,074
- Original published test methods inventoried: 2,073
- Support units with no published tests: 1 (`tcbaseparser.pas`)
- Missing inventory rows after archive audit: 0
- Extra inventory rows after archive audit: 0

Only published test methods from the uploaded passrc-style units are counted as runnable original tests. Helper functions, private methods, protected methods, and implementation routines are not counted.

## Inventory identity

Inventory rows are identified by:

`SourceUnit + OriginalTestClass + OriginalTestMethod`

The original `SourceUnit + OriginalTestMethod` pair is not unique for all passrc tests. The current full-key duplicate count is 0.

## Classification totals

| Status | Count |
| --- | ---: |
| active NexusPas test | 0 |
| active NexusPas test with adjusted Nexus expectation | 712 |
| deferred because NexusPas does not yet support the required feature | 1250 |
| not applicable because it targets passrc-specific internals | 34 |
| tried and failed because NexusPas does not yet support the required feature | 78 |

Current active mappings are classified as adjusted Nexus expectations because they assert NexusPas lexer/parser/symbol behavior directly rather than preserving passrc object-model expectations.

## Per-unit inventory

| Source unit | Rows | Published methods | Active adjusted | Deferred | Tried failed | Not applicable |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| tcbaseparser.pas | 1 | 0 | 0 | 0 | 0 | 1 |
| tcclasstype.pas | 123 | 123 | 95 | 13 | 15 | 0 |
| tcexprparser.pas | 110 | 110 | 0 | 110 | 0 | 0 |
| tcgenerics.pp | 20 | 20 | 8 | 5 | 7 | 0 |
| tcmoduleparser.pas | 26 | 26 | 25 | 0 | 1 | 0 |
| tconstparser.pas | 55 | 55 | 55 | 0 | 0 | 0 |
| tcpassrcutil.pas | 29 | 29 | 0 | 0 | 0 | 29 |
| tcprocfunc.pas | 130 | 130 | 127 | 0 | 3 | 0 |
| tcresolvegenerics.pas | 129 | 129 | 0 | 129 | 0 | 0 |
| tcresolver.pas | 726 | 726 | 0 | 726 | 0 | 0 |
| tcscanner.pas | 194 | 194 | 154 | 36 | 0 | 4 |
| tcstatements.pas | 95 | 95 | 0 | 95 | 0 | 0 |
| tctypeparser.pas | 282 | 282 | 217 | 13 | 52 | 0 |
| tcuseanalyzer.pas | 124 | 124 | 1 | 123 | 0 | 0 |
| tcvarparser.pas | 30 | 30 | 30 | 0 | 0 | 0 |

## Active NexusPas suite

- Suite: `NexusPas.PassrcPort`
- Active NexusPas tests currently registered: 71
- Latest visible summary: 71 passed / 71 total
- Latest full NexusLSTestModule summary: 277 passed / 1 failed. The failure is outside the passrc-port suite: `NexusLS.Core.AndroidNDKFieldSuggestsDownloadURL`.

Unsupported resolver, expression evaluator, statement parser, overload resolver, generic resolver, use analyzer, compiler-style unit resolver, and passrc-internal tests remain deferred or not applicable in the CSV until NexusPas owns those features.
