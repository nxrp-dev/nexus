# Work Plan: Package and PackageIndex Model

Date: 2026-10-06
Status: plan only; source inspection performed, no implementation, builds, or tests.

## Inputs

- The owner's current pasted request: `C:\Users\kcollins\.codex\attachments\d53efbe4-2f20-4883-962c-a962efe5e935\Pasted text.txt`.
- The owner's clarification: `nexus-packages` houses our own packages; `nexus-packages-ext` houses packages that are not ours, for packaging purposes. Only publication of this plan has been authorized, not implementation or changes to those repositories.
- Current working files under `projects/PackageManager`, the shared NexusScript dialect/validator/editor implementation, and the repository architecture and work-plan protocols.
- The existing `work/plans/nexus-package-manager.md` provides ownership context, not the final schemas. This request replaces its intentionally undecided Package/PackageIndex model and its earlier compiled-view UI direction; it does not reopen Project or Forge work.
- Existing uncommitted changes, including the reusable editor integration and restored source pane, remain untouched during planning. Implementation remains local; no sub-agent work is requested or authorized.

## Summary

Extend the two provisional entity definitions so the existing PackageManager GUI can exercise intrinsic package metadata, identity-only dependencies, an explicit catalog of descriptor locations, and index-owned repository trust. These are declarations, not package-management actions.

Package owns what it is. PackageIndex owns the list of packages advertised by its own repository and its explicitly trusted remote package sources. A dependency carries only a package ID. Neither entity performs discovery, dependency satisfaction, acquisition, building, or execution.

## Verified Findings

- `projects/PackageManager/language/PackageManager.Language.nxscript` is the actual current dialect. It has Package, PackageIndex, and Project roots; separate Package and PackageIndex dialect files are not present. Package permits only required text `Id` and optional text-array `Requires`. PackageIndex has no properties or children.
- `obNXPackageManagerDocument.pas` uses shared NexusScript analysis and validation. Its package-specific check only rejects a blank Package `Id`; `Trim` is used for that check, not to rewrite the identity. It has no catalog reader, repository traversal, or dependency resolver.
- The main form embeds `TNXScriptEditor`, validates a read-only source snapshot, and displays synchronized read-only source text and diagnostics. The editor remains the owner of accepted edits, undo history, dirty state, and saving. There is no reason to restore a compiled-view pane.
- The reusable editor supports declared properties, arrays, child definitions, parent restrictions, and child-count limits. Its demo dialect exercises these facilities. No new widget, compiler feature, or PackageManager-specific editor is needed for the proposed records.
- NexusScript uses the same parent/child permissions for ordinary child definitions and definitions contained in arrays. Its editor exposes both paths when permitted. An array-only catalog shape would therefore require additional placement rules if ordinary child entry creation were to be forbidden.
- The older `packages/Packages.PackageIndex.nxscript` lists directory strings in `Packages` and has `Discovery: []`. Its declared sibling `PackageIndex.Language.nxscript` is absent. It is not a functioning instance of the new provisional model and is not a migration requirement for this request.
- Current Forge definitions no longer own Package or PackageIndex. Forge tests explicitly assert that their rules are absent. Earlier plans describing runnable NexusPackage ownership are historical, not the current baseline.

## Target Contract

### Package

Keep Package as an independent descriptor. Extend its allowed properties as follows:

| Property | Representation | Meaning |
| --- | --- | --- |
| `Id` | Required, nonblank text | Stable, complete package identity. |
| `Version` | Optional text | Package release metadata; no ordering or constraint semantics. |
| `Author` | Optional text | Authorship metadata, independent of identity and repository trust. |
| `Description` | Optional text | Human-readable package description. |
| `License` | Optional text | License metadata; no prescribed license vocabulary in this work. |
| `Requires` | Optional array of nonblank package-ID texts | Declared required packages, with no repository or execution information. |

Only Id is required for the package itself. Do not invent additional required metadata or unrequested intrinsic fields. An absent or empty Requires array declares no dependencies.

