# NexusLib UI Agent Instructions

These rules apply to `NexusLib/ui`.

## Standards

- For Object Pascal / Free Pascal code, follow `../../.ai/standards/pascal.md`.
- Treat this folder as the NexusUI source library: retained controls, rendering, input routing, windows, popups, and skins.

## Architecture

- `TNXApplication` owns application/runtime lifecycle.
- Windows are first-class UI surfaces managed by the application/window manager.
- Controls are renderable and/or interactable UI objects.
- Container controls such as panels and group boxes are still controls.
- Parent relationships should use the CORBA-style `INXControlParent` interface and must not imply reference-counted ownership.
- SDL2 is an implementation detail where practical; keep backend details behind framework objects without inventing broad abstractions before they are needed.
