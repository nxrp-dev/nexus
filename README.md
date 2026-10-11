# Nexus

Nexus is a Pascal-focused project family for building tools, applications, schemas, tests, and language-server support.

Current major areas:

- `packages/nexus-packages/gui`: TNX-facing Pascal GUI framework source, tests, docs, resources, and bin over external fpGUI.
- `NexusForge`: schema and generation tooling.
- `projects/nxbuild`: nxbuild, the NexusScript project builder.
- `projects/profiler`: NexusProfilerImport, the NexusFPC profiling trace importer.
- `NexusTools`: repository infrastructure and support tools.
- `packages/nexus-packages`: shared runtime packages, including core helpers and source-independent binding.
- [Recovered MIDAS/DataSnap transport](packages/nexus-packages/network/datasnap/README.md): preserved client/server source, dependency context, and historical variants for future integration.

The documentation site is built with Material for MkDocs. Start with `docs/index.md` or run MkDocs from the repository root.

Project origins, upstream authors, import dates, and SPDX license indicators across
the Nexus repositories are recorded in [ATTRIBUTIONS.md](ATTRIBUTIONS.md).

## Build

`Nexus.Forge.nxscript` is the explicit native Win64 build list for this checkout.
Its shared tool paths and SDK settings are in `Nexus.BuildTools.nxscript`.
Run it from the repository root with the existing Forge executable:

```powershell
& .\output\NexusForge\x86_64-win64\nxforge.exe /input=Nexus.Forge.nxscript
```

The existing `output/nxbuild/x86_64-win64/nxbuild.exe` builds nxbuild into
`output/nxbuild-next/x86_64-win64`. Subsequent tasks use that new builder.
Forge builds into `output/NexusForge-next/x86_64-win64`, without replacing the
running Forge executable. Promoting either replacement is a separate operation.

The script builds applications, test executables/modules, samples, the LLVM
bzip2/C++ check, and NexusCode's JavaScript bundle. It does not run the tests,
launch applications, install dependencies, deploy extensions, or publish.
Groups execute in declaration order and stop at the first failure.
Small Forge/nxbuild compiler fixtures and the Lazarus-only example are not
components in this build list.

Prerequisites are the existing Forge/nxbuild runners, sibling NexusFPC checkout
with built RTL/FCL units, package checkouts, LLVM, the Windows SDK/CRT paths
listed in the script, and Node/npm with NexusCode's dependencies already
installed. The bzip2 build proves the LLVM operation; it does not replace all
of Abbrevia's native libraries or its Pascal bindings' existing object inputs.
