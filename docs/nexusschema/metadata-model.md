# Schema Model

The schema model is the internal representation of a schema after it has been loaded.

## Core idea

The source definition should describe intent.

The schema model should hold structured facts.

Generators should emit mechanical output from those facts.

## Likely concepts

NexusSchema will likely need model objects for common schema concepts:

| Concept | Meaning |
| --- | --- |
| Schema | the top-level definition set |
| Entity | a table-like or object-like structure |
| Field | a named value on an entity |
| Type | the kind of value a field stores |
| Relationship | a reference from one entity to another |
| Index | a lookup or uniqueness rule |
| Attribute | extra metadata attached to a schema object |
| Target | a generation backend or output profile |

## Model rules

The model should avoid being target-specific too early.

For example, an entity may eventually generate a Firebird table, a SQL Server table, a Pascal class, a C# class, or documentation. The model should describe the entity first. Target-specific generators can decide how to express it.

## Derived values

Generated names and defaults should be calculated once and stored consistently.

Examples:

- default primary key names
- default foreign key names
- default index names
- default generated filenames
- normalized type names
- target-specific escaped identifiers

If multiple generators need the same derived value, it should not be recalculated differently in each generator.

## Documentation gap

This page should eventually include the exact public schema object model once the current implementation is ready to document.