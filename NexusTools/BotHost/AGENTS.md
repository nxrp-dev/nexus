# Nexus BotHost Agent Instructions

- Follow `../../.ai/standards/pascal.md`.
- BotHost owns tool-specific coordination between NexusXMPP and Codex App Server.
- Protocol data is modeled by RTTI classes and published properties.
- Do not add a protocol result queue or require NexusUI to pump protocol work.
- Do not persist passwords or API keys.
- Register all BotHost tests with `NexusBotHostTestModule`; do not create
  standalone test runners or test harness applications. A separate executable
  is permitted only when it is the external process fixture being exercised by
  a test registered with the Nexus test framework.
