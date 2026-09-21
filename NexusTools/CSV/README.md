# NexusCSV

`nxcsv` compiles a delimited source file through a Mustache template into one
artifact. Forge invokes it through the same native-command path as FPC. Neither
Forge nor the NexusScript compiler parses CSV or understands SQL output.

```powershell
lazbuild NexusTools\CSV\NexusCSV.lpi
& .\output\NexusCSV\x86_64-win64\nxcsv.exe `
  /input=NexusLib/script/data/lookup/STATE.csv `
  /template=NexusLib/script/tools/CSV/SQL.mustache `
  /output=output/state.sql /name=STATE_TBL
```

Required switches are `/input`, `/template`, and `/output`. `/name` defaults to the
input file stem; `/delimiter=comma` is the default and `/delimiter=tab` is supported.
Delimiter selection is explicit, not inferred from the filename. Paths are relative
to the process working directory. Quote the whole `/name=value` argument when it
contains spaces. The output parent must exist; Forge packages prepare declared
artifact parents. Exit status is zero on success and nonzero on failure.

The first record supplies field names. Empty or duplicate names, malformed quoting,
and rows with the wrong number of columns fail compilation. Quoted delimiters,
doubled quotes, empty cells, and comma/tab input retain the existing reader behavior.
Multiline quoted fields are not supported. Every value remains text; there is no
implicit SQL conversion, schema lookup, database connection, or type inference.

Templates receive:

```json
{"DataSource":{"_nx":{"Name":"STATE_TBL","Source":"states.csv"},
 "Fields":["CODE","NAME"],"Records":[["CA","California"]]}}
```

Ordinary templates use raw values. The explicit helper `{{{sql .}}}` emits one
SQL string literal, including surrounding quotes and doubled apostrophes.
`O'Brien` becomes `'O''Brien'`; an empty value becomes `''`, never NULL. Use this
helper only where a SQL string value is intended. It does not quote identifiers.

All maintained definitions and templates are in `NexusLib/script/tools/CSV/`.
`CSV.nxscript` supplies the partial CompileCSV configuration. Its Forge `Template`
constructs the command; `SourceTemplate` is the artifact template supplied to nxcsv.
Source, SourceTemplate, and Output are native tool arguments relative to the package
working directory. Compiler defaults to `nxcsv` on PATH and can be supplied explicitly
or through a package output, as with FPC.

The ready-to-run package is `NexusLib/script/examples/csv/Lookup.ForgePackage.nxscript`.
Put the built executable directory on PATH and request package LookupSQL. It creates
`generated/state.sql` and reuses it while present.

CSV process and SQL/plain-text tests are registered in the existing Forge suite.
Build NexusCSV before running that suite. Shared reader regressions also run in
NexusScript's existing external-data tests; both consumers use
`NexusLib/packages/foundation/serialization/delimited-text/src/utNXDelimitedText.pas`
(the JSON implementation is under `NexusLib/packages/foundation/serialization/json/src`).

## Verified 2026-09-15

- 25 Forge tests, 60 NexusScript tests, and 12 language-server tests passed;
  all three suites reported zero unfreed heap blocks.
- The common LookupSQL package built its artifact and reused it on the next request.
- The relocated Hello package compiled, and the relocated BotHost package generated
  its SQL. BotHost catalog and disposable Firebird tests passed.
- Installer tasks materialized successfully with Forge and nxcsv build/install steps.
  Full installer staging and packaging were not run.

NexusSchema source/project/tests are retired. Maintained scripts and templates are
under the common library; test-only/invalid fixtures remain with their suites.
The existing NexusScript external-source manifest adapter uses the same delimited
reader; it is not a second implementation of CSV parsing.
