# Nexus Setup

Setup consumes the common NexusScript compiler through a native Live snapshot.
It owns its installation declarations and selection model, independently of
Forge and PackageManager.

Implemented:

- Product metadata, recursive features, logical locations, file/tree payloads,
  shortcuts, dependency identity, owned/shared declarations, and separate
  acquisition/installer data.
- Required/default seeds within a caller-supplied applicable set, transitive
  cyclic feature closure, exclusive immediate-child checks, explicit/implied
  selection, dependency membership deduplication, and deselection explanations.
- Capture of authored entry/dialect/include/module source, selected targets,
  and wildcard selections. Frozen source context recompiles without reading
  current file contents; each replay produces an independent model.
- Logical-location composition and resolved plans.
- File/tree installation, version-aware replacement, explicit preservation,
  durable installed-file evidence, retained-payload repair, uninstall, rollback
  and explicit interrupted-operation recovery.
- A builder that appends payload and original source context to the unbundled
  runtime, followed by a reverse footer. The runtime input is never overwritten.
- A compact fpGUI/TNXSkin installer wizard: Welcome, installation folder,
  components, review, installation and completion. TNXVirtualTreeView presents
  the owned component hierarchy; raw source and compiler diagnostics are not
  displayed as installer content. Declarations remaining after target filtering
  are treated as applicable. File operations execute synchronously on the
  calling GUI thread, without a worker or timer.

Build/run from the repository root:

```powershell
lazbuild projects\setup\NexusSetup.lpi
lazbuild projects\setup\NexusSetupBuilder.lpi
& .\output\NexusSetup\x86_64-win64\NexusSetup.exe projects\setup\examples\Files.nxscript
```

Use Next to choose an absolute installation folder and select components, then
review the choices and click Install. Nothing is written while navigating.
Completion appears only after installation succeeds; errors leave review
available for correction or retry. When the selected folder has recorded
installation state, review also offers Repair and Uninstall. Repair reuses saved
choices and location bindings; Uninstall uses recorded ownership, not the
current checkbox selection. The development runtime can
install files directly, but only bundled installations retain payload for repair.

Build a standalone installer:

```powershell
& .\output\NexusSetupBuilder\x86_64-win64\NexusSetupBuilder.exe projects\setup\examples\Files.nxscript output\NexusSetup\x86_64-win64\NexusSetup.exe output\FileExampleSetup.exe
```

Additional builder arguments are selected targets in `Name=Value` form.
The builder retains all declared feature payloads, including optional features.
The packaged executable opens its embedded definition without a source checkout.
Scripts are recompiled by the common compiler to Live objects, not loaded from
JSON or a generic SQLite graph.

Explicit noninteractive operations:

```powershell
& .\output\FileExampleSetup.exe --install "C:\Example" --log install.log
& .\output\NexusSetup\x86_64-win64\NexusSetup.exe --repair "<installation-state-file>" --log repair.log
& .\output\NexusSetup\x86_64-win64\NexusSetup.exe --uninstall "<installation-state-file>" --log uninstall.log
& .\output\NexusSetup\x86_64-win64\NexusSetup.exe --recover "<state-folder>" --log recovery.log
```

These commands write only when explicitly invoked. Exit code is zero for success
and nonzero for failure. The Windows GUI executable has no console; use
`--log` for the operation result.

The separate `examples/Nexus.nxscript` uses real Nexus sources, cyclic feature
requirements, shared VS Code and an owned VSIX declaration. It is an inspection
fixture, **not a complete Nexus distribution manifest**. Its dependency package
sources are illustrative, not usable acquisition/provider configurations.

```powershell
lazbuild -B projects\setup\test\NexusSetupTests.lpi
& .\output\NexusSetupTests\x86_64-win64\NexusSetupTests.exe
lazbuild -B projects\setup\test\NexusSetupUITests.lpi
& .\output\NexusSetupUITests\x86_64-win64\NexusSetupUITests.exe
```

Both runners enable heap checking. The native runner also enables range,
overflow, and I/O checks. The UI runner initializes fpGUI and the Nexus skin
before constructing controls. Windows x64 is the verified platform.

State lives under `<ApplicationRoot>/.nx/setup/<product-id-key>/`; it records
actual installed paths, choices, concrete location bindings and original source.
Bundled installations also retain `payload.zip`.

Ordinary unversioned files may be replaced on upgrade and removed on uninstall
even if locally modified, as with normal Inno file policy. Use
`PreserveExisting` for seeded user data and `KeepOnUninstall` for retained data.
Skipped preexisting files are never silently adopted.

No embedded scripting or conditional-expression mechanism was added. Shortcut
execution, MSI/VSIX/Exe providers, downloads, VS Code integration, automatic
Known Folder bindings, privilege elevation and platform installer registration
remain deferred. Unsupported selected operations fail before payload writes.
Nexus inventory/layout is intentionally not prescribed. Forge is unchanged.
See [implementation and limits](doc/implementation.md).
