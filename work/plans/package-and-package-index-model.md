# Work Plan: Package and PackageIndex Model

Date: 2026-10-06
Status: revised plan only; source inspected, no code changes, builds, or verification runs in this revision.

## Inputs

- The owner's revised request: `C:\Users\kcollins\.codex\attachments\136a277d-ca63-4b62-9a90-969320f0c66c\Pasted text.txt`.
- Repository roles supplied by the owner: `nexus-packages` houses our packages; `nexus-packages-ext` houses packages that are not ours, for packaging purposes. Addresses and actual inventories have not been supplied or verified.
- The owner's clarification that cross-local-root references are name lookups, not an approved extension of `@` lookup. The earlier failing cross-root fixture remains unchanged and its verification remains paused.
- Current PackageManager dialect, document checks, examples, tests, and reusable NexusScript compiler/validator/editor source. Earlier plans are historical context, not authority over this revised request.
- Repository architecture/work-plan protocols. This replaces this plan in place, without stages, gates, or approval scaffolding. Implementation remains local; no sub-agent use is authorized.

## Summary

Make PackageIndex a repository's declared package universe: its directly provided packages, its trusted canonical source-control repositories, and its externally required packages with explicit canonical provenance. Package remains authoritative for intrinsic metadata and declares requirements by ordinary NexusScript references to those index records.

Replace flat Discovery and descriptor-location-only catalog records, and replace plain-ID-string requirements. This does not create a resolver: binding an explicitly imported NexusScript record is not obtaining or satisfying the package represented by it.

## Verified Findings

- `projects/PackageManager/language/PackageManager.Language.nxscript` is the current shared dialect. Package already has Id, Version, Author, Description, License, and text-array Requires. PackageIndex has text-array Discovery and direct PackageEntry children containing Id and Descriptor. PackageEntry permits one provisional ContentHash child. Project remains an empty root.
- `obNXPackageManagerDocument.pas` checks nonblank identities, requirement strings, Discovery addresses, relative descriptor-file locator syntax, and hash fields. It does not read advertised descriptors or contact repositories. It cannot yet validate canonical-source associations or record-reference requirements.
- The main form embeds `TNXScriptEditor`. The editor owns accepted source, undo/redo, dirty state, and saving; the host validates a read-only snapshot and shows synchronized source and diagnostics. Keep that ownership and the source pane.
- NexusScript imports available documents with `module "file.nxscript";`, or selects a root with `module RootName "file.nxscript";`. `ResolveMember` in `obNexusScriptCompiler.pas` permits `@ImportedRoot.Child` through imported roots, but not through unrelated local sibling roots. `obNexusScriptSession.pas` already implements module loading. No new cross-local-root lookup is needed for the proposed documents.
- Dialect rules already support array EntrySourceForms, EntryEffectiveCategories, and DefinitionKinds, plus scalar reference Targets and DefinitionKinds. They can describe the proposed references without another dependency language.
- A definition reference retains ResolvedDefinition provenance and also creates a receiving structural projection. These are not interchangeable: projections can be renamed/reparented and omit definition-valued arrays. Read identity and provenance from the original target, not a projection or reference label.
- There is a concrete validation mismatch: `obNexusScriptValidator.pas` treats structural array items, including reference projections, as contained children and applies parent/child rules to them. A referenced index record would therefore be checked as if Package owned it. `TNexusScriptDefinitionView.CollectValue` already treats references as references, not new definition contributions. The editor's CountChildren has the same containment mismatch.
- Array Names validation uses effective names, and an unnamed definition reference inherits its target's name. Keeping `Names: Forbidden` would reject ordinary record references even without explicit array labels.
- Array reference choices are unfiltered: `TNXScriptEditor` passes no scalar reference rule when adding/editing array entries; GetReferenceChoices(nil, ...) offers definitions and properties from all compiled roots. The new model needs array-kind and lexical-scope filtering, not package search.
- Shared analysis validates the entry document's definition view, excluding imported roots. PackageManager must validate the selected imported index in its own compiled document rather than assume import validates its schema/domain rules. Current entity-type calculation includes imported roots, so Package plus imported PackageIndex would incorrectly display as Mixed.
- The paused fixture uses `@Base.Requires` across unrelated local roots. That is neither evidence that imported-index references are unavailable nor permission to change compiler lookup or rewrite the paused fixture.

## Architecture Problem

Discovery addresses do not identify which canonical repository supplies an external package, and a plain dependency ID does not select an index record carrying that relationship. Putting repository information on Package would assign trust to the wrong owner. Treating referenced index records as Package children would repeat that ownership mistake through validation.

Correct this with index-owned records and references that retain their targets' identity and provenance without transferring declaration ownership.

## Target Contract

### Index records

