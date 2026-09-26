# NexusForge

Forge is the front end for declarative builds and artifact generation. A package
declares its outputs and operations; present outputs satisfy the package, while
missing outputs cause its operations to run. There is no timestamp/hash freshness
tracking in this first pass.

Schema generation uses the shared Schema dialect and a Firebird Environment that
supplies its template and key conventions. Forge's Render operation compiles and
validates the source, then writes Mustache output in-process. The old NexusSchema
executable and `.nxs` parser have been retired.

CSV generation uses a separate compiler, nxcsv, invoked as an ordinary Forge
operation like FPC. Its SourceTemplate controls the generated artifact. SQL string
quoting is explicitly requested by that template; neither Forge nor the CSV reader
infers database behavior.

Maintained inputs live with their owners:

- `projects/forge/language/` and `projects/forge/examples/`: Forge definitions and build examples.
- `projects/bothost/`: BotHost schema package, configuration, tables, and Firebird template.
- `projects/csv/`: CSV compiler configuration, templates, lookup inputs, and package example.
- `projects/schema/`: Schema dialect and retained Schema examples.
- `tools/task/tasks/`: repository build/deployment tasks, pending their eventual Forge replacement.

From the repository root:

```powershell
lazbuild projects\forge\NexusForge.lpi
lazbuild projects\csv\NexusCSV.lpi
$env:PATH = (Resolve-Path output\NexusCSV\x86_64-win64).Path + ';' + $env:PATH
& .\output\NexusForge\x86_64-win64\nxforge.exe `
  /input=projects/csv/examples/Lookup.ForgePackage.nxscript /package=LookupSQL
& .\output\NexusForge\x86_64-win64\nxforge.exe `
  /input=projects/bothost/BotHost.ForgePackage.nxscript `
  /package=BotHostDatabase /targets=TargetDB:Firebird
```

These commands generate files; they do not connect to a database. The BotHost
database README documents the separate registered disposable Firebird test.
Only Firebird database generation is currently implemented.
