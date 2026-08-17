# NexusScript schema parity matrix

The production NexusSchema sources remain unchanged. The controlled legacy
fixtures contain all active production definitions and fields, and the paired
NexusScript fixtures express the same schema through the generic language.

| Baseline fixture | NexusScript fixture | Comparison | Result |
|---|---|---|---|
| `fixtures/legacy/inForceMain.nxs` | `fixtures/nexusscript/inForceMain.Schema.nxscript` | transformed Mustache metadata JSON, preserving order | exact match |
| `fixtures/legacy/inForceMain.nxs` | `fixtures/nexusscript/inForceMain.Schema.nxscript` | `DatabaseSchema.create.mustache` output | exact match |
| `fixtures/legacy/StormSpecific.nxs` | `fixtures/nexusscript/StormSpecific.Schema.nxscript` plus imported inForce fixture | transformed Mustache metadata JSON, preserving order | exact match |
| `fixtures/legacy/StormSpecific.nxs` | `fixtures/nexusscript/StormSpecific.Schema.nxscript` plus imported inForce fixture | `DatabaseSchema.create.mustache` output | exact match |

The comparisons are automated by `NexusScriptTestModule` tests
`InForceArtifactParity` and `StormArtifactParity`. The unchanged legacy parser
constructs the baseline metadata; NexusScript and the isolated schema consumer
construct the replacement metadata; the unchanged `TMetaDataTransform` and
Mustache renderer process both sides.

Definition references remain genuine `@` references. Reference projections
omit non-scalar arrays while retaining resolved-target provenance, allowing
the recursive schema relationships to compile without consumer-side
dereferencing or a text-reference fallback. Both artifact-parity tests pass.

## Controlled legacy corrections

- `inForceMain.nxs` is byte-for-byte equivalent to the active production
  content.
- `StormSpecific.nxs` changes its external absolute `uses` path to the adjacent
  controlled `inForceMain.nxs` fixture.
- The second identical local `MOVE_IN_DATE` declaration in `TENANT_UNIT` is
  removed. NexusScript's unified namespace correctly rejects that duplicate.

No other normalization is applied. JSON arrays and member order are compared as
emitted rather than sorted.
