# NexusScript schema-generation workspace

This directory isolates the NexusScript models and Mustache templates used to
develop output symmetry with the existing NexusSchema generation pipeline.

## Contents

- `models/` contains working copies of the migrated inForce and Storm
  NexusScript models from `../fixtures/nexusscript/`.
- `constants/` contains output-policy documents. The Firebird constants are
  ordinary NexusScript data and have no compiler-specific behavior.
- `data/` contains repository-local mock lookup/preload datasets used to test
  external-source compilation. They are not recovered production data.
- `mustache/` contains working copies of the current Firebird templates from
  `../../../Schema/firebird/`.
- `manifests/` owns complete generation runs by selecting domain models,
  output constants, templates, and output names.

These are NexusScript-owned working copies. Changes made here do not alter the
NexusSchema sources or templates used to produce the comparison baseline.

The working inForce model no longer owns `MODULE_POSTFIX`,
`MODULE_ID_POSTFIX`, `GENERATOR_PREFIX`, or
`NEXUS_SCHEMA_PRIMARY_KEY_TYPE`. Those values live under the explicit
`Firebird` root in `constants/Firebird.Constants.nxscript`, and the working
Mustache copies resolve them through paths such as
`Firebird.MODULE_POSTFIX`.

Each manifest compiles its models independently and combines their emitted
roots into one JSON context. The manifest entry names do not rename or wrap
those roots. This workspace does not yet claim full SQL parity: the copied
production templates still contain historical assumptions beyond the four
constant paths. Future parity work can reshape these NexusScript-owned models
and templates together without restoring a Schema-specific producer.

## Current template adaptation

The working models expose `Tables` and `Fields` as ordinary arrays. Their
structural entries retain names and reference provenance under `_nx`, so the
working templates iterate the completed model without performing lookup or
reconstructing compiler semantics.

The current inForce and Storm runs match the NexusSchema baselines for domain,
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
