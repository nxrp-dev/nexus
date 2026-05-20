# Nexus

Nexus is a Pascal project family focused on practical, self-contained application infrastructure.

The current repository contains the early NexusUI work: a retained-mode UI framework written in FreePascal/Lazarus style code, using SDL2 as the active backend.

## Current focus

NexusUI is being built from working application needs rather than as a theoretical widget toolkit. The immediate goal is to create enough reliable UI infrastructure to support real tools while keeping the framework understandable and portable.

Primary goals:

- Keep platform-specific behavior isolated behind a small backend layer.
- Use SDL2 for windowing, rendering, input, text input, clipboard, timing, images, and fonts.
- Build retained controls in Pascal code rather than depending on a visual designer.
- Keep layout and event behavior explicit.
- Prefer simple, readable control implementations over a large opaque framework.

## Documentation map

Start with the [NexusUI overview](nexusui/index.md), then read the architecture and event model pages.

- [Architecture](nexusui/architecture.md) explains the major runtime pieces.
- [Event and Focus Model](nexusui/event-focus.md) documents input routing, focus, popups, and mouse capture.
- [Controls](nexusui/controls.md) lists the current controls and backlog.
- [Styling and Skins](nexusui/styling-skins.md) describes the skin direction.
- [Development Notes](nexusui/development.md) captures working conventions.
- [Roadmap](nexusui/roadmap.md) tracks near-term priorities.
