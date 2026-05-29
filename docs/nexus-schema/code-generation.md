# Nexus Schema Code Generation

Nexus Schema does not currently expose dedicated Pascal or C# generator classes. Code or project artifact generation should be treated as Mustache template output driven by the same metadata JSON used for database generation.

## Current Generation Model

The implemented flow is:

```text
.nxs file -> metadata model -> transform -> JSON -> Mustache template -> output file
```

That means a code-generation template can use schema facts such as modules, tables, fields, references, and attributes, but the repository does not currently define a stable Pascal or C# code-generation API.

## What Templates Can Use

Templates can render from:

- modules
- types
- tables
- fields
- field types
- table references
- foreign key metadata
- table and field attributes
- top-level metadata attributes

See the Templates page for the JSON shape.

## Adding a Code Template

A new code template should:

- use `.mustache`
- name the desired output extension before `.mustache`
- avoid embedding schema interpretation that belongs in the parser or transform
- render from `NexusSchema.MetaData`

For example, a template named `PascalRecord.pas.mustache` would produce a `.pas` output file for a `.nxs` input.

## Current Limits

No repository-aligned documentation should claim implemented Pascal or C# generators until those templates or generator classes exist in the source tree.
