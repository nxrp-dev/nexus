# Nexus Schema Language

The `.nxs` language is a small declaration language parsed by `TNexusSchemaParser`.

## Tokens

The tokenizer recognizes:

- identifiers
- keywords
- operators
- quoted strings
- angle-bracket strings
- line and block comments

Quoted strings use double quotes:

```text
DOM_NAME : "varchar(100)"
```

Angle-bracket strings are useful for paths:

```text
data STATE <DML\STATE.csv>
```

Line comments use `//`. Block comments use `/* ... */`.

## Keywords

The current keyword set is:

| Keyword | Purpose |
| --- | --- |
| `module` | Starts a schema module. |
| `uses` | Loads another schema file. |
| `data` | Registers an external data file. |
| `var` | Sets a metadata attribute. |
| `table` | Declares a table. |
| `template` | Declares reusable fields and metadata. |
| `type` | Declares named type mappings. |
| `attributes` | Declares or applies attribute sets. |
| `children` | Records child references on a table or template. |

Keywords are matched case-insensitively by the parser.

## Modules

Every file starts with a module declaration:

```text
module Example
```

The parser stores declarations from that file under the module name. `uses` can load another schema file:

```text
uses <SharedTypes.nxs>
```

## Variables

Variables are stored as metadata attributes on the top-level metadata model:

```text
var MODULE_POSTFIX = "_TBL"
var NEXUS_SCHEMA_PRIMARY_KEY_TYPE = "DOM_INDEX"
```

If no value is supplied, the value is `true`:

```text
var ENABLE_REPORTS
```

The transform step currently defaults `NEXUS_SCHEMA_PRIMARY_KEY_TYPE` to `integer` when it is not set.

## Data Files

Top-level data declarations register data files by module name:

```text
data STATE <DML\STATE.csv>
```

Inside a table block, `data` registers a data file for that table:

```text
STATE = Table {
  CODE : DOM_STATE
  NAME : DOM_NAME
  data <DML\STATE.csv>
}
```

CSV, JCSV, TSV, and TAB files can be converted into Mustache JSON during rendering.

## Types

Types are name-value mappings:

```text
CoreTypes = Type {
  DOM_INDEX : "integer"
  DOM_NAME : "varchar(100)"
}
```

The Firebird schema template renders these as domains, but the model stores them as target-neutral metadata.

## Attribute Sets

Attribute sets are reusable name-value metadata:

```text
ATTR_HISTORY = Attributes {
  IS_HISTORY : "True"
}
```

Tables, templates, and fields can reference attribute sets:

```text
TENANT_UNIT = Table(TMPL_TRACKED) Attributes(ATTR_HISTORY) {
  TENANT_ID : @TENANT
}
```

During transformation, referenced attributes are copied into the target object's `Attributes` JSON object.

## Templates

Templates define reusable fields and metadata:

```text
TMPL_TRACKED = Template {
  CREATED_BY : @PERSON
  CREATED_DATE : DOM_TIMESTAMP
  MODIFIED_BY : @PERSON
  MODIFIED_DATE : DOM_TIMESTAMP
}
```

Templates can reference other templates:

```text
TMPL_PERSON = Template(TMPL_TRACKED) {
  FIRST_NAME : DOM_NAME
  LAST_NAME : DOM_NAME
}
```

## Tables

Tables may reference zero or more templates and may contain fields:

```text
PERSON = Table(TMPL_TRACKED) {
  FIRST_NAME : DOM_NAME
  LAST_NAME : DOM_NAME
}
```

An empty table declaration is valid:

```text
PERSON_TYPE = Table(TMPL_TYPE, TMPL_TRACKED)
```

## Fields

Fields are `name : type` pairs:

```text
NAME : DOM_NAME
```

Fields can reference attributes:

```text
NAME(ATTR_REQUIRED) : DOM_NAME
```

## References

A field value starting with `@` marks a table reference:

```text
PERSON_ID : @PERSON
```

The referenced field can be named explicitly:

```text
PERSON_NAME : @PERSON.NAME
```

The transform step creates foreign key metadata and assigns a field type from either the default primary-key type or the referenced field type.
