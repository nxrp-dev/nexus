# Templates

NexusSchema currently delegates text generation to templates rather than building large string emitters in Pascal.

## Current template runner

The current compiler calls FMPP through `fmpp.bat`.

Template execution is shaped around a `DDLPP` data-model binding.

Whole-model execution uses this form:

```text
-D "{DDLPP: xml(metadata.xml)}"
```

Module/data-file execution uses this form:

```text
-D "{DDLPP: csv(data.csv, {separator:','}), TABLE_NAME: 'SOME_TABLE'}"
```

The exact function name changes with the input extension. A `.dpp` input uses the `/dpp` template key. A `.csv` input uses the `/csv` template key.

## Template selection

Template selection is extension-based.

| Input file | Extension | Command-line template key |
| --- | --- | --- |
| `inForceMain.dpp` | `dpp` | `/dpp` |
| `SomeTable.csv` | `csv` | `/csv` |
| `metadata.xml` | `xml` | internal generated XML path |

## Firebird script generation

The known Firebird output style uses helper procedures from a common SQL bootstrap script.

Application scripts call reusable helpers such as:

```text
sp_create_domain
sp_create_table
sp_add_field
sp_add_foreign_key_id
sp_add_foreign_key_field
```

That keeps generated application scripts short and focused on schema intent.

## Good template responsibilities

Templates should emit mechanical text.

Good template work:

- table creation statements
- field creation calls
- foreign key creation calls
- index creation blocks
- generated import scripts
- repetitive boilerplate output

Poor template work:

- deciding core schema meaning
- duplicating parser rules
- compensating for missing transformation logic
- hiding required defaults that belong in the model

## Transformation before templates

If multiple templates need the same derived value, calculate it in `TMetaDataTransform` and store it in the model before template execution.

Do not copy the same derivation across templates.

## Portability target

The template runner path should become configurable.

The current hard-coded FMPP location is useful for a local prototype, but the documentation, batch files, and future CI should be able to run from a clean checkout without assuming `c:\fmpp\bin\fmpp.bat`.