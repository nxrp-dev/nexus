# Nexus GUI Package Agent Instructions

These rules apply to `packages/gui`.

## Standards

- For Object Pascal / Free Pascal code, follow `../../../.ai/standards/pascal.md`.
- Treat this folder as the Nexus fpGUI integration package: controls and skins built on fpGUI.

## Architecture

- `obNXControls` provides the small Nexus-named fpGUI control wrappers.
- `obNXTreeView` and `obNXStarMap` are fpGUI widgets.
- `TNXSkin` descends from the fpGUI style and owns its color palette.
- Use fpGUI ownership, rendering, input, and window lifecycle directly.
