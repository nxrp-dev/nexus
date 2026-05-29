# Nexus Schema Philosophy

Nexus Schema keeps schema knowledge in one place and pushes repetitive output into templates.

## Schema Intent First

The `.nxs` source describes the structure of data: modules, tables, fields, type mappings, references, templates, attributes, and data sources. It should not need to repeat every mechanical detail required by a target database or generated file format.

## Mechanical Generation

Generated output should be mechanical. If output needs a meaningful decision, that decision belongs in the schema, the metadata model, or the transform step. Templates should render known facts; they should not rediscover schema meaning.

## Small Pipeline

The implementation is a pipeline rather than a broad framework:

```text
source text -> tokens -> metadata model -> normalized model -> Mustache JSON -> files
```

That shape keeps each layer easy to reason about.

## Target-Specific Templates

Database dialect syntax, identifier naming, file extensions, SQL batching, and target-specific boilerplate belong in templates. The current Firebird templates are examples of that pattern.

## Conservative Public Docs

The public docs should distinguish current behavior from possible future expansion. It is better to document the implemented `.nxs` language and Mustache flow accurately than to describe targets or APIs that do not exist in the repository.
