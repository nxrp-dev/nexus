# NexusPackageManager

NexusPackageManager is an fpGUI workbench for developing the Package,
PackageIndex, and Project NexusScript dialects. These are provisional entity
definitions, not Forge tasks or a package manager.

Build with `lazbuild projects/PackageManager/NexusPackageManager.lpi`. Open the
application and choose a file from `projects/PackageManager/examples/`, or pass
an example filename on the command line. The editable pane embeds the reusable
`TNXScriptEditor` widget. F2 or double-click edits a value or definition name;
right-click or Insert offers the actions allowed by the document's dialect.
Ctrl+Z and Ctrl+Y undo and redo accepted edits. Save and Reload operate on the
widget's document, and unsaved changes are confirmed before opening another
file, reloading, or closing.

The read-only script pane and diagnostics update after accepted edits.
The script pane displays the current source, including comments and dialect
declarations, rather than the compiled definitions. Validate reruns the checks
against the current unsaved source. The widget
owns the editing state, undo history, dirty tracking, and byte-preserving save;
PackageManager validates a read-only source snapshot for package/index
boundary checks. Rejected edits appear in the diagnostics
pane without changing the accepted source.

## Package declarations

Package requires a nonblank `Id`. `Version`, `Author`, `Description`, and
`License` are optional text metadata. Package is authoritative for its intrinsic
metadata and requirements. `Requires` is an optional array of ordinary NexusScript
references to `LocalPackage` or `ExternalPackage` records in one explicitly imported
PackageIndex. An absent or empty array means no requirements and needs no index.

```text
module NexusPackages "PackageIndex.nxscript";

Package Example {
    Id: "NXRP.Example";
    Requires: [@NexusPackages.NexusLib, @NexusPackages.SQLite];
}
```

The module is an available local NexusScript document, not a remote repository
lookup. Missing modules/records produce diagnostics. Binding a record does not
obtain or satisfy the represented package. Unavailable package content and
unreachable canonical repository addresses remain valid declarations.
Quoted IDs, Id-property references, repository targets, and inline dependency
definitions are rejected. Optional array labels are language labels, not IDs.
Multiple imported indexes are diagnosed as ambiguous when requirements need
a context; no catalog is selected or merged implicitly. Compiler lookup between
unrelated local roots is unchanged.

The human identity convention is
`<ReleaseEntity>.<PackageName>[.<optional qualifiers>...]`, for example
`NXRP.NexusScript`, `FreePascal.FPC`, or an independently released `NXRP.FPC`.
The complete ID is opaque: its spelling and case are preserved, its parts are
not parsed, and identity is not derived from a filename, definition label,
repository, version, or license. Naming and global uniqueness remain authoring
responsibilities; the workbench does not certify them.

## Published package universe and canonical sources

PackageIndex contains zero or more direct children of these kinds:

| Record | Required fields | Purpose |
| --- | --- | --- |
| `LocalPackage` | `Id`, `Descriptor` | A package provided by this repository. |
| `TrustedRepository` | `Source` | An explicitly trusted canonical source-control repository. |
| `ExternalPackage` | `Id`, `Repository` | A required external package supplied by that trusted repository. |

Record labels are NexusScript reference names, not identities. ExternalPackage's
Repository is a single `@` reference to a TrustedRepository declared by the same
index. A repository in another index cannot satisfy this association or expand
trust. Source is preserved canonical repository-address text, not a mirror,
descriptor URL, or download command. There is no mirror, fallback, equivalent-source,
automatic traversal, reciprocal trust, or transitive trust behavior.

```text
PackageIndex NexusPackages {
    TrustedRepository ExternalPackages {
        Source: "<canonical source-control address of nexus-packages-ext>";
    }
    LocalPackage NexusLib {
        Id: "NXRP.NexusLib";
        Descriptor: "NexusLib/Package.nxscript";
    }
    ExternalPackage SQLite {
        Id: "SQLite.SQLite";
        Repository: @NexusPackages.ExternalPackages;
    }
}
```

Declared records are the catalog, not directories to scan. Descriptor is a relative
file locator based on the index document's directory within its own repository.
URLs, absolute paths, search masks, and explicit directory-only locators are
rejected. File existence, descriptor identity agreement, and repository-root
containment at retrieval time are not checked; no descriptor is opened while
validating the index. LocalPackage's source is its owning repository; it has no
repository selector. ExternalPackage records an Id and repository association,
not a duplicated remote address or descriptor path.

Both package-record kinds allow optional Version and Description for catalog
browsing without opening descriptors. These are advertised summaries, not overrides
of the authoritative Package. Author, License, Requires, and arbitrary metadata
are not duplicated. No automatic synchronization, summary reconciliation,
duplicate-ID policy, or version-selection/solving policy is performed.

`nexus-packages` houses our own packages. `nexus-packages-ext` houses externally
authored packages for packaging purposes. A LocalPackage means supplied here,
not authored by us: the external repository also uses LocalPackage records for
its hosted packages. The first-party index explicitly declares trust and the
external packages it requires; trust does not automatically import another catalog.
Shared hosting does not grant trust. Hosting an external package does not rewrite
its package identity, author, or license. The GUI examples illustrate those
roles, not the repositories' actual inventories. Repository-address placeholders
are labeled and are never contacted.

## Provisional content hashes

A LocalPackage may have one provisional `ContentHash` child, with required nonblank
text `Algorithm` and `Digest`. These are advertised hash data only: algorithms
and digest encodings are not restricted, and nothing is hashed or verified.
Hash presence does not establish trust, affect identity, or add dependency data.
Final hash ownership between Package and PackageIndex, the exact content/bytes
to hash, and verification mechanics remain undecided. The fixture
`test/fixtures/IndexWithHash.nxscript` contains explicitly synthetic editing data.

## Examples and checks

`Package.nxscript` and `PackageIndex.nxscript` illustrate first-party metadata,
an explicitly imported index, and local/external requirement references.
`ExternalPackage.nxscript` and `ExternalPackageIndex.nxscript` illustrate an
externally authored package whose identity is independent of our hosting.
Project remains the unchanged provisional empty entity; no Project design,
Forge integration, dependency resolver, or package-management workflow is added.

Imported indexes are validated using the compiled sources already loaded by the
session. Original reference targets retain declaration identity and repository
provenance; projections do not become owned Package children. The Package editor
shows only its entry source and offers dialect-filtered reference choices.
Open an index separately to edit it, save it explicitly, and reload/revalidate the
Package to read that saved context. The GUI does not create module directives or
perform hidden multi-document saves.

Build and run the focused tests with:

```text
lazbuild projects/PackageManager/test/NexusPackageManagerTests.lpi
output/NexusPackageManagerTests/x86_64-win64/NexusPackageManagerTests.exe
```

The earlier local-cross-root dependency fixture is retained unchanged and remains
paused at the owner's request; the runner reports that it is not executed. New
imported-index requirement tests cover the revised model independently.
