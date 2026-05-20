# Generation

NexusSchema should be able to generate output from schema definitions.

This page intentionally avoids documenting any unreleased template system or obsolete internal implementation.

## Goal

Generation should turn a normalized schema model into useful files.

Possible generated outputs include:

- database creation scripts
- migration scripts
- import/export scripts
- source code
- validation code
- documentation

## Generator responsibilities

Generators should be mechanical.

They should read the schema model and write output. They should not rediscover schema meaning, invent missing relationships, or hide important defaults.

Good generator work:

- emit table creation statements
- emit class definitions
- emit field declarations
- emit relationship code
- emit validation boilerplate
- emit documentation tables

Bad generator work:

- decide what the schema means
- repair invalid schema definitions silently
- duplicate validation rules inconsistently
- contain target-independent business logic

## Target-specific output

Some details belong to a target.

Examples:

- SQL dialect syntax
- identifier quoting rules
- filename extensions
- type mapping
- reserved word handling
- script batching rules

Those should be handled by the generator for that target, not by the source schema definition.

## Documentation gap

Once the public generator system exists, this page should list the available targets and include exact runnable examples.