Use three distinct direct child kinds under PackageIndex. Their differences stay visible in the dialect and GUI without mode flags or fields whose meaning changes by context.

| Kind | Required properties | Optional catalog summary | Meaning |
| --- | --- | --- | --- |
| `LocalPackage` | `Id`, `Descriptor` | `Version`, `Description` | Package provided directly by this index's repository. |
| `TrustedRepository` | `Source` | None initially | Explicitly trusted canonical source-control repository. |
| `ExternalPackage` | `Id`, `Repository` | `Version`, `Description` | Externally required package supplied by the referenced TrustedRepository. |

All three are non-root definitions permitted only under PackageIndex; it allows zero or more of each. Replace Discovery and PackageEntry in this dialect, without parallel representations or compatibility aliases.

Definition names are NexusScript reference labels, not package identities or repository identifiers. Id is nonblank text. Source is nonblank text identifying the canonical source-control repository, not a descriptor URL, mirror, or download command. Preserve its declared address; do not decide Git URL normalization, authentication, revision selection, or transport policy.

Descriptor remains a relative file locator based on the index document's directory in its own repository. Check its declared relative-file form, not existence or retrieval-time containment. LocalPackage needs no repository selector: its source is the index's own repository. ExternalPackage needs no duplicated source address or remote descriptor locator; its identity and single repository reference establish the association required here.

ExternalPackage.Repository is an ordinary `@` reference to a TrustedRepository declared by the same owning PackageIndex. Reject quoted addresses, arrays of repositories, wrong target kinds, property targets, and repositories from another index. Check declaration provenance, not merely kind or matching address text. Imported copies must preserve this association; a projection's receiving parent is not its declaration owner.

TrustedRepository declares trust by its presence. No separate Trusted switch is needed. ExternalPackage does not grant trust. Encountering another index cannot silently expand this index's repositories; neither reciprocal nor transitive trust is inferred.

### Package and requirements

Keep Package's required nonblank Id and optional text Version, Author, Description, and License. Package remains authoritative for those fields and its requirements. Do not add repository properties or children.

Keep the human convention `<ReleaseEntity>.<PackageName>[.<optional qualifiers>...]`. Preserve the complete ID exactly, including case. Do not parse components, infer repositories, enforce reverse-DNS rules, or derive version/license meaning. Labels and filenames do not supply identity. Global uniqueness cannot be certified by this offline workbench.

Change Requires to an optional array whose entries reference LocalPackage or ExternalPackage records. Missing or empty means no requirements. Enforce reference source form, effective Definition category, allowed target kinds, and membership in the relevant index. Reject quoted IDs, references to record Id properties, Package descriptors, TrustedRepository records, and inline dependency definitions. An ordinary property reference yielding an array may retain existing NexusScript behavior if its effective entries meet this same contract; do not expand lookup to enable it.

Use `Names: Optional` rather than Forbidden because normal references inherit effective record names. An explicit entry label remains a language label, never a second package ID. The existing array-rule vocabulary is sufficient:

```text
Array Array {
    Names: Optional;
    EntrySourceForms: [Reference];
    EntryEffectiveCategories: [Definition];
    DefinitionKinds: [LocalPackage, ExternalPackage];
}
```

Establish the workbench Package document's relevant index with the existing explicit root-selecting module declaration:

```text
module NexusPackages "PackageIndex.nxscript";
```

That selected PackageIndex is the requirement context; targets must belong to it. A Package without requirements needs no index import. For this work, use one explicit index context per Package document and diagnose ambiguous contexts rather than search for, merge, or select among indexes. Do not add Package.Repository or infer context from an ID or directory name. This is a product document relationship, not a new compiler restriction on modules or roots.

The module file must already be available through the existing source provider. A missing index/record produces a language/model diagnostic. Unavailable package content or an unreachable canonical repository does not invalidate an otherwise valid record: neither is accessed. The index does not import its descriptors, so Package importing its index creates no descriptor/index loading loop.

Binding available NexusScript documents is necessary to interpret `@`; it is not dependency resolution. No package-ID search, remote lookup, acquisition, version decision, satisfaction check, or dependency execution follows.

### Published summaries and authority

Repeat Id so a record identifies its package without opening the descriptor. Allow optional Version as an advertised release label and Description for browsing. Both have direct catalog value. Do not duplicate Author, License, Requires, or arbitrary metadata just because Package contains them.

Descriptor metadata remains authoritative; catalog summaries are not overrides. Do not automatically open descriptors to synchronize or check them, create a publisher, or compare external summaries with remote content. Until a separate verification workflow exists, consistency is the publisher's responsibility. Version has no ordering, constraint, or solving semantics.

### Canonical sources and the two repository roles

