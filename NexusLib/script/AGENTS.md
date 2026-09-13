# NexusScript Shared Resource Instructions

These rules apply to `NexusLib/script`.

## Standards

- Follow `../../.ai/standards/pascal.md` for Object Pascal code.
- Shared NexusScript dialect definitions belong under `dialects`.
- Dialect definitions are shared data contracts. Tool-specific runtime behavior
  remains in the tool that implements it.
- Keep test-only language definitions with the tests they exercise.