Document the human convention `<ReleaseEntity>.<PackageName>[.<optional qualifiers>...]`. Use examples such as `NXRP.NexusScript`, `NXRP.NexusLib`, `FreePascal.FPC`, and `NXRP.FPC`. Preserve IDs exactly, including case. Neither the definition name nor its filename supplies an ID. Do not split IDs, infer repositories, normalize case, require reverse-DNS spelling, or derive license/version meaning from them. The dotted convention does not become a component-parsing validation rule. Global uniqueness is an authoring responsibility, not something this offline workbench can certify.

Requires remains an array of IDs, not structured dependency records. There are no repository fields, version constraints, hashes, or nested package definitions on a dependency. An unavailable dependency is still a valid declaration.

Package rejects repository declarations and all execution/build properties. Version and License can change independently of Id; changing a release entity is an explicit choice of identity, not automatic fork detection.

### PackageIndex

Represent its catalog as zero or more direct `PackageEntry` child definitions. Each entry has required, nonblank text `Id` and `Descriptor` properties. Entry names are editable NexusScript labels, not package identity.

This is a deliberate choice over retaining the old directory-string `Packages` array: named child records give the GUI ordinary, dialect-constrained add/edit/remove behavior without special array-only placement machinery. The declared entries themselves are the catalog source of truth. There is no directory scan or required recursive discovery step.

Descriptor identifies a descriptor file relative to the index document's directory, within that index's own repository. It is not a directory to search, an NXScript package reference, an external repository address, or an acquisition command. This gives the same declaration a meaningful local or repository-hosted location without choosing a downloader or remote-access protocol. Validate the declaration's nonblank relative-file-locator form, not file existence. Do not claim that a future retrieval boundary or repository-root containment check has been implemented.

The repeated Id in an entry is the catalog key needed to advertise a package without opening its descriptor. The descriptor remains authoritative for intrinsic metadata. Do not copy Version, Author, Description, License, or Requires into the index. Identity agreement between a retrieved descriptor and its catalog entry is a future consumer check; validation of an index does not load its descriptors.

Keep `Discovery` as an optional array of nonblank remote repository-address texts, with an absent or empty array meaning no declared remote sources. Define its meaning explicitly: these are trusted package-source repositories, not casual links or a recommendation list. Keep the address as declared text; do not extract package identity or require branch, revision, credentials, or remote-index naming fields.

The model's discovery/trust universe is the current repository plus the repositories explicitly trusted by this index. Package descriptors and individual catalog entries cannot introduce additional repository sources. Merely naming another index or encountering its Discovery list does not silently grant authority to expand the original trust boundary. This work records these relationships; it does not choose traversal, transitive-trust, lookup priority, or conflict-resolution behavior.

### The two package repositories

- `nexus-packages` is the repository for our own packages.
- `nexus-packages-ext` is the repository in which we house externally authored packages for packaging purposes.

Each repository's PackageIndex catalogs only descriptor files in that repository. The first-party index does not copy the external repository's catalog into its own entries. An index can make the other repository available as a trusted source by explicitly naming its address in Discovery; neither shared hosting nor these repository roles creates automatic or reciprocal trust.

Hosting and release identity remain separate. Housing an external package does not, by itself, rewrite its Id, Author, or License. An independently released NXRP distribution can have an explicitly chosen identity such as `NXRP.FPC`; the implementation must not infer that change from the repository name. Dependencies still carry IDs only, regardless of which repository houses the referenced package.

Use these two roles in representative GUI/test documents, without cloning, restructuring, migrating, or publishing package contents. The owner supplied repository names, not confirmed repository addresses or inventories; plan examples use clearly labeled address placeholders rather than assumed Git URLs or claims about their current contents.

### Provisional content hash

Permit one optional `ContentHash` child on a PackageEntry, with required nonblank text `Algorithm` and `Digest`. It records the hash claim advertised with that entry. It is not an identity, not dependency metadata, and not evidence that content has already been checked.

