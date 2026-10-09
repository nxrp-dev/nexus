# nxpackage

nxpackage is an fpGUI workbench for editing package definitions and machine or
published-repository catalogs through one NexusScript dialect. Its three roots
are Package, PackageIndex, and RepositoryIndex. These are declarative documents,
not Forge tasks. Projects are outside this dialect and application.

Build with `lazbuild projects/nxpackage/nxpackage.lpi`. Open the
application and choose a file from `projects/nxpackage/examples/`, or pass
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
nxpackage validates a read-only source snapshot for package/index
boundary checks. Rejected edits appear in the diagnostics
pane without changing the accepted source.

## Package declarations

Package requires a nonblank `Id`. `Version`, `Author`, `Description`, and
`License` are optional text metadata. Package is authoritative for its intrinsic
metadata and requirements. `Requires` is an optional array of ordinary NexusScript
references to `LocalPackage` or `ExternalPackage` records in one explicitly imported
PackageIndex or RepositoryIndex. An absent or empty array means no requirements
and needs no index.

```text
module NexusPackages "RepositoryIndex.nxscript";

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

## Machine and published-repository catalogs

PackageIndex is the machine-level catalog: packages with local descriptor
locations, known repositories, and packages reachable through those repositories.
The package pool's local index can span several repository checkouts.

RepositoryIndex is one repository's published catalog. Its LocalPackage records
describe packages supplied by that repository. Trusted sister repositories and
ExternalPackage records describe external sources and requirements; they do not
claim those packages are supplied here.

Both indexes contain zero or more direct children of these kinds:

| Record | Required fields | Purpose |
| --- | --- | --- |
| `LocalPackage` | `Id`, `Descriptor` | A local descriptor in PackageIndex; a package supplied here in RepositoryIndex. |
| `TrustedRepository` | `Source` | An explicitly trusted canonical source-control repository. |
| `ExternalPackage` | `Id`, `Repository` | A package available through that trusted repository, not supplied locally. |

Record labels are NexusScript reference names, not identities. ExternalPackage's
Repository is a single `@` reference to a TrustedRepository declared by the same
index. A repository in another index cannot satisfy this association or expand
trust. Source is preserved canonical repository-address text, not a mirror,
descriptor URL, or download command. There is no mirror, fallback, equivalent-source,
automatic traversal, reciprocal trust, or transitive trust behavior.

```text
RepositoryIndex NexusPackages {
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
file locator based on the index document's directory. For RepositoryIndex it
locates a descriptor in that repository; for PackageIndex it locates a descriptor
in the machine's package pool.
URLs, absolute paths, search masks, and explicit directory-only locators are
rejected. File existence, descriptor identity agreement, and repository-root
containment at retrieval time are not checked; no descriptor is opened while
validating the index. LocalPackage has no repository selector.
ExternalPackage records an Id and repository association,
not a duplicated remote address or descriptor path.

Both package-record kinds allow optional Version and Description for catalog
browsing without opening descriptors. These are advertised summaries, not overrides
of the authoritative Package. Author, License, Requires, and arbitrary metadata
are not duplicated. No automatic synchronization, summary reconciliation,
duplicate-ID policy, or version-selection/solving policy is performed.

`nexus-packages` houses our own packages. `nexus-packages-ext` houses externally
authored packages for packaging purposes. A LocalPackage means supplied here,
not authored by us: the external RepositoryIndex also uses LocalPackage records
for its hosted packages. The first-party repository index explicitly declares trust and the
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
Final hash ownership between Package and its catalogs, the exact content/bytes
to hash, and verification mechanics remain undecided. The fixture
`test/fixtures/IndexWithHash.nxscript` contains explicitly synthetic editing data.

## Examples and checks

`Package.nxscript` imports `RepositoryIndex.nxscript` for illustrative package
requirements. `PackageIndex.nxscript` is the separate machine-catalog example.
`ExternalPackage.nxscript` and `ExternalRepositoryIndex.nxscript` illustrate an
externally authored package whose identity is independent of our hosting.
There is no Project root, Forge integration, dependency resolver, or
package-acquisition workflow.

Imported indexes are validated using the compiled sources already loaded by the
session. Original reference targets retain declaration identity and repository
provenance; projections do not become owned Package children. The Package editor
shows only its entry source and offers dialect-filtered reference choices.
Open an index separately to edit it, save it explicitly, and reload/revalidate the
Package to read that saved context. The GUI does not create module directives or
perform hidden multi-document saves.

Build and run the focused tests with:

```text
lazbuild projects/nxpackage/test/nxpackageTests.lpi
output/nxpackageTests/x86_64-win64/nxpackageTests.exe
```

The earlier local-cross-root dependency fixture is retained unchanged and remains
paused at the owner's request; the runner reports that it is not executed. New
imported-index requirement tests cover the revised model independently.
