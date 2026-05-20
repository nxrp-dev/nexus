# NexusSchema

NexusSchema is the schema side of the Nexus project family.

Its purpose is to describe structured data and the relationships between that data in a form that can later drive repeatable tooling.

## Purpose

NexusSchema should make schema intent explicit.

The goal is not to create another pile of hand-maintained scripts. The goal is to define structure once, then let tooling produce the repetitive output that follows from that structure.

Useful targets include:

- database schema definitions
- validation rules
- import/export definitions
- generated scripts
- generated source code
- documentation derived from schema definitions

## Boundary

NexusSchema is separate from NexusUI.

NexusUI is the UI framework. NexusSchema is for describing data structures, schema rules, and generation inputs. They are part of the same broader Nexus project family, but they should stay documented separately.

## Current documentation status

This documentation is intentionally conservative.

It describes the public direction of NexusSchema without documenting unreleased private history or obsolete internal project names.

## Working model

The intended shape is simple:

```text
schema definition -> schema model -> validation/normalization -> generated output
```

The exact source syntax and implementation details should be documented only after they are stable enough to be public.