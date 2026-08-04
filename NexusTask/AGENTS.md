# NexusTask Agent Instructions

These instructions apply to the `NexusTask` folder.

- Follow `../.ai/standards/pascal.md`.
- NexusTask manifests are trusted executable build/deployment descriptions, not untrusted data.
- Keep parsing, validation, materialization, target inspection, and execution as separate responsibilities.
- Do not add production deployment actions before the core language, resolver, and executor contracts are stable.
- Do not let task actions control child traversal in the initial implementation.