The nexus-packages index can provide our packages directly and explicitly trust nexus-packages-ext as the canonical source of packages housed there. Its ExternalPackage records identify the particular external packages required. Trusting a repository does not automatically add its whole catalog.

The nexus-packages-ext index uses LocalPackage for packages it directly houses, even when externally authored. Local means provided by this repository, not authored by us. Hosting does not rewrite Id, Author, or License and does not grant reciprocal trust.

Use illustrative offline documents for both roles, without assuming addresses/inventories or modifying those repositories. Every ExternalPackage selects one canonical repository. Do not represent mirrors, equivalent sources, fallback, or automatic replacement.

### Hash remains open

Final ownership between Package and PackageIndex remains undecided, as do content boundaries, algorithm/encoding rules, and verification mechanics. Carry the existing ContentHash fixture on the renamed LocalPackage solely as a provisional editing example. Updating that parent does not decide that indexes permanently own hashes; do not broaden placement or move hashes into Package during this restructuring.

Keep values labeled synthetic. Editing Algorithm and Digest hashes or verifies nothing. A future comparison can establish that bytes match an advertised value; trust is declared by the index's canonical repository record. Neither concern supplies the other.

### Ownership and GUI behavior

PackageManager owns the package dialect and domain checks. Reuse the compiled NexusScript graph and its reference provenance; do not introduce a duplicate editable domain graph, registry, or resolver.

The editor retains ownership of entry source and accepted edits. An imported index is reference context, not extra editable Package nodes. Open the index separately to edit it. Preserve the read-only source pane, diagnostics, undo/redo, and byte-preserving save/reload. Classify entity type from entry-owned roots only, so Package importing an index still displays as Package.

Validate the selected index's existing session compiler/document against the PackageManager dialect and domain rules. Reuse already loaded source, rather than reread advertised descriptors or follow Source addresses. Preserve source-located diagnostics, including errors originating in the imported index.

The current GUI does not author module directives. Use samples that already contain their explicit index module declaration to exercise reference editing. Do not add automatic imports or a separate module-management UI.

## Illustrative Documents

These propose the revised shape; they are not implemented schemas or actual inventory. Each file retains its current header and explicit PackageManager dialect declaration. Repository addresses and unprovided descriptor locations are illustrative.

`PackageIndex.nxscript`, representing nexus-packages:

```text
PackageIndex NexusPackages {
    TrustedRepository ExternalPackages {
        Source: "<canonical source-control address of nexus-packages-ext>";
    }
    LocalPackage NexusScript {
        Id: "NXRP.NexusScript";
        Descriptor: "Package.nxscript";
        Version: "1.0";
        Description: "NexusScript language support.";
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

`Package.nxscript`:

```text
module NexusPackages "PackageIndex.nxscript";

