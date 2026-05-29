# Nexus Schema Metadata Model

The metadata model is the structured representation that sits between `.nxs` parsing and generated output.

## Top Level

`TMetaDataModuleList` is the top-level model. It contains:

| Property | Meaning |
| --- | --- |
| `Data` | Named external data files. |
| `AttributeSets` | Top-level attribute-set collection on the model; parsed `.nxs` attribute sets are currently stored on modules. |
| `Items` | Schema modules. |
| `ExtraAttributes` | Top-level variables from `var` declarations. |

## Modules

`TMetaDataModuleItem` contains:

| Property | Meaning |
| --- | --- |
| `Tables` | Table declarations. |
| `Types` | Name-value type mappings. |
| `Templates` | Reusable field and metadata declarations. |
| `AttributeSets` | Attribute sets declared in the module. |

## Tables and Templates

Tables and templates share the `TTemplateItem` structure. A table is represented by `TTableItem`, which currently descends from `TTemplateItem`.

| Property | Meaning |
| --- | --- |
| `Fields` | Fields declared directly or copied from templates. |
| `Indexes` | Index metadata collection. |
| `ForeignKeys` | Foreign key metadata created from reference fields. |
| `TemplateReferences` | Names of templates to copy into this item. |
| `AttributeReferences` | Names of attribute sets to copy onto this item. |
| `ChildReferences` | Names recorded by `children(...)`. |
| `ExtraAttributes` | Attributes copied onto this item. |

## Fields

`TFieldItem` contains:

| Property | Meaning |
| --- | --- |
| `FieldType` | The resolved type used by templates. |
| `IsReference` | True when the source field used `@TABLE` or `@TABLE.FIELD`. |
| `ReferenceEntity` | Referenced table name. |
| `ReferencedFieldName` | Referenced field name, when present. |
| `AttributeReferences` | Field-level attribute set references. |
| `ExtraAttributes` | Attributes copied onto the field. |

## Foreign Keys

`TForeignKeyItem` is created during transformation for reference fields.

| Property | Meaning |
| --- | --- |
| `Entity` | Table that owns the reference field. |
| `ReferenceEntity` | Referenced table. |
| `Field` | Field on the owning table. |

When serialized to JSON, foreign keys also get a `ConstraintName` value in the form `FK_<TableName>_<Field>`.

## Attribute Sets

`TAttributeSetItem` stores a `TNameValueList`. Referencing an attribute set copies those name-value pairs into the target object's `ExtraAttributes`.

## Derived Values

The transform step currently derives:

- copied template fields
- copied table and field attributes
- foreign key records
- reference field types
- default primary-key type metadata

Generated names that are purely target-specific, such as Firebird generator names, are currently assembled in templates.
