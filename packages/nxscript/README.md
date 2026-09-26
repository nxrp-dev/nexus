# NexusScript Package

This package contains the reusable NexusScript mechanism:

- source ranges, values, definitions, modules, and semantic model;
- compiler, import, source-provider, and compilation-session logic;
- analysis, language definitions, normalization, and validation;
- artifact model and JSON serialization;
- external tabular-source handling and manifest processing.

The command-line frontend remains under `projects/nxscript/cli`. The
NexusScript language-server adapter remains under `projects/ls/nxscript`.
Dialect definitions live with their owners: NexusScript and NexusManifest under
`projects/nxscript/language`, Forge under `projects/forge/language`, Bot under
`projects/bothost/language`, Schema under `projects/schema/language`, and
WorkspaceIndex under `tools/workspace-index/language`.

Package tests and parity fixtures are under `test/`.