Package NexusScript {
    Id: "NXRP.NexusScript";
    Version: "1.0";
    Author: "Kevin Collins";
    Description: "NexusScript language support.";
    License: "MPL-2.0-no-copyleft-exception";
    Requires: [@NexusPackages.NexusLib, @NexusPackages.SQLite];
}
```

SQLite is an illustrative external requirement here, not a claim about actual NexusScript dependencies. The nexus-packages-ext example advertises SQLite.SQLite as LocalPackage with its own relative descriptor. It need not trust nexus-packages. Validating the first-party external association does not import that external index or descriptor.

## Concrete Work and Affected Areas

- Reshape `projects/PackageManager/language/PackageManager.Language.nxscript` in place: three index child kinds, selected summaries, repository reference rule, and Requires reference-array rules. Leave Project unchanged. Retain unknown-field/child rejection and record parent restrictions; do not loosen them to let projections pass as Package children.
- Replace string-dependency/Discovery/PackageEntry checks in `projects/PackageManager/src/obNXPackageManagerDocument.pas` with checks on declared records and original targets. Validate the selected imported index using its compiler already in the analysis session. Enforce same-index repository and requirement membership, preserve IDs exactly, and exclude imported roots from entity-type classification.
- Correct the necessary reference/containment distinction in `packages/nxscript/src/obNexusScriptValidator.pas`: references in arrays are values/targets, not newly owned children. Inline definitions and direct children still obey containment/count rules. Keep compiler lookup and structural projection unchanged. Align CountChildren in `obNexusScriptEditDocument.pas` with this ownership rule.
- Make reference choices in `obNexusScriptEditDocument.pas` and `packages/gui/src/obNXScriptEditor.pas` use the value's scalar-reference or array rule and lexical context. Requires offers permitted package records in its selected imported index; Repository offers same-index TrustedRepository records. Do not offer Id properties or unrelated local roots. Generic kind/scope filtering belongs in the reusable editor; product membership validation belongs in PackageManager. Do not hard-code package names into generic language infrastructure.
- Update PackageManager examples, model/editor test units, and provisional hash fixture for explicit modules, local/external records, and repository associations. Add focused regressions wherever necessary shared paths change. Do not rewrite or reinterpret the previously paused cross-local-root fixture as passing.
- Update `projects/PackageManager/README.md` with canonical-source semantics, advertised summaries versus descriptor authority, explicit imports, references, and the non-execution boundary. No main-form layout, widget-set, Project, or Forge redesign is needed.

The shared corrections have a concrete benefit: valid references become editable and validatable without moving declaration ownership or offering invalid targets. They are not general compiler/editor cleanup.

## Verification Plan

These are later implementation checks, not commands run during this planning revision:

```text
lazbuild projects/PackageManager/NexusPackageManager.lpi
lazbuild projects/PackageManager/test/NexusPackageManagerTests.lpi
output/NexusPackageManagerTests/x86_64-win64/NexusPackageManagerTests.exe
lazbuild packages/gui/test/NexusScriptEditorTests.lpi
output/NexusScriptEditorTests/x86_64-win64/NexusScriptEditorTests.exe
```

Exercise affected shared validator/compiler regressions and focused PackageManager/editor tests. Report the paused local-cross-root fixture separately from the new imported-index cases; do not silently change its expectation.

Required coverage:

- Package metadata, absent/empty Requires, exact opaque IDs and case, metadata changes independent of identity, and rejection of repository/build/execution fields.
- Empty indexes, multiple allowed records, relative descriptor declarations, and optional Version/Description summaries. Editing a summary does not modify a descriptor.
- ExternalPackage.Repository binds to exactly one same-index TrustedRepository. Reject strings, repository arrays, wrong kinds, property targets, and repositories from another imported index. An external record grants no trust by itself.
- Package imports its selected available index and references both package-record kinds. Read original Id and repository associations correctly after import/projection. Reject string IDs, inline records, Id-property references, wrong kinds, and targets outside context. Diagnose ambiguity without catalog merging or selecting a source.
- Invalid imported indexes produce source-located schema/domain diagnostics. Imports create neither editable Package children nor a misleading Mixed entry type.
- Array references do not satisfy child minima, consume child maxima, or violate receiver parent rules. Inline definitions still do so where applicable. Preserve compiler projection and module behavior.
- Reference chooser add/edit/source-form changes offer package records for Requires and same-index repository records for Repository, not properties or unrelated roots. Every offered reference must bind through existing language lookup.
- A recording/fail-on-unexpected-read provider allows entry, dialect sources, and explicit index module sources; it rejects advertised descriptor and canonical remote accesses. Replace the old fixed three-source assumption: the explicit index read is now required, not an implicit fetch. Unavailable package contents and unreachable remote addresses remain valid declarations.
- Save/reload preserves reference spelling, modules, dialect declarations, comments, and metadata. Preserve undo/redo, rejected-edit atomicity, source/diagnostic synchronization, and explicit separate-document index save/reload rather than hidden multi-document writes.
- Synthetic hash editing remains provisional and grants no trust. Keep Project smoke coverage unchanged.

Manually open both index and package examples. Add/edit/remove each index record kind, bind an external record to a repository, and add/change/remove Package requirement references. Save the index, reopen/revalidate the Package, and check reference choices, source, diagnostics, and undo/redo. Confirm no descriptor opening or remote access. This exercises the real GUI without package-management operations.

Focused searches of affected paths must confirm removal of Discovery/PackageEntry compatibility shapes and the string-ID-only requirement rule, and no added Package-owned repository declarations, ID parsing, or resolver/acquisition/execution calls. Do not rebuild unrelated projects.

## Open Decisions and Limits

- Hash ownership and exact content remain open; self-hashing, content representation, algorithms, and encoding are not decided by this restructuring.
- Canonical repository authentication and retrieval-time trust enforcement are not implemented. Source records are declarations, not proof of authentication or reachability.
- Multiple index contexts, conflicting advertised identities, release/version selection, and summary reconciliation are not resolver policy to design here. Use one explicit index context without inferring equivalence or a winning source.
- Imported-index validation and reference choices require the concrete changes above. Existing module support is source-verified; the revised combined dialect and GUI interactions are not compiled or tested yet.

## Out Of Scope

Project design; Forge integration or AutoResolve; builds, compiler/output/TargetOS/TargetCPU fields; dependency version solving, satisfaction, ordering, cycles as package-execution policy, acquisition/downloading, installation, caching, publishing workflow, repository recursion, mirrors, equivalent sources, fallback, automatic imports, descriptor synchronization, hash computation/verification, actual package-repository changes, unrelated cleanup/migration, and Task, PasBuild, Solar2D, VTV, or fpGUI changes. Do not change cross-local-root lookup or the paused fixture to conceal the unresolved language question.
