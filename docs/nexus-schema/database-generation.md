# Nexus Schema Database Generation

Database generation is currently template-driven. The code does not contain a separate database generator class; it parses schema metadata, transforms it, writes Mustache JSON, and renders database-oriented templates.

## Current Firebird Template

`NexusSchema/firebird/DatabaseSchema.create.mustache` renders Firebird-oriented output, including:

- domains from `.nxs` type mappings
- tables from schema tables
- primary-key columns
- generators
- before-insert triggers
- optional history tables for `IS_HISTORY`
- foreign key constraints
- report metadata insert statements

The template uses metadata attributes such as:

| Attribute | Use |
| --- | --- |
| `MODULE_POSTFIX` | Appended to generated table names. |
| `MODULE_ID_POSTFIX` | Appended to generated primary-key names. |
| `GENERATOR_PREFIX` | Prepended to generated Firebird generator names. |
| `NEXUS_SCHEMA_PRIMARY_KEY_TYPE` | Used for generated primary-key and default reference field types. |

## Type Mapping

`.nxs` type blocks store name-value mappings:

```text
CoreTypes = Type {
  DOM_INDEX : "integer"
  DOM_NAME : "varchar(100)"
}
```

The Firebird template renders those mappings as `create domain` statements.

## Table Fields

Table fields are rendered from the transformed table model. Template fields are copied into tables before rendering, so generated table output sees the expanded field list.

```text
PERSON = Table(TMPL_TRACKED) {
  FIRST_NAME : DOM_NAME
  LAST_NAME : DOM_NAME
}
```

## References and Foreign Keys

Reference fields use `@`:

```text
COMPANY_ID : @COMPANY
```

During transformation, Nexus Schema:

- marks the field as a reference
- creates foreign key metadata on the table
- sets the field type from `NEXUS_SCHEMA_PRIMARY_KEY_TYPE` when no referenced field is named
- sets the field type from the referenced field when using `@TABLE.FIELD`

The Firebird template renders that foreign key metadata as `alter table ... add constraint ... foreign key`.

## Import Scripts

`NexusSchema/firebird/DatabaseImport.import.mustache` renders insert statements from CSV/JCSV/TSV/TAB data sources. The data source converter reads the first row as headers and remaining rows as values.

## Other Database Targets

The dashed docs previously listed SQL Server and SQLite placeholders. There are no SQL Server or SQLite templates or target-specific generators in the current `NexusSchema/` source tree, so those targets are not documented as implemented.
