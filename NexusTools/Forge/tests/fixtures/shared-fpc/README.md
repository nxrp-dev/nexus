# Shared FPC configuration experiment

A tiny console application using JSON, XML, a local unit, and a local include.
The application script knows its own files; the shared configuration knows the
FPC library locations. This is an editable test fixture, not the final shared
configuration layout or an automated unit test yet.

Read these in order:

1. `Installation.nxscript`: this machine's FPC root and target, declared once.
2. `Shared.nxscript`: reusable `StandardFPC` configuration with library paths.
3. `Tiny.ForgePackage.nxscript`: application composes that configuration and adds
   its local unit/include paths. Ordinary unnamed array entries append.
4. `FPC.mustache`: translates the completed properties into compiler switches.

The only shared dialect additions are text arrays `UnitPaths` and `IncludePaths`.
There are no Forge runtime or NexusScript compiler changes.

## Run

The checked-in installation values describe `C:/lazarus/fpc/3.2.2` targeting
`x86_64-win64`. Edit Installation.nxscript for your installation. The executable
suffix and output folder in this small example are deliberately Windows-specific.

From the repository root, using the built Forge executable:

```powershell
& .\output\NexusForge\x86_64-win64\nxforge.exe /input=NexusTools/Forge/tests/fixtures/shared-fpc/Tiny.ForgePackage.nxscript /package=Tiny
& .\output\ForgeSharedFPC\tiny.exe
```

Expected output:

```text
Shared FPC: hello world
```

`output/ForgeSharedFPC/build.log` records the actual command and result.
FPC's `-n` switch disables implicit configuration files: the shared script supplies
the RTL paths explicitly and the FCL source directories for JSON and XML. Those
library sources compile into `output/ForgeSharedFPC` along with the application.
The template preserves array order; FPC determines search precedence.

Package reuse still checks artifact presence. After editing, remove only the
example executable to request another build:

```powershell
Remove-Item -LiteralPath .\output\ForgeSharedFPC\tiny.exe
```

Try changing the greeting include, adding a local unit path, or adding a library
path once in Shared.nxscript. Another application can compose the same StandardFPC
definition without repeating its library paths.

This establishes the small FPC example first. LCL/widgetset definitions and clean
LCL dependency builds remain the next experiment; source fingerprinting stays on hold.
