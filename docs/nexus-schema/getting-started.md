# Nexus Schema Getting Started

Nexus Schema is a console tool built from `NexusSchema/NexusSchema.lpr`. It expects a metadata schema file, one or more template switches, and an output folder.

## Define a Schema

A minimal schema module starts with `module`, then declares types, templates, tables, data files, or variables:

```text
module Example

var MODULE_POSTFIX = "_TBL"
var MODULE_ID_POSTFIX = "_ID"
var GENERATOR_PREFIX = "GEN_"
var NEXUS_SCHEMA_PRIMARY_KEY_TYPE = "integer"

CoreTypes = Type {
  DOM_NAME : "varchar(100)"
  DOM_DESCRIPTION : "blob sub_type 1 segment size 100"
}

TMPL_TYPE = Template {
  NAME : DOM_NAME
  DESCRIPTION : DOM_DESCRIPTION
}

PRODUCT = Table(TMPL_TYPE) {
}
```

Reference fields use `@`:

```text
ORDER_LINE = Table {
  PRODUCT_ID : @PRODUCT
}
```

During transformation, reference fields become foreign key metadata and receive the referenced primary-key type unless a specific referenced field is named.

## Choose a Template

Output comes from Mustache templates. The repository includes Firebird examples:

- `NexusSchema/firebird/DatabaseSchema.create.mustache`
- `NexusSchema/firebird/DatabaseImport.import.mustache`
- `NexusSchema/firebird/AutoProviderList.prv.mustache`

The schema tool derives the output extension from the template name. For example, `DatabaseSchema.create.mustache` produces a `.create` output file.

## Run the Tool

The command-line parser accepts switches in `-name=value` or `/name=value` form. The tool expects:

- `metadata`: the `.nxs` schema file to parse
- `Output`: the output folder
- one switch named after each input extension, such as `nxs` or `csv`, whose value is the template for that extension

Example:

```powershell
.\NexusSchema.exe -metadata=StormSpecific.nxs -nxs=firebird\DatabaseSchema.create.mustache -Output=output
```

If the schema references CSV or TSV data files, provide a matching template switch:

```powershell
.\NexusSchema.exe -metadata=inForceMain.nxs -nxs=firebird\DatabaseSchema.create.mustache -csv=firebird\DatabaseImport.import.mustache -Output=output
```

## Review Generated Files

The generated files are template output, not migrations managed by a database engine. Review the output before applying it to a database.
