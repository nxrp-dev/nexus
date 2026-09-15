# NexusScript Shared Resource Instructions

These rules apply to `NexusLib/script`.

## Standards

- Follow `../../.ai/standards/pascal.md` for Object Pascal code.
- All maintained application scripts, dialects, environments and Mustache templates belong in this common tree.
- Shared NexusScript dialect definitions belong under `dialects`.
- Keep one authoritative copy; tool code references it instead of copying it.
- Dialect definitions are shared data contracts. Tool-specific runtime behavior
  remains in the tool that implements it.
- Keep test-only language definitions with the tests they exercise.