Its placement on the index entry is explicitly provisional. Final ownership between the Package descriptor and PackageIndex remains open. Do not require hashes, compute them, constrain the supported algorithms, infer a hash target, or report integrity verification in this implementation. Test values used to exercise editing must be labeled synthetic rather than presented as hashes of actual package contents.

A hash can later establish that specific retrieved bytes match an advertised value. It cannot establish repository trust. The trust declaration comes from PackageIndex, not from possessing a hash.

### Ownership and GUI behavior

Keep all package-domain schema and semantic checks in `projects/PackageManager`; keep editing and generic dialect enforcement in the existing shared NexusScript/editor infrastructure. The current NexusScript object graph is sufficient to represent these declarations. Do not introduce a package registry, resolver class, or a duplicate editable domain graph merely to hold the new fields.

The state flow remains: structural edit -> accepted source document -> PackageManager validation snapshot -> diagnostics and synchronized read-only source. Save, reload, undo, and redo continue to use the editor's document. The workbench must not open package descriptors or contact trusted repositories as a side effect of loading, validating, or editing an index.

## Concrete Work

- Extend `projects/PackageManager/language/PackageManager.Language.nxscript` in place. Leave Project unchanged. Define Package metadata and ID-only Requires; define PackageIndex Discovery and its PackageEntry children; define PackageEntry fields and its optional ContentHash child. PackageEntry and ContentHash are not roots. Use existing parent restrictions, required properties, text/array rules, and a zero-or-one child limit for ContentHash. Reject unknown properties and inappropriate children.
- Extend the small domain checks in `projects/PackageManager/src/obNXPackageManagerDocument.pas` for blank dependency IDs, catalog IDs/descriptor locators, Discovery entries, and hash fields. Walk the records actually declared in the current document; do not look up dependencies, read descriptor files, or traverse repositories. Keep diagnostics attached to the offending source ranges. Preserve the draft for correction, as the GUI already does.
- Replace the reverse-DNS/slash-style sample identities in PackageManager examples with the release-entity convention. Give `examples/Package.nxscript` representative metadata and an identity-only dependency. Give `examples/PackageIndex.nxscript` a record pointing to that example descriptor and an explicitly illustrative trusted remote address. Add a focused hash-editing fixture with clearly synthetic values, rather than inventing a verified hash for the sample package.
- Extend `projects/PackageManager/test/tsNXPackageManagerTests.pas` to cover the entity rules and their existing editor integration. Adjust the small standalone projection fixtures for their new source contents where needed; do not redesign or resurrect the unused compiled-view UI.
- Update `projects/PackageManager/README.md` with field meanings, the identity convention, descriptor-locator base, the trust boundary, the provisional hash limitations, and the absence of execution. Preserve the restored source view.
- No production GUI or shared compiler/editor changes are expected. Verify the actual dialect-driven interactions before considering any narrowly necessary integration correction; do not treat generic widget cleanup as part of the package model.

## Illustrative Documents

These show the intended descriptor/index relationship; they are plan examples, not newly implemented schemas. The remote address is a placeholder, not an asserted existing or authenticated source.

```text
Package NexusScript {
    Id: "NXRP.NexusScript";
    Version: "1.0";
    Author: "Kevin Collins";
    Description: "NexusScript language support.";
    License: "MPL-2.0-no-copyleft-exception";
    Requires: ["NXRP.NexusLib"];
}

// Illustrative index for nexus-packages; the address is a placeholder.
PackageIndex Example {
    Discovery: ["<address of nexus-packages-ext>"];
    PackageEntry NexusScript {
        Id: "NXRP.NexusScript";
        Descriptor: "Package.nxscript";
    }
}
```

Each example file retains its existing explicit dialect declaration and source header. The index advertises its own package; the dependency does not say which repository supplies NexusLib. No lookup follows from either statement.

## Verification Plan

During implementation, build the affected application and focused test project:

