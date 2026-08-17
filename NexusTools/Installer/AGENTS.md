# Nexus Installer Instructions

This folder owns Nexus installer source and installer staging support.

- Follow `../../AGENTS.md`.
- Keep installer work Windows x64 focused unless a future task explicitly broadens platform scope.
- Inno Setup should package a staged Nexus payload; it should not crawl arbitrary source folders.
- The Windows installer discovery contract is one registry value: `NexusRoot`.
- Do not add a bootstrap executable or extra registry values without explicit approval.
