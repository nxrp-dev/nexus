# inForce and Storm schema examples

The maintained models, Firebird constants, and Mustache templates live here in
the common library. They were adapted from the retired NexusSchema tool; its
parser, transformation classes, and old `.nxs` inputs are no longer required.

- `models/`: ordinary NexusScript models for inForce and Storm.
- `constants/`: explicit Firebird conventions.
- `mustache/`: templates adapted to generic completed-model JSON.
- `manifests/`: existing NexusScript manifest entry points.
- `data/`: synthetic demonstration lookup/preload datasets, not production data.

These existing manifest examples remain available while Forge consolidation
continues. For standalone CSV compilation with explicit SQL escaping, use
`NexusLib/script/tools/CSV/CSV.nxscript` and `SQL.mustache`; the ordinary Forge
package example is `NexusLib/script/examples/csv/Lookup.ForgePackage.nxscript`.

## Current template adaptation

The working models expose `Tables` and `Fields` as ordinary arrays. Their
structural entries retain names and reference provenance under `_nx`, so the
working templates iterate the completed model without performing lookup or
reconstructing compiler semantics.

The previously verified inForce and Storm runs matched the historical NexusSchema baselines for domain,
table, generator, primary-key, foreign-key, trigger, index, report-table,
report-field, and report-join statement counts. Their provider artifacts are
byte-identical. The schema SQL is not byte-identical because generic array
composition retains effective compiler order rather than the historical
Schema producer's field order, but normalized non-comment SQL line multisets
match for both runs.

NexusScript now supports explicit external `data` declarations and manifest
`SourceTemplate` rules. The working inForce model declares nine mock CSV files
from `data/`; both inForce and Storm manifests compile them independently and
generate one SQL file per source beneath `preload/`. Storm reaches the same
dependencies through its imported/included inForce document, which exercises
module dependency propagation.

The mock headers match the current compiled table field names, and the data is
deliberately synthetic. This proves the NexusScript compilation and rendering
path, not historical value or SQL parity. Do not treat these files as recovered
inForce production data or compare their contents to an unavailable baseline.
