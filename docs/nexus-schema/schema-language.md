# Nexus Schema Syntax

The `.nxs` language is a compact declaration format parsed by `TNexusSchemaParser`. It describes metadata; rendering details belong in Mustache templates.

## Quick Example

```text
module Catalog

var MODULE_POSTFIX = "_TBL"
var MODULE_ID_POSTFIX = "_ID"
var GENERATOR_PREFIX = "GEN_"
var NEXUS_SCHEMA_PRIMARY_KEY_TYPE = "DOM_INDEX"

data STATE <DML\STATE.csv>

CoreTypes = Type {
  DOM_INDEX : "integer"
  DOM_NAME : "varchar(100)"
  DOM_DESCRIPTION : "blob sub_type 1 segment size 100"
}

ATTR_HISTORY = Attributes {
  IS_HISTORY : "True"
}

TMPL_TYPE = Template {
  NAME : DOM_NAME
  DESCRIPTION : DOM_DESCRIPTION
}

CATEGORY = Table(TMPL_TYPE)

PRODUCT = Table(TMPL_TYPE) Attributes(ATTR_HISTORY) {
  CATEGORY_ID : @CATEGORY
  EXTERNAL_CODE : "varchar(30)"
}
```

## Lexical Rules

- Keywords are case-insensitive: `table`, `Table`, and `TABLE` are all recognized.
- Identifiers are unquoted tokens that stop at whitespace, an operator, or the end of the file. They are stored with their original spelling.
- Newlines are normalized as semicolon operators. You may also write explicit `;` separators.
- Whitespace is otherwise insignificant.
- Line comments use `//`. Block comments use `/* ... */`.
- Strings use either double quotes or angle brackets:

```text
DOM_NAME : "varchar(100)"
data STATE <DML\STATE.csv>
```

Quoted and angle-bracket strings cannot span lines. To include the terminator inside the string, double it, such as `""` inside a quoted string.

## File Structure

Every schema file starts with a module declaration:

```text
module ModuleName
```

After the module declaration, the parser accepts these top-level forms:

```text
uses <OtherFile.nxs>
data NAME <DataFile.csv>
var NAME = "value"
Name = Type { ... }
Name = Attributes { ... }
Name = Template(...) Attributes(...) Children(...) { ... }
Name = Table(...) Attributes(...) Children(...) { ... }
```

`uses` parses another `.nxs` file into the same metadata model. The loader first tries the supplied path, then the basename in the current process directory.

## Declaration Forms

| Form | Syntax | Result |
| --- | --- | --- |
| Module | `module Name` | Starts a schema module. |
| Uses | `uses <File.nxs>` | Loads another schema file. |
| Data | `data NAME <File.csv>` | Registers a top-level data file. |
| Variable | `var NAME = VALUE` | Stores a top-level metadata attribute. |
| Type block | `Name = Type { NAME : "value" }` | Adds type/domain mappings to the module. |
| Attribute set | `Name = Attributes { NAME : "value" }` | Defines reusable metadata attributes. |
| Template | `Name = Template(...) { fields }` | Defines reusable fields and metadata. |
| Table | `Name = Table(...) { fields }` | Defines a table. |

## Variables

Variables become top-level metadata attributes:

```text
var MODULE_POSTFIX = "_TBL"
var NEXUS_SCHEMA_PRIMARY_KEY_TYPE = DOM_INDEX
var ENABLE_REPORTS
```

The value may be a string or identifier. If no value is supplied, the parser stores `true`. During transformation, `NEXUS_SCHEMA_PRIMARY_KEY_TYPE` defaults to `integer` when it is not set.

## Type Blocks

Type blocks contain `name : string` pairs:

```text
CoreTypes = Type {
  DOM_INDEX : "integer"
  DOM_NAME : "varchar(100)"
}
```

The declaration name, such as `CoreTypes`, is a source label. The block entries are stored directly in the module `Types` list. The current Firebird template renders them as domains, but the metadata model itself is target-neutral.

## Attribute Sets

Attribute sets contain `name : string` pairs:

```text
ATTR_HISTORY = Attributes {
  IS_HISTORY : "True"
}
```

Tables, templates, and fields can reference attribute sets:

```text
ORDER = Table() Attributes(ATTR_HISTORY) {
  CUSTOMER_ID(ATTR_REQUIRED) : @CUSTOMER
}
```

Referenced attribute sets are copied into the target object's `Attributes` JSON object during transformation.

## Templates And Tables

Templates and tables share the same declaration shape:

```text
TMPL_TRACKED = Template {
  CREATED_BY : @PERSON
  CREATED_DATE : DOM_TIMESTAMP
}

PERSON = Table(TMPL_TRACKED) {
  FIRST_NAME : DOM_NAME
  LAST_NAME : DOM_NAME
}
```

The optional parenthesized list immediately after `Table` or `Template` is the template-reference list. Empty lists are valid:

```text
LOG_ENTRY = Table()
```

`Attributes(...)` and `Children(...)` may appear after the template-reference list and before the field block:

```text
CATEGORY = Table(TMPL_TYPE) Children(CATEGORY_INDEX) {
  PARENT_ID : @CATEGORY
}
```

`children(...)` records child references in metadata. The current Firebird template does not consume those references directly.

The field block is optional, so these are valid:

```text
PERSON_TYPE = Table(TMPL_TYPE, TMPL_TRACKED)
SYSTEM_MODULE = Table(TMPL_TRACKED) {}
```

## Fields

Fields are `name : type` pairs inside a table or template block:

```text
NAME : DOM_NAME
DESCRIPTION : "blob sub_type 1 segment size 100"
```

A field type may be an identifier, a string, or a reference. Field-level attributes are written before the colon:

```text
NAME(ATTR_REQUIRED, ATTR_SEARCHABLE) : DOM_NAME
```

Inside a table block, `data` registers an additional data file for that table:

```text
STATE = Table {
  CODE : DOM_STATE
  NAME : DOM_NAME
  data <DML\STATE.csv>
}
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

During transformation, reference fields create foreign key metadata. A plain `@TABLE` reference receives the type from `NEXUS_SCHEMA_PRIMARY_KEY_TYPE`. A `@TABLE.FIELD` reference receives the type from the referenced field when the transform can resolve it.

## Current Limits

The current parser does not have dedicated syntax for indexes, nullability, default values, constraints, or target-specific database options. Capture that information with attributes or templates when a Mustache template needs it.
