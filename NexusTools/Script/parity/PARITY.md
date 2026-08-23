# NexusScript artifact boundary

NexusScript no longer has a Schema producer or a Schema-metadata parity gate.
Its artifact boundary is the generic completed-model JSON documented in
`../README.md`. The CLI, tests, and project files do not route output through
NexusSchema metadata classes or transformations.

The fixtures in this directory remain compiler-language fixtures only. They do
not define the JSON contract and are not evidence that NexusScript output must
match the historical NexusSchema metadata representation.

`schema-generation/` is the isolated NexusScript-owned workspace for pursuing
generated-output symmetry. Its manifests assemble independently compiled
domain and output-constants documents with working Mustache copies. This is a
local adaptation surface, not a Schema producer and not a claim that the
current generic model already renders SQL equivalent to NexusSchema.

External tabular compilation and source-driven manifest rendering are now part
of NexusScript's generic tooling. Repository-local fixtures verify type-based
CSV/JCSV/TSV/TAB dispatch and one derived output per declared source. The
schema-generation workspace also contains synthetic replacements for the nine
missing inForce files so both inForce and Storm exercise complete preload SQL
generation. The historical files remain unavailable, so the mock outputs are
functional evidence only, not NexusSchema data-parity evidence.
