# Shared FPC configuration experiment

A tiny console application using JSON, XML, a local unit, and a local include.
The application script knows its own files; the shared configuration knows the
FPC library locations. This is an editable test fixture, not the final shared
configuration layout or an automated unit test yet.

Read these in order:

1. `Installation.nxscript`: this machine's FPC root and target, declared once.
2. `Shared.nxscript`: reusable `StandardFPC` configuration with library paths.
3. `Tiny.ForgePackage.nxscript`: application composes that configuration and adds
   its local source selections and include paths. Unnamed array entries append.
4. `FPC.mustache`: translates the completed properties into compiler switches.

Source is an explicit file/pattern list; EntryPoint is the one application input.
Forge expands selections and supplies `_nx.SourcePaths` to the template, which
translates them into FPC unit search switches.

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

Every application request reaches FPC, even with the executable present. FPC
reuses compatible units and rebuilds dependencies when required. Try changing the
greeting include and running the same command again. No deletion or Forge source
hashing is needed.

The Source lists combine shared FCL selections with the application's local files.
This example establishes the FPC mechanism. LCL/widgetset and fpGUI installation
configurations remain separate follow-up work; no dependency-export framework is
introduced here.
