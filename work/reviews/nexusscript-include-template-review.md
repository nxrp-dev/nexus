# Include Presentation: Existing Mustache Review

Date: 2026-09-15
Status: Inclusion correction and affected Script template updates implemented locally for review.

## Agreed behavior

Included systems contribute definitions to a combined presentation. Definitions
remain intact, shared dependencies contribute once, and conflicting definitions
are errors rather than candidates for implicit merging. Templates should not
need to name every included subsystem to generate their combined tables.

## Findings

Reviewed all 14 repository Mustache files found by `rg --files -g '*.mustache'`.

| Files | Current behavior | Treatment |
| --- | --- | --- |
| `NexusTools/Script/parity/schema-generation/mustache/DatabaseSchema.create.mustache` | Repeats domain/table generation sections for named `Storm` and `inForce` roots. | Actual workaround for separate roots; replace repeated generation blocks with combined collections once presentation is established. |
| `NexusTools/Script/parity/schema-generation/mustache/AutoProviderList.prv.mustache` | Repeats provider generation for `Storm` and `inForce`, also creating a named provider category per system. | Remove hardcoded contributor names, but preserve intentional per-system provider categories. |
| `NexusTools/Schema/firebird/DatabaseSchema.create.mustache` and `AutoProviderList.prv.mustache` | Iterate `NexusSchema.MetaData.Modules` supplied by the separate legacy Schema producer. | Evidence that the older presentation exposed a module collection. Do not change templates independently of that producer; they are not consumers of the current generic Script JSON. |
| `NexusTools/Schema/firebird/DatabaseImport.import.mustache` | Uses the legacy data-import context. | Separate producer contract; not an include workaround. |
| `NexusTools/Script/parity/schema-generation/mustache/DatabaseImport.import.mustache` and `tests/fixtures/external-data/import.mustache` | Iterate the isolated `DataSource` record context. | Preserve; this is data-source rendering, not traversal of included model roots. |
| `NexusTools/Script/tests/fixtures/json/NexusSchemaShape.mustache` | Traverses an explicitly authored nested structure in its matching fixture. | Tests deliberate domain structure, not automatic include aggregation. Keep that distinction explicit. |
| `NexusTools/Script/tests/fixtures/json/Product.mustache` | Selects one named product and iterates its fields. | Deliberate named lookup; not repeated subsystem generation. |
| `NexusTools/Script/tests/fixtures/cli/Name.mustache` and manifest templates `first.mustache`, `second.mustache`, `combined.mustache` | Select a named example and, for combined output, a named constants definition. | Deliberate named lookup/context tests, not repeated subsystem generation. |
| `NexusTools/Script/tests/fixtures/manifest/templates/included.mustache` | Reads `First.Value`, `Shared.Value`, and `Second.Value`. | Tests named roots and shared-include deduplication, not collection iteration. |

## Concrete integration issue

The existing schema examples place tables in `Schema Storm { Tables: [...] }`
and `Schema inForce { Tables: [...] }`. Collecting only document roots would
expose two Schema definitions but would not expose the combined tables directly.
The presentation correction must account for these actual nested contributions
without flattening away a table's fields, indexes, or provenance.

## Implemented correction

- A shared included-definition view collects each included document once and
  excludes module-only roots. It preserves nested ownership and reference targets.
- JSON exposes kind collections under `_nx.Collections`, alongside named roots.
  The nine-table fixture renders all nine through one `Table` iteration.
- The Script schema template now uses the `Type` and `Table` collections. Its
  duplicated Storm/inForce generation blocks were removed.
- The Script provider template uses the `Schema` collection and retains its
  intentional category-per-system structure without hardcoded system names.
- The separate legacy Schema templates and isolated data-import templates were
  reviewed but not changed because their producer contracts are different.
- Dialect normalization consumes included language fragments through the shared
  view; FPC/Git pieces validate without explicit module composition.
- All 52 compiler tests pass, including the existing manifest/schema-generation
  cases and three new include regression cases. A heap-checked run reports zero
  unfreed blocks. Production changes remain uncommitted for owner review.
- The updated Storm schema template generated all 130 table definitions found in
  the combined view. These are the repository's synthetic schema examples, not
  a claim of historical database parity.
