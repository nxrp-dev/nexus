# Nexus Schema

Nexus Schema is the schema-driven generation tool in the Nexus project family. It reads `.nxs` schema modules, builds an in-memory metadata model, normalizes shared schema facts, serializes that model as JSON, and renders output through Mustache templates.

The current implementation lives in `NexusSchema/` and is intentionally small:

```text
.nxs schema module
    -> tokenizer
    -> parser
    -> metadata model
    -> metadata transform
    -> Mustache JSON
    -> rendered output files
```

## What It Describes

A schema module can define:

- modules
- imported schema modules
- global variables used as metadata attributes
- external data files
- named type/domain mappings
- reusable attribute sets
- reusable templates
- tables
- fields
- references between tables

The schema file describes structure and intent. Target-specific output details belong in templates.

## Current Outputs

The repository currently includes Firebird-oriented Mustache templates for database creation and import scripts under `NexusSchema/firebird/`. The renderer itself is generic: it emits whatever a Mustache template asks it to emit from the metadata JSON.

CSV, JCSV, TSV, and TAB data files can also be converted into Mustache JSON for data-import rendering.

## Boundary

Nexus Schema is separate from Nexus UI. Nexus UI is about controls, rendering, events, focus, styling, and application behavior. Nexus Schema is about structured data definitions and repeatable generated output.

## Documentation Status

These pages document the code that is present in the repository. Where a target, command, or generator is not implemented, the docs say so directly instead of promising future behavior.
