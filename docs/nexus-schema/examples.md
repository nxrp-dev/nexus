# Nexus Schema Examples

These examples are based on the current `.nxs` parser and metadata transform.

## Small Schema

```text
module Catalog

var MODULE_POSTFIX = "_TBL"
var MODULE_ID_POSTFIX = "_ID"
var GENERATOR_PREFIX = "GEN_"
var NEXUS_SCHEMA_PRIMARY_KEY_TYPE = "integer"

CatalogTypes = Type {
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

`PRODUCT` receives `NAME` and `DESCRIPTION` from `TMPL_TYPE` during transformation.

## Reference Field

```text
module Sales

OrderTypes = Type {
  DOM_COUNT : "integer"
}

PRODUCT = Table {
  NAME : "varchar(100)"
}

ORDER_LINE = Table {
  PRODUCT_ID : @PRODUCT
  QUANTITY : DOM_COUNT
}
```

`PRODUCT_ID` is marked as a reference to `PRODUCT`. The transform creates foreign key metadata for `ORDER_LINE`.

## Attribute Set

```text
module Audit

ATTR_HISTORY = Attributes {
  IS_HISTORY : "True"
}

PAYMENT = Table() Attributes(ATTR_HISTORY) {
  AMOUNT : "numeric(12,2)"
}
```

The `IS_HISTORY` attribute is copied onto `PAYMENT`. The current Firebird schema template uses that attribute to render a history table and related trigger.

## Data File

```text
module SeedData

data STATE <DML\STATE.csv>

STATE = Table {
  CODE : "char(2)"
  NAME : "varchar(100)"
}
```

With a `-csv=firebird\DatabaseImport.import.mustache` switch, the tool can render insert statements from `STATE.csv`.

## Command

```powershell
.\NexusSchema.exe -metadata=Catalog.nxs -nxs=firebird\DatabaseSchema.create.mustache -Output=output
```

For `Catalog.nxs`, this writes `output\Catalog.create` and an intermediate `output\Catalog.schema.json`.
