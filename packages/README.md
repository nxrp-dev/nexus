# Package catalog drafts

[Packages.PackageIndex.nxscript](Packages.PackageIndex.nxscript) is the explicit
machine-level inventory for this package pool. It records local descriptor
locations and known repositories, and can advertise packages reachable through
those repositories. Its descriptor locations are relative to this folder.
It lists packages directly; discovering them does not require recursing through
directories or following repository links.

[nexus-packages/Packages.RepositoryIndex.nxscript](nexus-packages/Packages.RepositoryIndex.nxscript)
is the RepositoryIndex published by the independent `nexus-packages` repository.
Its local descriptor locations are relative to that repository; external
requirements identify a package in a trusted sister repository.
Each package has its own `Package.nxscript` beside its source folder; that
definition owns the package's intrinsic metadata and requirements. Projects are
outside this package dialect.

[nexus-packages-ext/Packages.RepositoryIndex.nxscript](nexus-packages-ext/Packages.RepositoryIndex.nxscript)
is the RepositoryIndex published by our third-party package repository. It describes Mustache and the compression packages Abbrevia and PasZLib.
Third-party source lives under each package's `external` folder.

The local index names both `nexus-packages` and `nexus-packages-ext` as trusted
repositories. The owned repository's catalog names the external repository as
a sister repository. These declarations do not fetch, traverse, or resolve
anything. The local inventory lists Mustache's descriptor directly rather than
requiring traversal of the external repository's catalog.

## Draft conventions

- Package IDs use proposed `NXRP.*` qualified names. They are opaque identities,
  not instructions to interpret directory names, ownership, or dependency order.
- The descriptor owns the package's metadata and requirements. The index only
  advertises identity, location, and a short browsing description.
- Versions and content hashes are omitted until actual release and integrity
  values are chosen.
- `Requires` uses ordinary references into one explicitly imported repository
  index. Only direct dependencies on independently described packages are listed.
  There is no automatic resolution, building, ordering, or acquisition.
- Directory nesting is not a dependency. `db` and `network` are grouping folders;
  `serialization` has its own source as well as separately described children.
- Test runners, language servers, command-line front ends, and the Nexus2D
  engine/simulator remain projects, not packages in this catalog.

For example, the Solar2D integration descriptor is:

```nexusscript
dialect "nxpackage.Language.nxscript";
module NexusPackages "../Packages.RepositoryIndex.nxscript";

Package Solar2D {
    Id: "NXRP.Solar2D";
    Author: "Kevin Collins";
    Description: "Solar2D native plugin API and Pascal event bridge.";
    License: "MPL-2.0-no-copyleft-exception";
    Requires: [@NexusPackages.Lua];
}
```

## Known incomplete information

Core and Binding are independently described packages. The Pascal project and
compiler-option models are project-owned under projects/nxbuild/src.

Some real prerequisites have no independent package descriptor in this catalog:
Synapse, the compiler's platform-specific FFI support,
and external runtime/host libraries. The affected descriptors identify those
prerequisites in comments. Their absence from `Requires` does not mean those
packages are self-contained. This draft does not invent identities or
repository records to conceal the missing descriptions.

`Author` identifies the Nexus implementation author; upstream notices are
unchanged. Package-wide `License` is left unset for GUI, Lua, and SQLite rather
than describing their mixed upstream/reference/runtime contents as wholly
MPL-licensed. Other descriptors record the Nexus source license.

## Validation with the existing dialect

The drafts name the current nxpackage entity dialect through a caller-owned
dialect catalog. They contain no paths reaching from packages into projects.
From the Nexus repository root, validate a descriptor with:

```powershell
& .\output\NexusScript\x86_64-win64\NexusScript.exe `
    /input=packages/nexus-packages/solar2d/Package.nxscript `
    /dialect-root=projects/nxpackage/language `
    /validate
```

The existing compiler supports this catalog setting. The nxpackage GUI
currently does not configure a dialect root, so these catalog-relative dialect
names are not yet resolved when opening the drafts there. No compiler, editor,
dialect, or Forge implementation changes are included in this data-only draft.
