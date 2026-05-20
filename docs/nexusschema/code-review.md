# Review Notes

These are public-facing review notes for NexusSchema documentation and direction.

They are intentionally not tied to unreleased private tools or obsolete project names.

## Keep

### Keep NexusSchema separate from NexusUI

NexusUI and NexusSchema solve different problems.

NexusUI is about interface controls, rendering, events, focus, styling, and application UI behavior.

NexusSchema is about structured data definitions and repeatable generation from those definitions.

The documentation should keep that separation clear.

### Keep the pipeline simple

The intended pipeline is easy to reason about:

```text
schema definition -> schema model -> validation -> normalization -> generation
```

That shape is worth preserving.

### Keep generated output mechanical

Generated files should come from schema facts.

If output requires meaningful decisions, those decisions probably belong in the schema model, validation layer, or normalization layer rather than scattered through generators.

## Fix soon

### Replace placeholders with exact examples

The documentation still needs real public examples once the source format is stable.

Needed examples:

- smallest valid schema definition
- entity/table definition
- field definition
- relationship definition
- index or uniqueness rule
- generated output example

### Define the public vocabulary

The docs need stable names for the core concepts.

Possible terms:

- schema
- entity
- field
- relationship
- index
- attribute
- target
- generator

The exact words matter less than consistency.

### Document what is real versus planned

Each page should make it obvious whether it describes:

- current behavior
- planned behavior
- design intent
- open questions

This prevents docs from becoming fake certainty.

## Avoid

### Do not document private history

Public docs should not mention obsolete internal project names, unreleased experiments, or local-only tooling.

### Do not over-specify early

Until the source format and command-line interface are stable, keep the docs directional and conservative.

### Do not mix project categories

Do not let NexusSchema pages become a dumping ground for NexusUI, NexusCore, or unrelated compiler notes.

## Next useful documentation step

Write one small public schema example and one matching generated-output example.

That will make the docs executable in spirit instead of merely descriptive.