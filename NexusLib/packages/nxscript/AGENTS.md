# NexusScript Package Instructions

These rules apply to `NexusLib/packages/nxscript`.

- This package owns the reusable NexusScript language model, compiler, source/dependency session, analysis, validation, artifact model, JSON serialization, external-data handling, and manifest processing.
- Command-line process behavior remains under `NexusTools/Script/cli`.
- Language-server composition remains under `NexusTools/Script/ls`.
- Shared dialect catalogs and maintained schema scripts remain under `NexusLib/script`.
- Follow `../../../.ai/standards/pascal.md` for Object Pascal code.
