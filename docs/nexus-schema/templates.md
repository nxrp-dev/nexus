# Nexus Schema Templates

Nexus Schema generates files by rendering Mustache templates against JSON produced from the metadata model.

## Template Engine

Rendering is handled by `RenderMustacheFile` in `obMustacheRenderer.pas`, using `TSynMustache.TryRenderJson`.

The renderer reads:

- a JSON file
- a `.mustache` template file
- an output path

It writes the rendered text to the output path, creating the output folder when needed.

## Metadata JSON Shape

Schema metadata is written under `NexusSchema.MetaData`:

```text
NexusSchema
  MetaData
    Attributes
    Data
    AttributeSets
    Modules
      Types
      Templates
      Tables
```

Tables and templates expose:

- `Name`
- `Fields`
- `Indexes`
- `ForeignKeys`
- `TemplateReferences`
- `AttributeReferences`
- `ChildReferences`
- `Attributes`

Fields expose:

- `Name`
- `TableName`
- `FieldType`
- `IsReference`
- `ReferenceEntity`
- `ReferencedFieldName`
- `Comma`
- `AttributeReferences`
- `Attributes`

Foreign keys expose:

- `Name`
- `TableName`
- `ConstraintName`
- `Entity`
- `ReferenceEntity`
- `Field`
- `Attributes`

## Current Repository Templates

The current repository includes these templates under `NexusSchema/firebird/`:

| Template | Output role |
| --- | --- |
| `DatabaseSchema.create.mustache` | Firebird-oriented domains, tables, generators, triggers, foreign keys, and report metadata inserts. |
| `DatabaseImport.import.mustache` | SQL insert statements for delimited data sources. |
| `AutoProviderList.prv.mustache` | Provider-list style output. |

## Output File Extensions

The tool derives the generated file extension from the template name after removing `.mustache`.

Examples:

| Template | Output extension |
| --- | --- |
| `DatabaseSchema.create.mustache` | `.create` |
| `DatabaseImport.import.mustache` | `.import` |
| `AutoProviderList.prv.mustache` | `.prv` |

## Data Source Templates

For CSV, JCSV, TSV, and TAB files, Nexus Schema first converts the delimited file into JSON with:

- `TABLE_NAME`
- `Headers`
- `Rows`
- `Values`

The import template then renders from that data JSON instead of from the schema metadata JSON.
