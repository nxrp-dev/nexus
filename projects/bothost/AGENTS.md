# Nexus BotHost Agent Instructions

Follow the Nexus root [AGENTS.md](../../AGENTS.md), including its rules on instruction sources.

- Follow `../../.ai/standards/pascal.md`.
- BotHost owns tool-specific coordination between NexusXMPP and Codex App Server.
- Protocol data is modeled by RTTI classes and published properties.
- Do not add a protocol result queue.
- Bot deployment credentials belong in the typed persisted configuration.
  Never expose them through logs, diagnostics, command-line arguments, or
  console output.
- Register all BotHost tests with `NexusBotHostTestModule`; do not create
  standalone test runners or test harness applications. A separate executable
  is permitted only when it is the external process fixture being exercised by
  a test registered with the Nexus test framework.
