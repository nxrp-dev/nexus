# Metadata Model

The metadata model is the in-memory representation produced by the parser and consumed by the transformation and template stages.

## Core idea

The parser should collect schema facts.

The model should hold those facts.

The transform should derive additional facts.

The templates should emit text from the final model.

## Known model units

The current project file lists the main schema model units:

| Unit | Role |
| --- | --- |
| `obMetaDataModuleList.pas` | top-level metadata module collection |
| `obTableList.pas` | table collection/model |
| `obFieldList.pas` | field collection/model |
| `obForeignKeyList.pas` | foreign key collection/model |
| `obIndexList.pas` | index collection/model |
| `obTemplateList.pas` | template metadata |
| `obAttributeSetList.pas` | grouped attributes |
| `obNameValueList.pas` | generic name/value data |
| `obNameList.pas` | generic name list data |

## Supporting common units

The compiler also uses common infrastructure:

| Unit | Role |
| --- | --- |
| `obCommandLine.pas` | command-line options |
| `obXMLObjects.pas` | XML object support |
| `csXMLObjects.pas` | XML constants/support |
| `libxml2.pas` | libxml2 binding |
| `obTokenQueue.pas` | token stream support |
| `tpTokenizer.pas` | tokenizer types/constants |
| `utFile.pas` | file utilities |
| `FastStrings.pas` | string helper support |
| `FastStringFuncs.pas` | string helper functions |

## Data child files

The compiler loops through `lMetaData.Data` after the primary metadata file is processed.

Each data item provides:

- a name, used as `TABLE_NAME` in module-style template execution
- a value, used as the child data filename

That creates a two-level generation model:

1. Generate from the transformed whole metadata model.
2. Generate additional files from metadata-referenced child data files.

## Database-oriented output

The current Firebird scripts show the expected database style:

- create reusable domains
- create base tables through helper procedures
- add fields through helper procedures
- add foreign keys through helper procedures
- add unique constraints and indexes after table creation

Generated database output should preserve this pattern unless the schema model evolves beyond it.

## Naming conventions seen in output

The current generated SQL uses these conventions:

| Concept | Convention |
| --- | --- |
| Base table | `<NAME>_TBL` |
| Primary key | `<NAME>_PK` |
| Sequence | `<NAME>_SEQ` |
| Before insert trigger | `<NAME>_BI` |
| Before update trigger | `<NAME>_BU` |
| Foreign key field | `<REFERENCE>_ID` |
| Foreign key constraint | `<TABLE>_<FIELD>_FK` |

Those are output conventions. They should not leak backward into the parser unless the source language intentionally exposes them.