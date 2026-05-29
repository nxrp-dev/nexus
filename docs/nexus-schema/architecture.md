# Nexus Schema Architecture

Nexus Schema is organized as a direct compiler-style pipeline.

```text
source file
    -> tokenizer
    -> parser
    -> metadata model
    -> transform
    -> JSON serialization
    -> Mustache rendering
    -> output files
```

## Source File

The source file is a `.nxs` schema module. It starts with `module` and can include types, templates, tables, attributes, variables, data files, and `uses` references to other schema files.

## Tokenizer

`obNexusSchemaTokenizer.pas` converts source text into tokens. It recognizes operators, keywords, strings, identifiers, and comments. Newlines are normalized as semicolon operators, which lets declarations be separated by line breaks.

## Parser

`TNexusSchemaParser` in `obNexusSchemaParser.pas` consumes tokens and fills a `TMetaDataModuleList`.

The parser is responsible for syntax-level structure:

- module names
- used files
- variables
- type mappings
- attribute sets
- template declarations
- table declarations
- field declarations
- table references
- data file registrations

It does not render output directly.

## Metadata Model

The metadata model is defined by `obMetaDataModel.pas` and `obMetaDataModuleList.pas`. It stores modules, tables, templates, fields, indexes, foreign keys, attribute sets, data files, and extra attributes.

The model is intentionally target-neutral. The current Firebird output is a template choice, not a separate model type.

## Transform

`TMetaDataTransform` normalizes metadata before output. It currently:

- applies a default primary-key type when `NEXUS_SCHEMA_PRIMARY_KEY_TYPE` is missing
- expands template fields into tables
- copies referenced attribute sets onto tables and fields
- creates foreign key metadata for reference fields
- resolves reference field types

## JSON Serialization

`obMetaDataJSON.pas` writes transformed metadata under `NexusSchema.MetaData`. This JSON is the input for schema-output Mustache templates.

## Mustache Rendering

`obMustacheRenderer.pas` renders templates using `TSynMustache`. The renderer is generic. Database scripts, code files, provider files, and documentation-like files are all just template output.

## Data Source Rendering

`obDataSourceProcessors.pas` supports CSV/JCSV and TSV/TAB data files. It converts delimited files to JSON with headers and rows so import templates can render data statements.