```text
lazbuild projects/PackageManager/NexusPackageManager.lpi
lazbuild projects/PackageManager/test/NexusPackageManagerTests.lpi
output/NexusPackageManagerTests/x86_64-win64/NexusPackageManagerTests.exe
```

Tests must exercise:

- All Package metadata fields, optional omissions, and zero-dependency cases; changing Version or License leaves Id unchanged.
- Exact preservation of `NXRP.NexusScript`, optional qualifiers, mixed case, and distinct `FreePascal.FPC`/`NXRP.FPC` values. No namespace parsing, case folding, DNS test, or global-registration claim.
- Rejection of missing/blank required IDs and blank dependency IDs, wrong field types, repository-bearing dependency objects, repository declarations on Package/PackageEntry, and build-related properties.
- Empty indexes, multiple declared entries, ordinary entry labels independent of Id, descriptor-file locator declarations, and absent/empty/populated Discovery.
- Representative first-party/external repository-role documents: each catalog contains only its own declared descriptor locations; external-source trust is explicit rather than automatic or reciprocal; hosted package identity and metadata are not derived from the repository name.
- Valid declarations with nonexistent descriptor files, unavailable dependencies, and unreachable remote addresses. A recording or fail-on-unexpected-read source provider should establish that validation reads only the entry/dialect sources needed by NexusScript, not catalog targets or remote sources.
- Optional, well-formed synthetic ContentHash declarations; missing Algorithm/Digest and a second hash object are rejected. Hash presence never changes identity, supplies a dependency field, or grants trust.
- Editor property/child choices for metadata, PackageEntry and ContentHash; add/edit/remove Discovery and Requires items; required-field removal restrictions; PackageEntry unavailable as a root or under Package; ContentHash unavailable under Package or PackageIndex and a second hash not offered.
- Unsaved semantic diagnostics, correction, rejected-edit atomicity, undo/redo, byte-preserving save/reload, and source-pane synchronization including comments and dialect declarations. Keep the existing Project smoke coverage without extending its schema.

Manually exercise both examples in PackageManager: edit package metadata; add/remove an entry; edit its descriptor location; edit trusted repository declarations; add/edit/remove a synthetic hash; save/reload and undo/redo. Confirm no network activity or automatic descriptor opening, and that diagnostics and source text remain visible. User-visible launches belong to implementation verification, not this planning pass.

Use focused source/schema searches to confirm the permitted fields and that no Forge references, repository-qualified dependency model, ID-component parsing, or execution state was introduced. Do not rebuild unrelated Forge, Solar2D, or toolchain projects for this change.

## Deliberately Undecided

- Whether the hash ultimately belongs in Package or PackageIndex, and exactly which content it hashes: descriptor bytes, a defined package-content representation, or an artifact. Without a content boundary and representation, computing a hash would create an unsupported integrity contract. Descriptor ownership also needs to account for whether the hash field itself is included in the hashed content.
- Hash algorithm selection, digest encoding, content canonicalization, and verification mechanics.
- Discovery/resolution algorithms, interpretation of another index's trust declarations, lookup priority, catalog collisions, and multiple releases sharing an ID. Do not invent duplicate-ID/version-selection policy simply to make the catalog look complete.
- Remote repository/index addressing beyond the declared repository address, trusted-index provenance/authentication, retrieval, and enforcement of repository containment when retrieval is eventually implemented.

These uncertainties do not prevent exercising the declarations and their GUI editing behavior. They prevent claiming that discovery, resolution, trust authentication, or content verification already works.

## Out Of Scope

Forge integration or AutoResolve; Project design; package builds, installation, publishing, acquisition, downloading, resolver/dependency ordering/cycles, recipe lookup, caching, version constraints or solving, filesystem discovery recursion, reverse-DNS semantics, DNS ownership checks, centralized registration, and repository-wide descriptor/index migration. Do not modify PasBuild, Task, Solar2D, fpGUI, or unrelated code. Do not create compatibility aliases to the old Forge package model.
