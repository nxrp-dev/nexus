# Shared FPC configuration experiment

This is a generic Forge FPC task, not a package definition. The tiny console
application uses JSON, XML, a local unit, and an include file.

- Installation.nxscript records this machine's FPC paths.
- Shared.nxscript contributes compiler and search-path values.
- Tiny.Forge.nxscript composes those values with its own source, entry point,
  output, and the ordinary FPC.mustache command template.

From the repository root, prepare the explicit output directory and run:

~~~powershell
New-Item -ItemType Directory -Force output/ForgeSharedFPC | Out-Null
& .\output\NexusForge\x86_64-win64\nxforge.exe /input=projects/forge/test/fixtures/shared-fpc/Tiny.Forge.nxscript
& .\output\ForgeSharedFPC\tiny.exe
~~~

The expected output is "Shared FPC: hello world". FPC handles unit freshness;
Forge expands the Source selections into search directories and runs one
explicit compiler task.
