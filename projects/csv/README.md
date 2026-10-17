# NexusCSV

`nxcsv` compiles a delimited source file through a Mustache template into one
artifact. Forge invokes it through the same native-command path as FPC. Neither
Forge nor the NexusScript compiler parses CSV or understands SQL output.

Build with nxbuild and NexusFPC from the Nexus root. The recipe uses the shared
installation settings in `projects/nxbuild/nxbuild.environment.nxscript` and writes
to `output/NexusCSV/<cpu>-<os>`.

On Linux:

```sh
./output/nxbuild-next/x86_64-linux/nxbuild /action=build /project=projects/csv/NexusCSV.nxproject
./output/NexusCSV/x86_64-linux/nxcsv \
  /input=../nexus-lab/examples/data/csv/data/lookup/STATE.csv \
  /template=projects/csv/templates/SQL.mustache \
  /output=output/state.sql /name=STATE_TBL
```

On Windows:

```powershell
& .\output\nxbuild-next\x86_64-win64\nxbuild.exe /action=build /project=projects/csv/NexusCSV.nxproject
& .\output\NexusCSV\x86_64-win64\nxcsv.exe `
  /input=../nexus-lab/examples/data/csv/data/lookup/STATE.csv `
  /template=projects/csv/templates/SQL.mustache `
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

`config/CSV.nxscript` supplies the partial CompileCSV configuration. The Forge
`Template` constructs the command; `templates/SQL.mustache` is the artifact
template supplied to nxcsv.
Source, SourceTemplate, and Output are native tool arguments relative to the task
working directory. Compiler defaults to `nxcsv` on PATH and can be supplied explicitly.

The ready-to-run CSV task is `../nexus-lab/examples/data/csv/Lookup.Forge.nxscript`.
Put the built executable directory on PATH and run that Forge document. It writes
`generated/state.sql` on each run.

CSV process and SQL/plain-text tests are registered in the existing Forge suite.
The root Forge `Tests` group builds NexusCSV before the Forge test executable.
When building the test executable directly, build NexusCSV first with the command
above. The test requires the tool under `output/NexusCSV/<cpu>-<os>/nxcsv`
(`nxcsv.exe` on Windows), matching the test host; a missing tool is a failed
prerequisite. It runs the real executable to check quoting, delimiters, error
propagation and preservation of an existing artifact after invalid input.
Shared reader regressions also run in
NexusScript's existing external-data tests; both consumers use
`packages/nexus-packages/serialization/delimited-text/src/utNXDelimitedText.pas`
(the JSON implementation is under `packages/nexus-packages/serialization/json/src`).

## Verified 2026-10-16

The native Linux executable built with NexusFPC SDK `3175c76fba` and nxbuild;
the existing Forge `CSVTool` integration test passed. The build verification
selected that SDK's matching compiler and RTL in an ignored recipe. The full
Forge suite passed 54/54 after fixing Unix child-status decoding and copied-file
permissions, including two added Unix regressions. The Windows build plan selects
`x86_64-win64/nxcsv.exe`; Windows compilation and execution were not run here.

## Verified 2026-09-15

- 25 Forge tests, 60 NexusScript tests, and 12 language-server tests passed;
  all three suites reported zero unfreed heap blocks.
- The common LookupSQL package built its artifact and reused it on the next request.
- The relocated Hello package compiled, and the relocated BotHost package generated
  its SQL. BotHost catalog and disposable Firebird tests passed.
- Installer tasks materialized successfully with Forge and nxcsv build/install steps.
  Full installer staging and packaging were not run.

NexusSchema source/project/tests are retired. CSV configuration and templates
are owned by this project. Examples and lookup inputs live in
`../nexus-lab/examples/data/csv`; test-only fixtures remain with their suites.
The existing NexusScript external-source manifest adapter uses the same delimited
reader; it is not a second implementation of CSV parsing.
