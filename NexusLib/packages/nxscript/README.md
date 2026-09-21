# NexusScript Package

This package contains the reusable NexusScript mechanism:

- source ranges, values, definitions, modules, and semantic model;
- compiler, import, source-provider, and compilation-session logic;
- analysis, language definitions, normalization, and validation;
- artifact model and JSON serialization;
- external tabular-source handling and manifest processing.

The command-line frontend remains under `NexusTools/Script/cli`. The
NexusScript language-server adapter remains under `NexusTools/Script/ls`.
Shared dialect catalogs and schema-owned scripts remain under `NexusLib/script`.

Package tests and parity fixtures are under `test/`.
