# NexusSchema Architecture

NexusSchema should stay small and explicit.

The architecture is a pipeline, not a framework maze.

## Intended pipeline

```text
schema definition
    -> parser / loader
    -> schema model
    -> validation
    -> normalization
    -> generation
    -> output files
```

## Schema definition

A schema definition is the source of truth.

It should describe the structure and intent of the data without forcing the author to repeat every mechanical detail required by a target system.

## Parser / loader

The parser or loader reads the schema definition and converts it into the internal schema model.

This layer should only understand the source format. It should not generate database scripts, UI code, or application code directly.

## Schema model

The schema model is the in-memory representation of the parsed structure.

This is where tables, fields, relationships, indexes, attributes, and other schema concepts belong.

The model should be target-neutral where possible. Firebird, SQL Server, Pascal, C#, and documentation output should all be treated as possible targets rather than as the model itself.

## Validation

Validation should catch bad schema definitions early.

Examples:

- missing names
- duplicate names
- invalid references
- unsupported field types
- relationship errors
- target-specific incompatibilities

## Normalization

Normalization fills in derived facts and defaults.

Examples:

- generated constraint names
- generated index names
- default table suffixes
- default field attributes
- inferred relationships

If more than one output target needs the same derived value, calculate it once during normalization.

## Generation

Generators turn the normalized schema model into files.

Possible generators include:

- database scripts
- import scripts
- source code
- validation code
- documentation

Generators should be boring. They should emit from the model, not rediscover schema meaning.